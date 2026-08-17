const { PrismaClient, BookingStatus } = require('@prisma/client');
const prisma = new PrismaClient();
const notificationService = require('../services/notificationService'); // 🟢 1. นำเข้า notificationService

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
      status: { 
        notIn: [BookingStatus.CANCELLED, BookingStatus.COMPLETED, BookingStatus.REJECTED] 
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
// [POST] /api/bookings - API สร้างรายการจองห้องประชุม
// =========================================================================
exports.createBooking = async (req, res, next) => {
  try {
    const roomId = req.body?.roomId || req.body?.room_id;
    const startDatetime = req.body?.startDatetime;
    const endDatetime = req.body?.endDatetime;
    const title = req.body?.title || req.body?.purpose;
    const rawUserId = req.body?.userId || req.body?.user_id || (req.user ? (req.user.userId || req.user.id) : null);

    if (!roomId || !rawUserId || !startDatetime || !endDatetime || !title) {
      return res.status(400).json({ 
        success: false, 
        message: 'กรุณากรอกข้อมูลที่จำเป็นให้ครบถ้วน' 
      });
    }
    const userId = parseInt(rawUserId);
    const start = new Date(startDatetime);
    const end = new Date(endDatetime);

    // 1. เพิ่ม Time Validation 
    if (isNaN(start.getTime()) || isNaN(end.getTime())) {
      return res.status(400).json({ success: false, message: 'รูปแบบของวันที่และเวลาไม่ถูกต้อง' });
    }

    if (start >= end) {
      return res.status(400).json({ success: false, message: 'เวลาสิ้นสุดการจองต้องมากกว่าเวลาเริ่มต้น' });
    }

    const now = new Date();
    if (start < now) {
      return res.status(400).json({ success: false, message: 'ไม่สามารถจองห้องประชุมย้อนหลังได้' });
    }

    const isOverlap = await checkOverlapping(roomId, start, end);
    if (isOverlap) {
      return res.status(409).json({ 
        success: false, 
        message: 'ไม่สามารถจองได้ เนื่องจากช่วงเวลาดังกล่าวถูกจองไปแล้วในระบบ' 
      });
    }

    // 2. นำ AuditLog เข้ามารวมใน Transaction
    const newBooking = await prisma.$transaction(async (tx) => {
      const booking = await tx.roomBooking.create({
        data: {
          roomId: parseInt(roomId), 
          userId: userId, 
          startDatetime: start,     
          endDatetime: end,         
          purpose: title,           
          status: BookingStatus.PENDING // เปลี่ยนกลับเป็น PENDING เพื่อรออนุมัติ
        },
        include: { room: true }
      });

      // 🟢 บันทึก AuditLog ภายใน Transaction เพื่อเป็น Single Source of Truth
      await tx.auditLog.create({
        data: {
          action: "CREATE_ROOM_BOOKING",
          module: "ROOM_BOOKING",
          entityId: booking.id,
          entityType: "ROOM_BOOKING",
          userId: userId,
          details: JSON.stringify({
            newStatus: BookingStatus.PENDING,
            remark: 'สร้างการจองห้องประชุมใหม่ รอการอนุมัติ'
          })
        }
      });

      return booking;
    });

    // 🔔 2. แจ้งเตือน Admin ว่ามีรายการขอจองห้องใหม่
    await notificationService.notifyAdmins({
      title: "มีคำขอจองห้องประชุมใหม่",
      message: `รอการอนุมัติ: ห้องประชุม ${newBooking.room.roomName} (หัวข้อ: ${title})`,
      type: 'APPROVAL',
      entityType: 'ROOM_BOOKING',
      entityId: newBooking.id
    });

    return res.status(201).json({
      success: true,
      message: '🎉 บันทึกการจองห้องประชุมเรียบร้อย รอการอนุมัติ',
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
// [GET] /api/bookings - API แสดงประวัติการจอง พร้อมคำนวณ Permissions ให้ Frontend
// =========================================================================
exports.getBookingHistory = async (req, res, next) => { 
  try {
    let rawUserId = req.query?.userId || req.query?.user_id || req.user?.userId || req.user?.id;
    let whereClause = {};

    if (rawUserId && rawUserId !== 'null' && rawUserId !== 'undefined') {
      const parsedUserId = parseInt(rawUserId, 10);
      if (!isNaN(parsedUserId) && req.query.filterByUser === 'true') { 
         whereClause = { userId: parsedUserId };
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

    // 🟢 แปลงข้อมูลและแนบสิทธิ์ (Permissions) กลับไปให้ Frontend อัตโนมัติ
    const currentUserId = req.user ? parseInt(req.user.userId, 10) : null;
    const currentUserRole = req.user ? req.user.role : 'USER';
    
    const bookingsWithPermissions = history.map(booking => {
      const isOwner = currentUserId === booking.userId;
      const isAdmin = currentUserRole === 'ADMIN';
      const isPendingOrApproved = [BookingStatus.PENDING, BookingStatus.APPROVED].includes(booking.status);

      return {
        ...booking,
        permissions: {
          canCancel: (isOwner || isAdmin) && isPendingOrApproved,
          canEdit: (isOwner || isAdmin) && booking.status === BookingStatus.PENDING,
          canApprove: isAdmin && booking.status === BookingStatus.PENDING // เพิ่มสิทธิ์ Approve ให้ Frontend
        }
      };
    });

    return res.status(200).json({
      success: true,
      message: "ดึงข้อมูลรายการจองสำเร็จ",
      pagination: {
        totalItems,
        totalPages: Math.ceil(totalItems / limit),
        currentPage: page,
        limit
      },
      bookings: bookingsWithPermissions
    });

  } catch (error) {
    console.error("❌ GET /api/bookings Error: ", error);

    if (res.headersSent) {
      return next(error);
    }

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
    const cancelRemark = req.body?.remark || 'ยกเลิกการจองโดยผู้ใช้งาน';

    if (isNaN(bookingId)) {
      return res.status(400).json({ success: false, message: 'รหัสรายการจองไม่ถูกต้อง' });
    }

    const existingBooking = await prisma.roomBooking.findUnique({
      where: { id: bookingId }
    });

    if (!existingBooking) {
      return res.status(404).json({ success: false, message: 'ไม่พบข้อมูลการจองนี้ในระบบ' });
    }

    if (req.user.role === 'ADMIN') {
      // อนุญาต: ADMIN
    } else if (req.user.role === 'USER' && existingBooking.userId === parseInt(req.user.userId, 10)) {
      // อนุญาต: Owner USER
    } else {
      return res.status(403).json({ 
        success: false, 
        message: 'คุณไม่มีสิทธิ์แก้ไขหรือยกเลิกการจองของผู้อื่น' 
      });
    }

    const updatedBooking = await prisma.$transaction(async (tx) => {
      const booking = await tx.roomBooking.update({
        where: { id: bookingId },
        data: { status: BookingStatus.CANCELLED } 
      });

      await tx.room.update({
        where: { id: booking.roomId },
        data: { status: 'AVAILABLE' },
      });

      // 🟢 บันทึก AuditLog ภายใน Transaction
      await tx.auditLog.create({
        data: {
          action: "CANCEL_ROOM_BOOKING",
          module: "ROOM_BOOKING",
          entityId: bookingId,
          entityType: "ROOM_BOOKING",
          userId: parseInt(req.user.userId, 10),
          details: JSON.stringify({
            oldStatus: existingBooking.status,
            newStatus: BookingStatus.CANCELLED,
            remark: cancelRemark
          })
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
// [PUT] /api/bookings/:id - API อัปเดตสถานะต่างๆ
// =========================================================================
exports.updateBookingStatus = async (req, res, next) => {
  try {
    const bookingId = parseInt(req.params.id);
    const { status, remark } = req.body;

    if (isNaN(bookingId)) {
      return res.status(400).json({ success: false, message: 'รหัสรายการจองไม่ถูกต้อง' });
    }

    if (!status) {
      return res.status(400).json({ success: false, message: 'ข้อมูลสำหรับอัปเดตสถานะไม่ครบถ้วน' });
    }

    const existingBooking = await prisma.roomBooking.findUnique({
      where: { id: bookingId }
    });

    if (!existingBooking) {
      return res.status(404).json({ success: false, message: 'ไม่พบรายการจองนี้ในระบบ' });
    }

    if (req.user.role === 'ADMIN') {
      // อนุญาต: ADMIN
    } else if (req.user.role === 'USER' && existingBooking.userId === parseInt(req.user.userId, 10)) {
      // อนุญาต: Owner USER
    } else {
      return res.status(403).json({ 
        success: false, 
        message: 'คุณไม่มีสิทธิ์แก้ไขหรือยกเลิกการจองของผู้อื่น' 
      });
    }

    const validStatus = BookingStatus[status?.toUpperCase()];
    
    if (!validStatus) {
      return res.status(400).json({ success: false, message: 'สถานะไม่ถูกต้องตามระบบ' });
    }

    const updatedBooking = await prisma.$transaction(async (tx) => {
      const booking = await tx.roomBooking.update({
        where: { id: bookingId },
        data: { status: validStatus }
      });

      if (validStatus === BookingStatus.COMPLETED || validStatus === BookingStatus.CANCELLED) {
        await tx.room.update({
          where: { id: booking.roomId },
          data: { status: 'AVAILABLE' }
        });
      }

      // 🟢 บันทึก AuditLog ภายใน Transaction
      const auditAction = validStatus === BookingStatus.APPROVED ? "APPROVE_ROOM_BOOKING" : 
                         (validStatus === BookingStatus.COMPLETED ? "COMPLETED_ROOM_BOOKING" : "UPDATE_ROOM_BOOKING");
      
      await tx.auditLog.create({
        data: {
          action: auditAction,
          module: "ROOM_BOOKING",
          entityId: bookingId,
          entityType: "ROOM_BOOKING",
          userId: parseInt(req.user.userId, 10),
          details: JSON.stringify({
            oldStatus: existingBooking.status,
            newStatus: validStatus,
            remark: remark || `อัปเดตสถานะเป็น ${validStatus}`
          })
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

// =========================================================================
// 🟢 3. [POST] /api/bookings/:id/approve - API อนุมัติการจองห้องประชุม
// =========================================================================
exports.approveBooking = async (req, res, next) => {
  try {
    const bookingId = parseInt(req.params.id, 10);
    const adminId = parseInt(req.user.userId, 10);

    const booking = await prisma.roomBooking.findUnique({ where: { id: bookingId } });
    if (!booking) return res.status(404).json({ success: false, error: "ไม่พบการจอง" });

    // เปลี่ยนสถานะเป็น APPROVED และบันทึก Log
    const updatedBooking = await prisma.$transaction(async (tx) => {
      const updated = await tx.roomBooking.update({
        where: { id: bookingId },
        data: { status: BookingStatus.APPROVED }
      });

      await tx.auditLog.create({
        data: {
          action: 'APPROVE_ROOM_BOOKING',
          module: 'ROOM_BOOKING',
          userId: adminId,
          entityId: bookingId,
          entityType: 'ROOM_BOOKING',
          details: JSON.stringify({ oldStatus: booking.status, newStatus: BookingStatus.APPROVED })
        }
      });
      return updated;
    });

    // 🔔 ส่ง Notification แจ้งผู้จอง
    await notificationService.createNotification({
      userId: booking.userId,
      title: "✅ อนุมัติการจองห้องประชุม",
      message: `คำขอจองห้องประชุมของคุณ (อ้างอิง: ${booking.purpose}) ได้รับการอนุมัติแล้ว`,
      type: 'APPROVAL',
      entityType: 'ROOM_BOOKING',
      entityId: bookingId
    });

    return res.status(200).json({ success: true, data: updatedBooking, message: "อนุมัติสำเร็จ" });
  } catch (error) {
    next(error);
  }
};

// =========================================================================
// 🟢 4. [POST] /api/bookings/:id/reject - API ปฏิเสธการจองห้องประชุม
// =========================================================================
exports.rejectBooking = async (req, res, next) => {
  try {
    const bookingId = parseInt(req.params.id, 10);
    const adminId = parseInt(req.user.userId, 10);
    const { remark } = req.body;

    const booking = await prisma.roomBooking.findUnique({ where: { id: bookingId } });
    if (!booking) return res.status(404).json({ success: false, error: "ไม่พบการจอง" });

    // เปลี่ยนสถานะเป็น REJECTED, คืนห้องให้ AVAILABLE และบันทึก Log
    const updatedBooking = await prisma.$transaction(async (tx) => {
      const updated = await tx.roomBooking.update({
        where: { id: bookingId },
        data: { status: BookingStatus.REJECTED }
      });

      await tx.room.update({
        where: { id: booking.roomId },
        data: { status: 'AVAILABLE' }
      });

      await tx.auditLog.create({
        data: {
          action: 'REJECT_ROOM_BOOKING',
          module: 'ROOM_BOOKING',
          userId: adminId,
          entityId: bookingId,
          entityType: 'ROOM_BOOKING',
          details: JSON.stringify({ remark: remark || 'ปฏิเสธคำขอจองโดยผู้ดูแลระบบ' })
        }
      });
      return updated;
    });

    // 🔔 ส่ง Notification แจ้งผู้จอง
    await notificationService.createNotification({
      userId: booking.userId,
      title: "❌ ปฏิเสธการจองห้องประชุม",
      message: `คำขอจองห้องประชุมของคุณถูกปฏิเสธ หมายเหตุ: ${remark || 'ไม่ระบุเหตุผล'}`,
      type: 'APPROVAL',
      entityType: 'ROOM_BOOKING',
      entityId: bookingId
    });

    return res.status(200).json({ success: true, data: updatedBooking, message: "ปฏิเสธสำเร็จ" });
  } catch (error) {
    next(error);
  }
};