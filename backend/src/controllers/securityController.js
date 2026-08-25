const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// =========================================================================
// [GET] /api/security/available - แสดงรายการรถยนต์ที่ถูกจองแล้วและรอการปล่อยตัว
// =========================================================================
exports.getAvailableVehicles = async (req, res, next) => {
  try {
    const vehicles = await prisma.vehicle.findMany({
      where: {
        status: 'RESERVED',
        isDeleted: false
      },
      include: {
        bookings: {
          where: {
            status: { in: ['Approved', 'APPROVED', 'RESERVED'] }
          },
          include: {
            user: {
              include: {
                employee: true
              }
            }
          }
        }
      }
    });

    return res.status(200).json({
      success: true,
      data: vehicles
    });
  } catch (error) {
    next(error);
  }
};

// =========================================================================
// [GET] /api/security/in-use - แสดงรายการรถยนต์ที่กำลังนำออกไปใช้งานในขณะนี้
// =========================================================================
exports.getInUseVehicles = async (req, res, next) => {
  try {
    const vehicles = await prisma.vehicle.findMany({
      where: {
        status: 'IN_USE',
        isDeleted: false
      },
      include: {
        bookings: {
          where: {
            status: 'IN_USE' // 💡 เปลี่ยนจาก 'In Progress' เป็น 'IN_USE'
          },
          include: {
            user: {
              include: {
                employee: true
              }
            },
            vehicleLogs: {
              orderBy: { createdAt: 'desc' },
              take: 1
            }
          }
        }
      }
    });

    return res.status(200).json({
      success: true,
      data: vehicles
    });
  } catch (error) {
    next(error);
  }
};

// =========================================================================
// [POST] /api/security/check-out - ยืนยันปล่อยรถออกจากระบบ (Security Guard)
// =========================================================================
exports.checkOut = async (req, res, next) => {
  try {
    const { vehicleBookingId, checkoutMileage, checkoutFuelLevel } = req.body;
    const guardId = (req.user?.userId || req.user?.id) ? parseInt(req.user.userId || req.user.id, 10) : null;

    if (!vehicleBookingId || checkoutMileage === undefined || checkoutFuelLevel === undefined) {
      return res.status(400).json({
        success: false,
        message: 'กรุณาระบุข้อมูลให้ครบถ้วน (vehicleBookingId, checkoutMileage, checkoutFuelLevel)'
      });
    }

    const bookingId = parseInt(vehicleBookingId);
    const mileage = parseInt(checkoutMileage);
    const fuelLevel = parseInt(checkoutFuelLevel);

    if (isNaN(bookingId) || isNaN(mileage) || isNaN(fuelLevel)) {
      return res.status(400).json({
        success: false,
        message: 'ข้อมูลในส่วนของ ID, เลขไมล์ และระดับน้ำมัน ต้องระบุเป็นตัวเลขที่ถูกต้องเท่านั้น'
      });
    }

    await prisma.$transaction(async (tx) => {
      const booking = await tx.vehicleBooking.findUnique({
        where: { id: bookingId }
      });

      if (!booking) {
        throw new Error('BOOKING_NOT_FOUND');
      }

      const now = new Date();
      if (now < booking.startDatetime) {
        const consentLog = await tx.auditLog.findFirst({
          where: {
            module: 'VEHICLE_BOOKING',
            entityId: bookingId,
            action: 'EARLY_RELEASE_CONSENT_GRANTED'
          }
        });

        if (!consentLog) {
          throw new Error('EARLY_RELEASE_REQUIRES_APPROVAL');
        }
      }

      const vehicle = await tx.vehicle.findUnique({ where: { id: booking.vehicleId } });
      if (!vehicle || vehicle.status !== 'RESERVED') {
        throw new Error('VEHICLE_NOT_READY');
      }

      await tx.vehicle.update({
        where: { id: booking.vehicleId },
        data: { status: 'IN_USE' }
      });

      await tx.vehicleBooking.update({
        where: { id: bookingId },
        data: {
          status: 'IN_USE' // 💡 เปลี่ยนสถานะการจองเป็น 'IN_USE' เพื่อให้ตรงกับแอป
        }
      });

      const log = await tx.vehicleLog.create({
        data: {
          vehicleBookingId: bookingId,
          checkoutById: guardId,
          checkoutTime: new Date(),
          checkoutMileage: mileage,
          checkoutFuelLevel: fuelLevel
        }
      });

      await tx.vehicleBookingHistory.create({
        data: {
          vehicleBookingId: bookingId,
          changedById: guardId,
          action: 'CHECK_OUT',
          statusSnapshot: 'IN_USE', // 💡 เปลี่ยน Snapshot ให้เป็น 'IN_USE' ตามกัน
          remark: 'เจ้าหน้าที่รักษาความปลอดภัยทำรายการปล่อยรถยนต์ออกจากบริษัทเรียบร้อย'
        }
      });
    });

// 🟢 บันทึก AuditLog เมื่อทำรายการ Check-Out สำเร็จ
    if (guardId) {
      await prisma.auditLog.create({
        data: {
          action: "CHECK_OUT_VEHICLE",
          module: "VEHICLE_SECURITY",
          entityId: bookingId,
          entityType: "VEHICLE_BOOKING",
          userId: guardId,
          details: `Security Guard ID ${guardId} checked out vehicle for booking ID ${bookingId}`
        }
      }).catch(err => console.error("AuditLog Error [CHECK_OUT_VEHICLE]:", err.message));
    }

    return res.status(200).json({
      success: true,
      message: 'ทำรายการ Check-Out รถยนต์สำเร็จเรียบร้อย'
    });

  } catch (error) {
    if (error.message === 'BOOKING_NOT_FOUND') {
      return res.status(404).json({ success: false, message: 'ไม่พบข้อมูลการจองรถยนต์รายการนี้ในระบบ' });
    }
    if (error.message === 'EARLY_RELEASE_REQUIRES_APPROVAL') {
      return res.status(409).json({
        success: false,
        code: 'EARLY_RELEASE_REQUIRES_APPROVAL',
        message: 'ยังไม่ถึงเวลาปล่อยรถ และยังไม่มีการยินยอมรับรถก่อนเวลาจากผู้จอง'
      });
    }
    if (error.message === 'VEHICLE_NOT_READY') {
      return res.status(400).json({ success: false, message: 'รถคันนี้ไม่ได้อยู่ในสถานะจองพร้อมปล่อยใช้งาน หรืออาจมีผู้ทำรายการไปก่อนหน้านี้แล้ว' });
    }
    next(error);
  }
};

