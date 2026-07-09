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
      // 🔥 มองข้ามคิวที่ยกเลิกไปแล้ว หรือ คืนห้องเสร็จสิ้นแล้ว
      status: { 
        notIn: ['Cancelled', 'CANCELLED', 'COMPLETED', 'Completed', 'Rejected', 'REJECTED'] 
      },
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
// [POST] /api/bookings - API สร้างรายการจองห้องประชุม (อัปเดตระบบ History)
// =========================================================================
exports.createBooking = async (req, res, next) => {
  try {
    const roomId = req.body?.roomId || req.body?.room_id;
    const startDatetime = req.body?.startDatetime;
    const endDatetime = req.body?.endDatetime;
    const title = req.body?.title || req.body?.purpose;
    const rawUserId = req.body?.userId || req.body?.user_id || (req.user ? req.user.userId : null);

    if (!roomId || !rawUserId || !startDatetime || !endDatetime || !title) {
      return res.status(400).json({ 
        success: false, 
        message: 'กรุณากรอกข้อมูลที่จำเป็นให้ครบถ้วน' 
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

    const newBooking = await prisma.$transaction(async (tx) => {
      const booking = await tx.roomBooking.create({
        data: {
          roomId: parseInt(roomId), 
          userId: userId, 
          startDatetime: start,     
          endDatetime: end,         
          purpose: title,           
          status: 'Pending'         
        },
        include: { room: true }
      });

      await tx.room.update({
        where: { id: parseInt(roomId) },
        data: { status: 'RESERVED' },
      });

      await tx.roomBookingHistory.create({
        data: {
          roomBookingId: booking.id,
          changedById: userId,
          action: 'CREATED',
          statusSnapshot: 'Pending',
          remark: 'สร้างการจองห้องประชุมใหม่'
        }
      });

      return booking;
    });

    return res.status(201).json({
      success: true,
      message: '🎉 บันทึกการจองห้องประชุมและประวัติเรียบร้อยแล้ว!',
      data: newBooking
    });

  } catch (error) {
    if (error.code === 'P2003') {
      return res.status(400).json({
        success: false,
        message: 'ไม่สามารถจองได้ เนื่องจากไม่พบรหัสผู้ใช้งานหรือห้องประชุม'
      });
    }
    next(error);
  }
};

// =========================================================================
// [GET] /api/bookings - API แสดงประวัติการจอง 
// =========================================================================
exports.getBookingHistory = async (req, res) => { 
  try {
    let rawUserId = req.query?.userId || req.query?.user_id || req.user?.userId || req.user?.id;
    let whereClause = {};

    if (rawUserId && rawUserId !== 'null' && rawUserId !== 'undefined') {
      const parsedUserId = parseInt(rawUserId, 10);
      if (!isNaN(parsedUserId)) {
        if (req.user?.role !== 'ADMIN') {
          whereClause = { userId: parsedUserId };
        }
      }
    }

    const page = parseInt(req.query?.page) || 1;
    const limit = parseInt(req.query?.limit) || 10;
    const skip = (page - 1) * limit;

    const [totalItems, history] = await Promise.all([
      prisma.roomBooking.count({ where: whereClause }),
      prisma.roomBooking.findMany({
        where: whereClause,
        orderBy: { startDatetime: 'desc' },
        skip: skip,
        take: limit,
        include: { 
          room: true, 
          user: { include: { employee: true } }
        }
      })
    ]);

    return res.status(200).json({
      success: true,
      message: "ดึงข้อมูลรายการจองสำเร็จ",
      pagination: {
        totalItems,
        totalPages: Math.ceil(totalItems / limit),
        currentPage: page,
        limit
      },
      bookings: history
    });

  } catch (error) {
    console.error("❌ GET /api/bookings Error: ", error);
    return res.status(500).json({
      success: false,
      message: "เซิร์ฟเวอร์เกิดข้อผิดพลาดในการดึงข้อมูลประวัติการจอง",
      error: error.message
    });
  }
};

// =========================================================================
// [PATCH] /api/bookings/:id/cancel - API ยกเลิกการจอง
// =========================================================================
exports.cancelBooking = async (req, res, next) => {
  try {
    const bookingId = parseInt(req.params.id);
    const rawUserId = req.body?.userId || req.body?.user_id || (req.user ? req.user.userId : null);
    const cancelRemark = req.body?.remark || 'ยกเลิกการจองโดยผู้ใช้งาน';

    if (isNaN(bookingId)) {
      return res.status(400).json({ success: false, message: 'รหัสรายการจองไม่ถูกต้อง' });
    }

    if (!rawUserId) {
      return res.status(400).json({ success: false, message: 'กรุณาระบุรหัสผู้ใช้งาน (userId)' });
    }

    const existingBooking = await prisma.roomBooking.findUnique({
      where: { id: bookingId }
    });

    if (!existingBooking) {
      return res.status(404).json({ success: false, message: 'ไม่พบข้อมูลการจองนี้ในระบบ' });
    }

    const updatedBooking = await prisma.$transaction(async (tx) => {
      const booking = await tx.roomBooking.update({
        where: { id: bookingId },
        data: { status: 'CANCELLED' } // 💡 แก้ให้ตัวพิมพ์ใหญ่ตรงกันหมด
      });

      await tx.room.update({
        where: { id: booking.roomId },
        data: { status: 'AVAILABLE' },
      });

      await tx.roomBookingHistory.create({
        data: {
          roomBookingId: bookingId,
          changedById: parseInt(rawUserId),
          action: 'CANCELLED',
          statusSnapshot: 'CANCELLED',
          remark: cancelRemark
        }
      });

      return booking;
    });

    return res.status(200).json({
      success: true,
      message: '✅ ยกเลิกการจองสำเร็จ! บันทึกประวัติเรียบร้อยแล้ว',
      data: updatedBooking
    });

  } catch (error) {
    next(error);
  }
};

// =========================================================================
// 🚀 [PUT] /api/bookings/:id - API อัปเดตสถานะต่างๆ (เช่น คืนห้องเสร็จสิ้น)
// =========================================================================
exports.updateBookingStatus = async (req, res, next) => {
  try {
    const bookingId = parseInt(req.params.id);
    const { status, remark } = req.body;
    
    // ดึงรหัสพนักงานจาก Token หรือที่ส่งมาใน Body
    const rawUserId = req.body?.userId || req.body?.user_id || (req.user ? req.user.userId : null);

    if (isNaN(bookingId)) {
      return res.status(400).json({ success: false, message: 'รหัสรายการจองไม่ถูกต้อง' });
    }

    if (!rawUserId || !status) {
      return res.status(400).json({ success: false, message: 'ข้อมูลสำหรับอัปเดตสถานะไม่ครบถ้วน' });
    }

    // 1. ค้นหาการจองเดิมก่อน
    const existingBooking = await prisma.roomBooking.findUnique({
      where: { id: bookingId }
    });

    if (!existingBooking) {
      return res.status(404).json({ success: false, message: 'ไม่พบรายการจองนี้ในระบบ' });
    }

    // 2. ใช้ Transaction เพื่ออัปเดตตารางที่เกี่ยวข้องทั้งหมดพร้อมกัน
    const updatedBooking = await prisma.$transaction(async (tx) => {
      
      // อัปเดตสถานะการจอง (เช่น เป็น COMPLETED หรือ CANCELLED)
      const booking = await tx.roomBooking.update({
        where: { id: bookingId },
        data: { status: status }
      });

      // ปลดล็อกห้องให้กลับมาว่าง (AVAILABLE) หากสถานะคือ คืนห้อง หรือ ยกเลิก
      if (status === 'COMPLETED' || status === 'CANCELLED') {
        await tx.room.update({
          where: { id: booking.roomId },
          data: { status: 'AVAILABLE' }
        });
      }

      // บันทึกประวัติการเปลี่ยนสถานะลง Audit Log
      await tx.roomBookingHistory.create({
        data: {
          roomBookingId: bookingId,
          changedById: parseInt(rawUserId), 
          action: status === 'COMPLETED' ? 'COMPLETED' : 'STATUS_CHANGED',
          statusSnapshot: status,
          remark: remark || `อัปเดตสถานะเป็น ${status}`
        }
      });

      return booking;
    });

    return res.status(200).json({ 
      success: true, 
      message: 'อัปเดตสถานะการจองเรียบร้อยแล้ว',
      data: updatedBooking
    });

  } catch (error) {
    next(error);
  }
};