const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// =========================================================================
// Helper Function: สำหรับแปลงสตริงเวลาให้เป็น Date Object 
// =========================================================================
const normalizeTime = (dateString, timeString) => {
  if (!dateString || !timeString) return null;
  const datePart = new Date(dateString).toISOString().split('T')[0];
  const isTimeOnly = timeString.match(/^([01]\d|2[0-3]):([0-5]\d)(:[0-5]\d)?$/);
  if (isTimeOnly) {
    return new Date(`${datePart}T${timeString}.000Z`);
  }
  return new Date(timeString);
};

// =========================================================================
// 💡 โลจิกสำหรับตรวจสอบเวลาจองซ้ำ (Reusable Function)
// =========================================================================
const checkOverlapping = async (roomId, start, end) => {
  const duplicate = await prisma.roomBooking.findFirst({
    where: {
      roomId: parseInt(roomId),
      status: { not: "Cancelled" },
      AND: [
        { startDatetime: { lt: end } }, 
        { endDatetime: { gt: start } }
      ]
    }
  });
  return duplicate; 
};

// =========================================================================
// [POST] /api/bookings/check-availability - API เช็คเวลาซ้ำสำหรับ Frontend
// =========================================================================
exports.checkAvailability = async (req, res, next) => {
  try {
    const roomId = req.body?.roomId || req.body?.room_id;
    const startDatetime = req.body?.startDatetime;
    const endDatetime = req.body?.endDatetime;
    const bookingDate = req.body?.bookingDate || req.body?.booking_date;
    const startTime = req.body?.startTime || req.body?.start_time;
    const endTime = req.body?.endTime || req.body?.end_time;

    const start = startDatetime ? new Date(startDatetime) : normalizeTime(bookingDate, startTime);
    const end = endDatetime ? new Date(endDatetime) : normalizeTime(bookingDate, endTime);

    if (!roomId || !start || !end) {
      return res.status(400).json({ 
        success: false, 
        message: 'กรุณากรอกข้อมูลห้องและเวลาให้ครบถ้วน' 
      });
    }

    const isOverlap = await checkOverlapping(roomId, start, end);

    if (isOverlap) {
      return res.status(409).json({
        success: false,
        available: false,
        message: '❌ ช่วงเวลาดังกล่าวถูกจองไว้แล้ว ไม่สามารถจองซ้ำได้',
        conflict: {
          id: isOverlap.id,
          title: isOverlap.purpose,
          time: `${isOverlap.startDatetime.toISOString()} - ${isOverlap.endDatetime.toISOString()}`
        }
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

// =========================================================================
// [POST] /api/bookings - API สร้างรายการจองห้องประชุม
// =========================================================================
exports.createBooking = async (req, res, next) => {
  try {
    const roomId = req.body?.roomId || req.body?.room_id;
    const startDatetime = req.body?.startDatetime;
    const endDatetime = req.body?.endDatetime;
    const title = req.body?.title || req.body?.purpose;
    const rawUserId = req.body?.userId || req.body?.user_id || (req.user ? req.user.id : null);

    if (!roomId || !rawUserId || !startDatetime || !endDatetime || !title) {
      return res.status(400).json({ 
        success: false, 
        message: 'กรุณากรอกข้อมูลที่จำเป็นให้ครบถ้วน (roomId, userId, startDatetime, endDatetime, title)' 
      });
    }

    const userId = parseInt(rawUserId);
    const start = new Date(startDatetime);
    const end = new Date(endDatetime);

    if (isNaN(start.getTime()) || isNaN(end.getTime())) {
      return res.status(400).json({
        success: false,
        message: 'รูปแบบของวันที่และเวลาไม่ถูกต้อง'
      });
    }

    const isOverlap = await checkOverlapping(roomId, start, end);
    if (isOverlap) {
      return res.status(409).json({ 
        success: false, 
        message: 'ไม่สามารถจองได้ เนื่องจากช่วงเวลาดังกล่าวถูกจองไปแล้วในระบบ' 
      });
    }

    const newBooking = await prisma.roomBooking.create({
      data: {
        roomId: parseInt(roomId), 
        userId: userId, 
        startDatetime: start,     
        endDatetime: end,         
        purpose: title,           
        status: 'Pending'         
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
    if (error.code === 'P2003') {
      return res.status(400).json({
        success: false,
        message: 'ไม่สามารถจองได้ เนื่องจากไม่พบรหัสผู้ใช้งาน (userId) หรือห้องประชุม (roomId) นี้ในระบบคลังข้อมูล'
      });
    }
    next(error);
  }
};

// =========================================================================
// [GET] /api/bookings - API แสดงประวัติการจอง (Optimize เพิ่ม Pagination ป้องกันค้าง)
// =========================================================================
exports.getBookingHistory = async (req, res, next) => {
  try {
    // แก้บั๊ก: อ่านจาก query หรือ token เท่านั้น ห้ามอ่านจาก req.body ใน GET Request
    const userId = req.query?.userId || req.query?.user_id || req.user?.id;
    const whereClause = userId ? { userId: parseInt(userId) } : {};

    // 💡 การแบ่งหน้า (Pagination) เพื่อเพิ่มประสิทธิภาพ (Optimize)
    const page = parseInt(req.query?.page) || 1;
    const limit = parseInt(req.query?.limit) || 10;
    const skip = (page - 1) * limit;

    // รันนับจำนวนรวมและดึงข้อมูลพร้อมกัน (Parallel) ช่วยให้โหลดไวขึ้น
    const [totalItems, history] = await Promise.all([
      prisma.roomBooking.count({ where: whereClause }),
      prisma.roomBooking.findMany({
        where: whereClause,
        orderBy: { startDatetime: 'desc' },
        skip: skip,
        take: limit,
        include: { 
          room: true, 
          user: {
            include: {
              employee: true
            }
          }
        }
      })
    ]);

    return res.status(200).json({
      success: true,
      message: "ดึงข้อมูลรายการจองสำเร็จ (Booking API is ready to use!)",
      pagination: {
        totalItems,
        totalPages: Math.ceil(totalItems / limit),
        currentPage: page,
        limit
      },
      bookings: history
    });

  } catch (error) {
    next(error);
  }
};

// =========================================================================
// [PATCH] /api/bookings/:id/cancel - API ยกเลิกการจอง (Soft Delete)
// =========================================================================
exports.cancelBooking = async (req, res, next) => {
  try {
    const bookingId = parseInt(req.params.id);

    if (isNaN(bookingId)) {
      return res.status(400).json({
        success: false,
        message: 'รหัสรายการจองต้องเป็นตัวเลขที่ถูกต้องเท่านั้น'
      });
    }

    const existingBooking = await prisma.roomBooking.findUnique({
      where: { id: bookingId }
    });

    if (!existingBooking) {
      return res.status(404).json({ 
        success: false, 
        message: 'ไม่พบข้อมูลการจองนี้ในระบบ' 
      });
    }

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