// =========================================================================
// [POST] /api/security/check-in - ตรวจสอบและบันทึกรับคืนรถยนต์เข้าสู่บริษัท
// =========================================================================
exports.checkIn = async (req, res, next) => {
  try {
    const { vehicleBookingId, returnMileage, returnFuelLevel } = req.body;
    const guardId = (req.user?.userId || req.user?.id) ? parseInt(req.user.userId || req.user.id, 10) : null;

    if (!vehicleBookingId || returnMileage === undefined || returnFuelLevel === undefined) {
      return res.status(400).json({
        success: false,
        message: 'กรุณาระบุข้อมูลให้ครบถ้วน (vehicleBookingId, returnMileage, returnFuelLevel)'
      });
    }

    const bookingId = parseInt(vehicleBookingId);
    const mileage = parseInt(returnMileage);
    const fuelLevel = parseInt(returnFuelLevel);

    if (isNaN(bookingId) || isNaN(mileage) || isNaN(fuelLevel)) {
      return res.status(400).json({
        success: false,
        message: 'ข้อมูลในส่วนของ ID, เลขไมล์รับคืน และระดับน้ำมันรับคืน ต้องระบุเป็นตัวเลขที่ถูกต้องเท่านั้น'
      });
    }

    await prisma.$transaction(async (tx) => {
      const booking = await tx.vehicleBooking.findUnique({
        where: { id: bookingId }
      });

      if (!booking) {
        throw new Error('BOOKING_NOT_FOUND');
      }

      const now = new Date();
      if (now < booking.endDatetime) {
        const consentLog = await tx.auditLog.findFirst({
          where: {
            module: 'VEHICLE_BOOKING',
            entityId: bookingId,
            action: 'EARLY_RETURN_CONSENT_GRANTED'
          }
        });

        if (!consentLog) {
          throw new Error('EARLY_RETURN_REQUIRES_APPROVAL');
        }
      }

      const existingLog = await tx.vehicleLog.findFirst({
        where: { vehicleBookingId: bookingId },
        orderBy: { createdAt: 'desc' }
      });

      if (!existingLog) {
        throw new Error('LOG_NOT_FOUND');
      }

      const vehicle = await tx.vehicle.findUnique({ where: { id: booking.vehicleId } });
      if (!vehicle || vehicle.status !== 'IN_USE') {
        throw new Error('VEHICLE_NOT_IN_USE');
      }

      await tx.vehicle.update({
        where: { id: booking.vehicleId },
        data: { status: 'AVAILABLE' }
      });

      await tx.vehicleLog.update({
        where: { id: existingLog.id },
        data: {
          returnById: guardId,
          returnTime: new Date(),
          returnMileage: mileage,
          returnFuelLevel: fuelLevel
        }
      });

      await tx.vehicleBooking.update({
        where: { id: bookingId },
        data: {
          status: 'COMPLETED'
        }
      });

      await tx.vehicleBookingHistory.create({
        data: {
          vehicleBookingId: bookingId,
          changedById: guardId,
          action: 'CHECK_IN',
          statusSnapshot: 'COMPLETED',
          remark: 'เจ้าหน้าที่รักษาความปลอดภัยทำการรับรถคืนเข้าคลังและตรวจสอบความเรียบร้อยแล้ว'
        }
      });
    });

// 🟢 บันทึก AuditLog เมื่อทำรายการ Check-In สำเร็จ
    if (guardId) {
      await prisma.auditLog.create({
        data: {
          action: "CHECK_IN_VEHICLE",
          module: "VEHICLE_SECURITY",
          entityId: bookingId,
          entityType: "VEHICLE_BOOKING",
          userId: guardId,
          details: `Security Guard ID ${guardId} checked in vehicle for booking ID ${bookingId}`
        }
      }).catch(err => console.error("AuditLog Error [CHECK_IN_VEHICLE]:", err.message));
    }

    return res.status(200).json({
      success: true,
      message: 'ทำรายการ Check-In รับรถยนต์คืนคลังสำเร็จเรียบร้อย'
    });

  } catch (error) {
    if (error.message === 'BOOKING_NOT_FOUND') {
      return res.status(404).json({ success: false, message: 'ไม่พบข้อมูลการจองรถยนต์รายการนี้ในระบบ' });
    }
    if (error.message === 'EARLY_RETURN_REQUIRES_APPROVAL') {
      return res.status(409).json({
        success: false,
        code: 'EARLY_RETURN_REQUIRES_APPROVAL',
        message: 'ยังไม่ถึงเวลาคืนรถตามกำหนด และยังไม่มีการยินยอมคืนรถก่อนเวลาจากผู้จอง'
      });
    }
    if (error.message === 'LOG_NOT_FOUND') {
      return res.status(404).json({ success: false, message: 'ไม่พบประวัติการปล่อยบันทึกเบื้องต้นของรถยนต์คันนี้' });
    }
    if (error.message === 'VEHICLE_NOT_IN_USE') {
      return res.status(400).json({ success: false, message: 'รถคันนี้ไม่ได้อยู่ในสถานะนำออกใช้งาน (IN USE) ไม่สามารถรับคืนได้' });
    }
    next(error);
  }
};

// =========================================================================
// [GET] /api/vehicle-logs/:id - ดึงข้อมูลประวัติการบันทึก Check-Out / Check-In รายรายการ
// =========================================================================
exports.getVehicleLogById = async (req, res, next) => {
  try {
    const { id } = req.params;
    const logId = parseInt(id);

    if (isNaN(logId)) {
      return res.status(400).json({
        success: false,
        message: 'รูปแบบ ID ของ Log ไม่ถูกต้อง'
      });
    }

    const log = await prisma.vehicleLog.findUnique({
      where: { id: logId },
      include: {
        checkoutBy: {
          include: { employee: true }
        },
        returnBy: {
          include: { employee: true }
        },
        vehicleBooking: {
          include: {
            user: {
              include: { employee: true }
            },
            vehicle: true,
            attachments: {
              where: { isDeleted: false }
            }
          }
        }
      }
    });

    if (!log) {
      return res.status(404).json({
        success: false,
        message: 'ไม่พบข้อมูลบันทึกประวัติ (Vehicle Log) ที่ระบุในระบบ'
      });
    }

    return res.status(200).json({
      success: true,
      data: log
    });
  } catch (error) {
    next(error);
  }
};