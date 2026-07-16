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
            status: 'Pending'
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
            status: 'In Progress'
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
    // ✅ นำตัวแปร images ออกจากการรับค่า เพราะ frontend จะแยกไปยิงที่ /api/attachments/upload แล้ว
    const { vehicleBookingId, checkoutMileage, checkoutFuelLevel } = req.body;
    const guardId = req.user ? req.user.userId : null;

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

    // ทำงานภายใต้ Prisma Transaction เพื่อความปลอดภัยและป้องกัน Race Condition
    await prisma.$transaction(async (tx) => {
      // 1. ตรวจสอบว่าใบจองรถยนต์นี้มีอยู่ในระบบจริงหรือไม่
      const booking = await tx.vehicleBooking.findUnique({
        where: { id: bookingId }
      });

      if (!booking) {
        throw new Error('BOOKING_NOT_FOUND');
      }

      // 2 & 3. เปลี่ยนสถานะรถยนต์ (RESERVED -> IN_USE) 
      // ป้องกัน Race Condition: เจาะจงเงื่อนไขว่า status ใน db ต้องเป็น RESERVED เท่านั้น ณ วินาทีที่เขียนลงฐานข้อมูล
      try {
        await tx.vehicle.update({
          where: {
            id: booking.vehicleId,
            status: 'RESERVED'
          },
          data: {
            status: 'IN_USE'
          }
        });
      } catch (err) {
        throw new Error('VEHICLE_NOT_READY');
      }

      // อัปเดตสถานะของรายการจองรถยนต์เป็น In Progress
      await tx.vehicleBooking.update({
        where: { id: bookingId },
        data: {
          status: 'In Progress'
        }
      });

      // 4. บันทึกข้อมูลการตรวจสอบออกลงใน VehicleLog
      const log = await tx.vehicleLog.create({
        data: {
          vehicleBookingId: bookingId,
          checkoutById: guardId,
          checkoutTime: new Date(),
          checkoutMileage: mileage,
          checkoutFuelLevel: fuelLevel
        }
      });

      // บันทึก Timeline ประวัติความเคลื่อนไหวลงในตารางหลักตาม Pattern
      await tx.vehicleBookingHistory.create({
        data: {
          vehicleBookingId: bookingId,
          changedById: guardId,
          action: 'CHECK_OUT',
          statusSnapshot: 'In Progress',
          remark: 'เจ้าหน้าที่รักษาความปลอดภัยทำรายการปล่อยรถยนต์ออกจากบริษัทเรียบร้อย'
        }
      });

      // ✅ ลบบล็อก tx.attachment.create(images) ออกเรียบร้อยแล้ว
    });

    return res.status(200).json({
      success: true,
      message: 'ทำรายการ Check-Out รถยนต์สำเร็จเรียบร้อย'
    });

  } catch (error) {
    if (error.message === 'BOOKING_NOT_FOUND') {
      return res.status(404).json({ success: false, message: 'ไม่พบข้อมูลการจองรถยนต์รายการนี้ในระบบ' });
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
    // ✅ 1. นำตัวแปร images ออกจากการรับค่า
    const { vehicleBookingId, returnMileage, returnFuelLevel } = req.body;
    // ✅ 2. เปลี่ยนมาใช้ req.user.userId ให้ตรงกับ JWT Payload
    const guardId = req.user ? req.user.userId : null;

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
      // 1. ตรวจสอบใบจองรถยนต์ในฐานข้อมูล
      const booking = await tx.vehicleBooking.findUnique({
        where: { id: bookingId }
      });

      if (!booking) {
        throw new Error('BOOKING_NOT_FOUND');
      }

      // 2. ดึงข้อมูลบันทึกประวัติ VehicleLog ล่าสุดขานำออกเพื่อทำการอัปเดตข้อมูลรับคืน
      const existingLog = await tx.vehicleLog.findFirst({
        where: { vehicleBookingId: bookingId },
        orderBy: { createdAt: 'desc' }
      });

      if (!existingLog) {
        throw new Error('LOG_NOT_FOUND');
      }

      // 4. เปลี่ยนสถานะรถกลับเป็น AVAILABLE โดยต้องมั่นใจว่าสถานะปัจจุบันเป็น IN_USE
      try {
        await tx.vehicle.update({
          where: {
            id: booking.vehicleId,
            status: 'IN_USE'
          },
          data: {
            status: 'AVAILABLE'
          }
        });
      } catch (err) {
        throw new Error('VEHICLE_NOT_IN_USE');
      }

      // 3. ปรับปรุงข้อมูลบันทึกขากลับเข้าในตารางประวัติ VehicleLog
      await tx.vehicleLog.update({
        where: { id: existingLog.id },
        data: {
          returnById: guardId,
          returnTime: new Date(),
          returnMileage: mileage,
          returnFuelLevel: fuelLevel
        }
      });

      // 5. ปรับเปลี่ยนสถานะเอกสารการจองให้เป็นแบบเสร็จสมบูรณ์เสร็จสิ้นภารกิจ (Completed)
      await tx.vehicleBooking.update({
        where: { id: bookingId },
        data: {
          status: 'Completed'
        }
      });

      // สร้างประวัติ Audit ย้อนหลังในกลุ่ม History
      await tx.vehicleBookingHistory.create({
        data: {
          vehicleBookingId: bookingId,
          changedById: guardId,
          action: 'CHECK_IN',
          statusSnapshot: 'Completed',
          remark: 'เจ้าหน้าที่รักษาความปลอดภัยทำการรับรถคืนเข้าคลังและตรวจสอบความเรียบร้อยแล้ว'
        }
      });

      // ✅ 3. ลบบล็อกที่ทำหน้าที่บันทึก Attachment ซ้ำซ้อนออกเรียบร้อยแล้ว
    });

    return res.status(200).json({
      success: true,
      message: 'ทำรายการ Check-In รับรถยนต์คืนคลังสำเร็จเรียบร้อย'
    });

  } catch (error) {
    if (error.message === 'BOOKING_NOT_FOUND') {
      return res.status(404).json({ success: false, message: 'ไม่พบข้อมูลการจองรถยนต์รายการนี้ในระบบ' });
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