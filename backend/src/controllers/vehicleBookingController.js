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
// 💡 โลจิกสำหรับตรวจสอบเวลาจองรถซ้ำ (Reusable Function)
// =========================================================================
const checkVehicleOverlapping = async (vehicleId, start, end) => {
  const duplicate = await prisma.vehicleBooking.findFirst({
    where: {
      vehicleId: parseInt(vehicleId),
      // ✅ [FIX COLLISION LOGIC]: เปลี่ยนเป็น notIn เพื่อมองข้ามคิวที่เคลียร์แล้ว/ยกเลิกแล้ว
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
// [POST] /api/vehicle-bookings/check-availability - เช็คเวลาซ้ำสำหรับ Frontend
// =========================================================================
exports.checkAvailability = async (req, res, next) => {
  try {
    const vehicleId = req.body?.vehicleId || req.body?.vehicle_id;
    const startDatetime = req.body?.startDatetime;
    const endDatetime = req.body?.endDatetime;
    const bookingDate = req.body?.bookingDate || req.body?.booking_date;
    const startTime = req.body?.startTime || req.body?.start_time;
    const endTime = req.body?.endTime || req.body?.end_time;

    const start = startDatetime ? new Date(startDatetime) : normalizeTime(bookingDate, startTime);
    const end = endDatetime ? new Date(endDatetime) : normalizeTime(bookingDate, endTime);

    if (!vehicleId || !start || !end) {
      return res.status(400).json({ 
        success: false, 
        message: 'กรุณากรอกข้อมูลรถยนต์และเวลาให้ครบถ้วน' 
      });
    }

    const isOverlap = await checkVehicleOverlapping(vehicleId, start, end);

    if (isOverlap) {
      return res.status(409).json({
        success: false,
        available: false,
        message: '❌ ช่วงเวลาดังกล่าวรถยนต์ถูกจองไว้แล้ว ไม่สามารถจองซ้ำได้',
        conflict: {
          id: isOverlap.id,
          purpose: isOverlap.purpose,
          destination: isOverlap.destination,
          time: `${isOverlap.startDatetime.toISOString()} - ${isOverlap.endDatetime.toISOString()}`
        }
      });
    }

    return res.status(200).json({
      success: true,
      available: true,
      message: '✨ ช่วงเวลานี้ว่าง สามารถทำการจองรถยนต์ได้'
    });

  } catch (error) {
    next(error); 
  }
};

// =========================================================================
// [POST] /api/vehicle-bookings/book - API สร้างรายการจองรถยนต์
// =========================================================================
exports.createBooking = async (req, res, next) => {
  try {
    const {
      vehicleId,
      startDatetime,
      endDatetime,
      purpose,
      destination,
      passengers = 1
    } = req.body;
    
    // ✅ [JWT KEY CORRECTION]: ดึงข้อมูลจาก Token ตรงๆ ป้องกัน IDOR & Token Payload Mismatch
    const tokenUserId = req.user?.userId;

    if (!tokenUserId) {
      return res.status(401).json({
        success: false,
        message: 'ปฏิเสธการเข้าถึง: ไม่พบเซสชันผู้ใช้งานที่ถูกต้อง กรุณาเข้าสู่ระบบใหม่'
      });
    }

    if (!vehicleId || !startDatetime || !endDatetime || !purpose || !destination) {
      return res.status(400).json({ 
        success: false, 
        message: 'กรุณากรอกข้อมูลที่จำเป็นให้ครบถ้วน (vehicleId, startDatetime, endDatetime, purpose, destination)' 
      });
    }

    // ✅ [BACKEND VALIDATION 1]: ตรวจสอบจำนวนผู้โดยสาร
    const parsedPassengers = parseInt(passengers);
    if (isNaN(parsedPassengers) || parsedPassengers <= 0) {
      return res.status(400).json({
        success: false,
        message: 'จำนวนผู้โดยสาร (passengers) ต้องเป็นตัวเลขที่ถูกต้องและมีค่ามากกว่า 0'
      });
    }

    // ✅ [BACKEND VALIDATION 2]: ตรวจสอบลอจิกด้านวันเวลา
    const start = new Date(startDatetime);
    const end = new Date(endDatetime);

    if (isNaN(start.getTime()) || isNaN(end.getTime())) {
      return res.status(400).json({
        success: false,
        message: 'รูปแบบของวันที่และเวลาไม่ถูกต้อง'
      });
    }

    if (start >= end) {
      return res.status(400).json({
        success: false,
        message: 'เวลาสิ้นสุดการจอง (endDatetime) ต้องมากกว่าเวลาเริ่มต้นการจอง (startDatetime)'
      });
    }

    // ✅ [BACKEND VALIDATION 3]: ป้องกันการจองย้อนหลัง (เปิด Buffer ไว้ 5 นาทีเผื่อ Latency)
    const now = new Date();
    if (start < new Date(now.getTime() - 5 * 60 * 1000)) {
      return res.status(400).json({
        success: false,
        message: 'ไม่สามารถทำจองช่วงเวลาย้อนหลังได้'
      });
    }

    // ✅ [BACKEND VALIDATION 4 & 5]: เช็คว่ารถและยูสเซอร์มีตัวตนจริงในฐานข้อมูลหรือไม่
    const targetVehicle = await prisma.vehicle.findUnique({
      where: { id: parseInt(vehicleId), isDeleted: false }
    });
    if (!targetVehicle) {
      return res.status(404).json({
        success: false,
        message: 'ไม่พบข้อมูลรถยนต์คันนี้ในระบบ หรือรถยนต์ถูกระงับการใช้งานชั่วคราว'
      });
    }

    const targetUser = await prisma.user.findUnique({
      where: { id: tokenUserId }
    });
    if (!targetUser) {
      return res.status(404).json({
        success: false,
        message: 'ไม่พบประวัติพนักงานผู้จองนี้ในระบบ'
      });
    }

    // ตรวจสอบคิวรถยนต์ชนซ้ำ
    const isOverlap = await checkVehicleOverlapping(vehicleId, start, end);
    if (isOverlap) {
      return res.status(409).json({ 
        success: false, 
        message: 'ไม่สามารถทำจองรถยนต์ได้ เนื่องจากช่วงเวลาดังกล่าวถูกจองคิวไปแล้วในระบบ' 
      });
    }

    // ✅ [TRANSACTION FLOW]: ควบคุมการสร้างจอง, ล็อคสถานะรถยนต์, และเขียนประวัติ
    const newBooking = await prisma.$transaction(async (tx) => {
      // 1. สร้างเอกสารการจอง
      const booking = await tx.vehicleBooking.create({
        data: {
          vehicleId: parseInt(vehicleId), 
          userId: tokenUserId,
          destination: destination,
          passengers: parsedPassengers,
          startDatetime: start,     
          endDatetime: end,         
          purpose: purpose,           
          status: 'Pending'         
        },
        include: {
          vehicle: true,
          user: {
            select: {
              id: true,
              employee: {
                select: {
                  fullName: true,
                  employeeCode: true
                }
              }
            }
          }
        }
      });

      // 2. อัปเดตสถานะรถเป็น RESERVED ป้องกันการจองทับซ้อนทางกายภาพ
      await tx.vehicle.update({
        where: { id: parseInt(vehicleId) },
        data: { status: 'RESERVED' }
      });

      // 3. บันทึกประวัติการทำธุรกรรมลงตาราง History
      await tx.vehicleBookingHistory.create({
        data: {
          vehicleBookingId: booking.id,
          changedById: tokenUserId,
          action: 'CREATED',
          statusSnapshot: 'Pending',
          remark: 'สร้างการจองรถยนต์ใหม่ผ่านระบบและเตรียมล็อคคิวรถ'
        }
      });

      return booking;
    });

    return res.status(201).json({
      success: true,
      message: '🎉 บันทึกการจองรถยนต์และประวัติเรียบร้อยแล้ว!',
      data: newBooking
    });

  } catch (error) {
    next(error);
  }
};

// =========================================================================
// [GET] /api/vehicle-bookings - ดึงประวัติการจองทั้งหมด (สำหรับ Admin หรือ Filter)
// =========================================================================
exports.getBookingHistory = async (req, res, next) => {
  try {
    const tokenUserId = req.user?.userId;
    const tokenRole = req.user?.role;

    if (!tokenUserId) {
      return res.status(401).json({
        success: false,
        message: 'ปฏิเสธการเข้าถึง: กรุณาเข้าสู่ระบบก่อนทำรายการ'
      });
    }

    // ✅ [IDOR PROTECTION]: หากไม่ใช่ ADMIN จะถูกบังคับให้เห็นเฉพาะการจองของตนเองเท่านั้น
    let whereClause = {};
    if (tokenRole !== 'ADMIN') {
      whereClause.userId = tokenUserId;
    } else {
      const targetUserId = req.query?.userId || req.query?.user_id;
      if (targetUserId) {
        whereClause.userId = parseInt(targetUserId);
      }
    }

    const page = parseInt(req.query?.page) || 1;
    const limit = parseInt(req.query?.limit) || 10;
    const skip = (page - 1) * limit;

    const [totalItems, history] = await Promise.all([
      prisma.vehicleBooking.count({ where: whereClause }),
      prisma.vehicleBooking.findMany({
        where: whereClause,
        orderBy: { startDatetime: 'desc' },
        skip: skip,
        take: limit,
        include: { 
          vehicle: true,
          user: {
            select: {
              id: true,
              employee: {
                select: {
                  fullName: true,
                  employeeCode: true
                }
              }
            }
          }
        }
      })
    ]);

    return res.status(200).json({
      success: true,
      message: "ดึงข้อมูลรายการจองรถยนต์สำเร็จ",
      data: {
        bookings: history,
        pagination: {
          totalItems,
          totalPages: Math.ceil(totalItems / limit),
          currentPage: page,
          limit
        }
      }
    });

  } catch (error) {
    next(error);
  }
};

// =========================================================================
// [GET] /api/vehicle-bookings/history - ดึงประวัติการจองของ "ผู้ใช้งานที่กำลังเข้าสู่ระบบ"
// =========================================================================
exports.getUserBookings = async (req, res, next) => {
  try {
    const tokenUserId = req.user?.userId;

    if (!tokenUserId) {
      return res.status(401).json({
        success: false,
        message: 'กรุณาเข้าสู่ระบบใหม่ เซสชันผู้ใช้งานหมดอายุ'
      });
    }

    const page = parseInt(req.query?.page) || 1;
    const limit = parseInt(req.query?.limit) || 10;
    const skip = (page - 1) * limit;

    // ✅ บังคับล็อคที่ ID ของ token ป้องกัน IDOR 100%
    const whereClause = { userId: tokenUserId };

    const [totalItems, history] = await Promise.all([
      prisma.vehicleBooking.count({ where: whereClause }),
      prisma.vehicleBooking.findMany({
        where: whereClause,
        orderBy: { startDatetime: 'desc' },
        skip: skip,
        take: limit,
        include: { 
          vehicle: true
        }
      })
    ]);

    return res.status(200).json({
      success: true,
      message: "ดึงประวัติการจองรถยนต์ของคุณสำเร็จเรียบร้อย",
      data: {
        bookings: history,
        pagination: {
          totalItems,
          totalPages: Math.ceil(totalItems / limit),
          currentPage: page,
          limit
        }
      }
    });

  } catch (error) {
    next(error);
  }
};

// =========================================================================
// [GET] /api/vehicle-bookings/:id - ดูรายละเอียดการจองรถยนต์รายการเดียว
// =========================================================================
exports.getBookingById = async (req, res, next) => {
  try {
    const bookingId = parseInt(req.params.id);
    const tokenUserId = req.user?.userId;
    const tokenRole = req.user?.role;

    if (isNaN(bookingId)) {
      return res.status(400).json({
        success: false,
        message: 'รหัสรายการจองรถต้องเป็นตัวเลขที่ถูกต้องเท่านั้น'
      });
    }

    const booking = await prisma.vehicleBooking.findUnique({
      where: { id: bookingId },
      include: {
        vehicle: true,
        user: {
          select: {
            id: true,
            employee: {
              select: {
                fullName: true,
                employeeCode: true
              }
            }
          }
        },
        histories: {
          orderBy: { createdAt: 'desc' },
          include: {
            changedBy: {
              select: {
                employee: {
                  select: {
                    fullName: true
                  }
                }
              }
            }
          }
        }
      }
    });

    if (!booking) {
      return res.status(404).json({
        success: false,
        message: 'ไม่พบประวัติรายละเอียดการจองรถยนต์นี้ในระบบ'
      });
    }

    // ✅ [IDOR PROTECTION]: คนธรรมดาดูได้แต่คิวตัวเอง ส่วน ADMIN ดูได้หมดทุกคิว
    if (tokenRole !== 'ADMIN' && booking.userId !== tokenUserId) {
      return res.status(403).json({
        success: false,
        message: 'ปฏิเสธการเข้าถึง: คุณไม่มีสิทธิ์ตรวจสอบรายละเอียดคิวจองของพนักงานคนอื่น'
      });
    }

    return res.status(200).json({
      success: true,
      message: 'ดึงข้อมูลรายละเอียดรายการจองสำเร็จ',
      data: booking
    });

  } catch (error) {
    next(error);
  }
};

// =========================================================================
// [PATCH] /api/vehicle-bookings/:id/cancel - ยกเลิกการจอง
// =========================================================================
exports.cancelBooking = async (req, res, next) => {
  try {
    const bookingId = parseInt(req.params.id);
    const tokenUserId = req.user?.userId;
    const tokenRole = req.user?.role;
    const cancelRemark = req.body?.remark || 'ยกเลิกการจองโดยผู้ใช้งาน';

    if (isNaN(bookingId)) {
      return res.status(400).json({
        success: false,
        message: 'รหัสรายการจองต้องเป็นตัวเลขที่ถูกต้องเท่านั้น'
      });
    }

    if (!tokenUserId) {
      return res.status(401).json({
        success: false,
        message: 'กรุณาเข้าสู่ระบบใหม่เพื่อทำรายการยกเลิก'
      });
    }

    const existingBooking = await prisma.vehicleBooking.findUnique({
      where: { id: bookingId }
    });

    if (!existingBooking) {
      return res.status(404).json({ 
        success: false, 
        message: 'ไม่พบข้อมูลการจองนี้ในระบบ' 
      });
    }

    // ✅ [IDOR PROTECTION]: ตรวจสอบว่าผู้ทำรายการเป็นพนักงานคนเดียวกัน หรือเป็นผู้ดูแลระบบ
    if (tokenRole !== 'ADMIN' && existingBooking.userId !== tokenUserId) {
      return res.status(403).json({
        success: false,
        message: 'ปฏิเสธการเข้าถึง: คุณไม่มีสิทธิ์ยกเลิกคิวรถของผู้อื่น'
      });
    }

    // ป้องกันการยกเลิกซ้ำ
    if (existingBooking.status === 'Cancelled' || existingBooking.status === 'CANCELLED') {
      return res.status(400).json({
        success: false,
        message: 'รายการนี้ได้รับการยกเลิกไปแล้วในระบบ'
      });
    }

    // ✅ [TRANSACTION FLOW]: ปลอดภัยไม่เกิดข้อมูลคงค้าง
    const updatedBooking = await prisma.$transaction(async (tx) => {
      // 1. อัปเดตสถานะเอกสารการจอง
      const booking = await tx.vehicleBooking.update({
        where: { id: bookingId },
        data: { status: 'CANCELLED' }
      });

      // 2. ปลดสถานะรถคืนสู่ "ว่างใช้งาน (AVAILABLE)"
      await tx.vehicle.update({
        where: { id: booking.vehicleId },
        data: { status: 'AVAILABLE' }
      });

      // 3. บันทึก Transaction ประวัติการเขียนล็อกยกเลิก
      await tx.vehicleBookingHistory.create({
        data: {
          vehicleBookingId: bookingId,
          changedById: tokenUserId,
          action: 'CANCELLED',
          statusSnapshot: 'CANCELLED',
          remark: cancelRemark
        }
      });

      return booking;
    });

    return res.status(200).json({
      success: true,
      message: '✅ ยกเลิกการจองรถยนต์สำเร็จ! บันทึกประวัติและปลดสถานะรถให้พร้อมใช้งานแล้ว',
      data: updatedBooking
    });

  } catch (error) {
    next(error);
  }
};