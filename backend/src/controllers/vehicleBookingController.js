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
      status: { not: "Cancelled" }, // ยกเว้นรายการที่ถูกยกเลิกไปแล้ว
      AND: [
        { startDatetime: { lt: end } }, 
        { endDatetime: { gt: start } }
      ]
    }
  });
  return duplicate; 
};

// =========================================================================
// [POST] /api/vehicle-bookings/check-availability - API เช็คเวลาซ้ำสำหรับ Frontend
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
// [POST] /api/vehicle-bookings - API สร้างรายการจองรถยนต์ (พร้อมระบบ History)
// =========================================================================
exports.createBooking = async (req, res, next) => {
  try {
    const {
      vehicleId,
      startDatetime,
      endDatetime,
      purpose,
      destination,
      passengers = 1,
      driverEmployeeId
    } = req.body;
    
    const rawUserId = req.body?.userId || req.body?.user_id || (req.user ? req.user.id : null);

    if (!vehicleId || !rawUserId || !startDatetime || !endDatetime || !purpose || !destination) {
      return res.status(400).json({ 
        success: false, 
        message: 'กรุณากรอกข้อมูลที่จำเป็นให้ครบถ้วน (vehicleId, userId, startDatetime, endDatetime, purpose, destination)' 
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

    const isOverlap = await checkVehicleOverlapping(vehicleId, start, end);
    if (isOverlap) {
      return res.status(409).json({ 
        success: false, 
        message: 'ไม่สามารถจองได้ เนื่องจากช่วงเวลาดังกล่าวรถยนต์ถูกจองไปแล้วในระบบ' 
      });
    }

    // 💡 ใช้ Transaction เพื่อสร้างการจอง และ สร้างประวัติการจอง พร้อมกัน
    const newBooking = await prisma.$transaction(async (tx) => {
      // 1. สร้างการจองรถยนต์
      const booking = await tx.vehicleBooking.create({
        data: {
          vehicleId: parseInt(vehicleId), 
          userId: userId,
          driverEmployeeId: driverEmployeeId ? parseInt(driverEmployeeId) : null,
          destination: destination,
          passengers: parseInt(passengers),
          startDatetime: start,     
          endDatetime: end,         
          purpose: purpose,           
          status: 'Pending'         
        },
        include: {
          vehicle: true,
          driver: true
        }
      });

      // 2. บันทึกประวัติ
      await tx.vehicleBookingHistory.create({
        data: {
          vehicleBookingId: booking.id,
          changedById: userId,
          action: 'CREATED',
          statusSnapshot: 'Pending',
          remark: 'สร้างการจองรถยนต์ใหม่'
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
    if (error.code === 'P2003') {
      return res.status(400).json({
        success: false,
        message: 'ไม่สามารถจองได้ เนื่องจากไม่พบข้อมูลอ้างอิงในระบบ (อาจจะไม่มีรหัสผู้ใช้นี้ หรือรหัสรถยนต์นี้)'
      });
    }
    next(error);
  }
};

// =========================================================================
// [GET] /api/vehicle-bookings - API แสดงประวัติการจอง (Optimize เพิ่ม Pagination)
// =========================================================================
exports.getBookingHistory = async (req, res, next) => {
  try {
    const userId = req.query?.userId || req.query?.user_id || req.user?.id;
    const whereClause = userId ? { userId: parseInt(userId) } : {};

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
          driver: true,
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
      message: "ดึงข้อมูลรายการจองรถยนต์สำเร็จ",
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
// [PATCH] /api/vehicle-bookings/:id/cancel - API ยกเลิกการจอง (พร้อมระบบ History)
// =========================================================================
exports.cancelBooking = async (req, res, next) => {
  try {
    const bookingId = parseInt(req.params.id);
    const rawUserId = req.body?.userId || req.body?.user_id || (req.user ? req.user.id : null);
    const cancelRemark = req.body?.remark || 'ยกเลิกการจองโดยผู้ใช้งาน';

    if (isNaN(bookingId)) {
      return res.status(400).json({
        success: false,
        message: 'รหัสรายการจองต้องเป็นตัวเลขที่ถูกต้องเท่านั้น'
      });
    }

    if (!rawUserId) {
      return res.status(400).json({
        success: false,
        message: 'กรุณาระบุรหัสผู้ใช้งาน (userId) เพื่อบันทึกประวัติการยกเลิก'
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

    // 💡 ใช้ Transaction เพื่ออัปเดตสถานะ และ สร้างประวัติการยกเลิก พร้อมกัน
    const updatedBooking = await prisma.$transaction(async (tx) => {
      // 1. อัปเดตสถานะรถเป็นการยกเลิก
      const booking = await tx.vehicleBooking.update({
        where: { id: bookingId },
        data: { status: 'Cancelled' }
      });

      // 2. บันทึกประวัติการยกเลิก
      await tx.vehicleBookingHistory.create({
        data: {
          vehicleBookingId: bookingId,
          changedById: parseInt(rawUserId),
          action: 'CANCELLED',
          statusSnapshot: 'Cancelled',
          remark: cancelRemark
        }
      });

      return booking;
    });

    return res.status(200).json({
      success: true,
      message: '✅ ยกเลิกการจองรถยนต์สำเร็จ! บันทึกประวัติเรียบร้อยแล้ว',
      data: updatedBooking
    });

  } catch (error) {
    next(error);
  }
};