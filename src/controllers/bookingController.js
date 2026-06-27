const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// ==========================================
// Helper Function: สำหรับแปลงสตริงเวลาให้เป็น Date Object ตามที่ Prisma ต้องการ
// ==========================================
const normalizeTime = (dateString, timeString) => {
  const datePart = new Date(dateString).toISOString().split('T')[0];
  const isTimeOnly = timeString.match(/^([01]\d|2[0-3]):([0-5]\d)(:[0-5]\d)?$/);
  if (isTimeOnly) {
    return new Date(`${datePart}T${timeString}.000Z`);
  }
  return new Date(timeString);
};

// ==========================================
// 💡 โลจิกสำหรับตรวจสอบเวลาจองซ้ำ (Reusable Function)
// ==========================================
const checkOverlapping = async (roomId, bookingDate, startTime, endTime) => {
  const start = normalizeTime(bookingDate, startTime);
  const end = normalizeTime(bookingDate, endTime);

  const duplicate = await prisma.roomBooking.findFirst({
    where: {
      roomId: parseInt(roomId),
      bookingDate: new Date(bookingDate),
      status: { not: 'Cancelled' }, // ไม่นับรายการที่ถูกยกเลิกไปแล้ว
      AND: [
        { startTime: { lt: end } },  // เวลาเริ่มที่ขอใหม่ ต้องน้อยกว่า เวลาจบที่มีอยู่แล้ว
        { endTime: { gt: start } }   // เวลาจบที่ขอใหม่ ต้องมากกว่า เวลาเริ่มที่มีอยู่แล้ว
      ]
    }
  });
  return duplicate; 
};

// ==========================================
// [POST] /api/bookings/check-availability - API เช็คเวลาซ้ำสำหรับ Frontend
// ==========================================
exports.checkAvailability = async (req, res, next) => {
  try {
    const { room_id, booking_date, start_time, end_time } = req.body;

    // Validation เบื้องต้น
    if (!room_id || !booking_date || !start_time || !end_time) {
      return res.status(400).json({ 
        success: false, 
        message: 'กรุณากรอกข้อมูลให้ครบถ้วน (room_id, booking_date, start_time, end_time)' 
      });
    }

    const isOverlap = await checkOverlapping(room_id, booking_date, start_time, end_time);

    if (isOverlap) {
      return res.status(409).json({
        success: false,
        available: false,
        message: '❌ ช่วงเวลาดังกล่าวถูกจองไว้แล้ว ไม่สามารถจองซ้ำได้'
      });
    }

    return res.status(200).json({
      success: true,
      available: true,
      message: '✨ ช่วงเวลานี้ว่าง สามารถทำการจองได้'
    });

  } catch (error) {
    next(error); 
  }
};

// ==========================================
// [POST] /api/bookings - API สร้างรายการจองห้องประชุม
// ==========================================
exports.createBooking = async (req, res, next) => {
  try {
    const { room_id, user_id, booking_date, start_time, end_time, title } = req.body;

    // 1. Validation ดักจับข้อมูลไม่ครบ
    if (!room_id || !user_id || !booking_date || !start_time || !end_time || !title) {
      return res.status(400).json({ 
        success: false, 
        message: 'กรุณากรอกข้อมูลที่จำเป็นให้ครบถ้วน' 
      });
    }

    // 2. ตรวจสอบเวลาซ้ำอีกครั้งก่อนบันทึกจริงเพื่อความปลอดภัย 
    const isOverlap = await checkOverlapping(room_id, booking_date, start_time, end_time);
    if (isOverlap) {
      return res.status(409).json({ 
        success: false, 
        message: 'ไม่สามารถจองได้ เนื่องจากช่วงเวลาดังกล่าวถูกจองไปแล้วในระบบ' 
      });
    }

    // 3. บันทึกข้อมูลลง Database ผ่าน Prisma
    const newBooking = await prisma.roomBooking.create({
      data: {
        roomId: parseInt(room_id),
        userId: parseInt(user_id),
        bookingDate: new Date(booking_date),
        startTime: normalizeTime(booking_date, start_time),
        endTime: normalizeTime(booking_date, end_time),
        purpose: title, // แปลง title จาก req.body ลงคอลัมน์ purpose ตาม schema
        status: 'Booked'
      },
      include: {
        room: true 
      }
    });

    return res.status(201).json({
      success: true,
      message: '🎉 บันทึกการจองห้องประชุมเรียบร้อยแล้ว!',
      data: newBooking
    });

  } catch (error) {
    next(error);
  }
};

// ==========================================
// [GET] /api/bookings - API แสดงประวัติการจอง
// ==========================================
exports.getBookingHistory = async (req, res, next) => {
  try {
    const userId = req.query.user_id || req.body.user_id;
    const whereClause = userId ? { userId: parseInt(userId) } : {};

    const history = await prisma.roomBooking.findMany({
      where: whereClause,
      orderBy: { bookingDate: 'desc' },
      include: { 
        room: true, 
        user: true 
      }
    });

    return res.status(200).json({
      success: true,
      data: history
    });

  } catch (error) {
    next(error);
  }
};

// ==========================================
// [PATCH] /api/bookings/:id/cancel - API ยกเลิกการจอง (Soft Delete)
// ==========================================
exports.cancelBooking = async (req, res, next) => {
  try {
    const bookingId = parseInt(req.params.id);

    // 1. ตรวจสอบว่ามีรายการจองนี้อยู่ในระบบหรือไม่
    const existingBooking = await prisma.roomBooking.findUnique({
      where: { id: bookingId }
    });

    if (!existingBooking) {
      return res.status(404).json({ 
        success: false, 
        message: 'ไม่พบข้อมูลการจองนี้ในระบบ' 
      });
    }

    // 2. อัปเดตสถานะเป็น Cancelled (Soft Delete)
    const updatedBooking = await prisma.roomBooking.update({
      where: { id: bookingId },
      data: { status: 'Cancelled' }
    });

    return res.status(200).json({
      success: true,
      message: '✅ ยกเลิกการจองสำเร็จ! ห้องกลับมาสถานะว่างในช่วงเวลานั้นแล้ว',
      data: updatedBooking
    });

  } catch (error) {
    next(error);
  }
};