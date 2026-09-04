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
          orderBy: {
            startDatetime: 'asc'
          },
          include: {
            user: {
              include: {
                employee: true
              }
            },
            attachments: true,
            vehicleLogs: {
              include: {
                checkoutBy: { include: { employee: true } },
                returnBy: { include: { employee: true } }
              }
            } // 🎯 เพิ่มการดึงข้อมูลประวัติการปล่อยรถ
          }
        }
      }
    });

    const formattedVehicles = vehicles.map(vehicle => ({
      ...vehicle,
      bookings: vehicle.bookings.map(booking => {
        const log = booking.vehicleLogs;
        const logReleaseImages = log ? [log.checkoutFrontPhoto, log.checkoutBackPhoto, log.checkoutMileagePhoto].filter(Boolean).map(a => a.replace(/\\/g, '/')) : [];
        const logReturnImages = log ? [log.returnFrontPhoto, log.returnBackPhoto, log.returnMileagePhoto].filter(Boolean).map(a => a.replace(/\\/g, '/')) : [];

        const releaseImages = [
          ...(booking.attachments || [])
            .filter(a => a.entityType === 'VEHICLE_RELEASE_IMAGE' && !a.isDeleted)
            .map(a => a.filePath ? a.filePath.replace(/\\/g, '/') : ''),
          ...logReleaseImages
        ];

        const returnImages = [
          ...(booking.attachments || [])
            .filter(a => a.entityType === 'VEHICLE_RETURN_IMAGE' && !a.isDeleted)
            .map(a => a.filePath ? a.filePath.replace(/\\/g, '/') : ''),
          ...logReturnImages
        ];

        return {
          ...booking,
          checkoutTime: log?.checkoutTime || null,
          returnTime: log?.returnTime || null,
          actualCheckoutTime: log?.checkoutTime || null,
          actualReturnTime: log?.returnTime || null,
          checkoutBy: log?.checkoutBy || null,
          returnBy: log?.returnBy || null,
          checkoutByName: log?.checkoutBy?.employee?.fullName || null,
          returnByName: log?.returnBy?.employee?.fullName || null,
          releaseImages,
          returnImages,
          releasePhotos: releaseImages,
          returnPhotos: returnImages,
          attachments: (booking.attachments || []).map(a => ({
            ...a,
            url: a.filePath ? a.filePath.replace(/\\/g, '/') : '',
            filePath: a.filePath ? a.filePath.replace(/\\/g, '/') : ''
          }))
        };
      })
    }));

    return res.status(200).json({
      success: true,
      data: formattedVehicles
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
            status: 'IN_USE'
          },
          orderBy: {
            startDatetime: 'asc'
          },
          include: {
            user: {
              include: {
                employee: true
              }
            },
            attachments: true,
            vehicleLogs: {
              include: {
                checkoutBy: { include: { employee: true } },
                returnBy: { include: { employee: true } }
              }
            } // 🎯 แก้ไขเป็น true เนื่องจากใน Prisma Schema (VehicleLog?) เป็นแบบ 1-to-1 ไม่สามารถใช้ orderBy/take ได้
          }
        }
      }
    });

    const formattedVehicles = vehicles.map(vehicle => ({
      ...vehicle,
      bookings: vehicle.bookings.map(booking => {
        const log = booking.vehicleLogs;
        const logReleaseImages = log ? [log.checkoutFrontPhoto, log.checkoutBackPhoto, log.checkoutMileagePhoto].filter(Boolean).map(a => a.replace(/\\/g, '/')) : [];
        const logReturnImages = log ? [log.returnFrontPhoto, log.returnBackPhoto, log.returnMileagePhoto].filter(Boolean).map(a => a.replace(/\\/g, '/')) : [];

        const releaseImages = [
          ...(booking.attachments || [])
            .filter(a => a.entityType === 'VEHICLE_RELEASE_IMAGE' && !a.isDeleted)
            .map(a => a.filePath ? a.filePath.replace(/\\/g, '/') : ''),
          ...logReleaseImages
        ];

        const returnImages = [
          ...(booking.attachments || [])
            .filter(a => a.entityType === 'VEHICLE_RETURN_IMAGE' && !a.isDeleted)
            .map(a => a.filePath ? a.filePath.replace(/\\/g, '/') : ''),
          ...logReturnImages
        ];

        return {
          ...booking,
          checkoutTime: log?.checkoutTime || null,
          returnTime: log?.returnTime || null,
          actualCheckoutTime: log?.checkoutTime || null,
          actualReturnTime: log?.returnTime || null,
          checkoutBy: log?.checkoutBy || null,
          returnBy: log?.returnBy || null,
          checkoutByName: log?.checkoutBy?.employee?.fullName || null,
          returnByName: log?.returnBy?.employee?.fullName || null,
          releaseImages,
          returnImages,
          releasePhotos: releaseImages,
          returnPhotos: returnImages,
          attachments: (booking.attachments || []).map(a => ({
            ...a,
            url: a.filePath ? a.filePath.replace(/\\/g, '/') : '',
            filePath: a.filePath ? a.filePath.replace(/\\/g, '/') : ''
          }))
        };
      })
    }));

    return res.status(200).json({
      success: true,
      data: formattedVehicles
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
    const {
      vehicleBookingId,
      checkoutMileage,
      checkoutFuelLevel,
      checkoutFrontPhoto,
      checkoutBackPhoto,
      checkoutMileagePhoto
    } = req.body;
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

      const serverCheckoutTime = new Date(); // 🎯 ดึงเวลาจาก Server ปัจจุบัน

      const getCheckoutFilePath = (field) => {
        if (req.files && req.files[field] && req.files[field][0]) {
          return req.files[field][0].path.replace(/\\/g, '/');
        }
        return req.body[field] || null;
      };

      const log = await tx.vehicleLog.create({
        data: {
          vehicleBookingId: bookingId,
          checkoutById: guardId,
          checkoutTime: serverCheckoutTime,
          checkoutMileage: mileage,
          checkoutFuelLevel: fuelLevel,
          checkoutFrontPhoto: getCheckoutFilePath('checkoutFrontPhoto'),
          checkoutBackPhoto: getCheckoutFilePath('checkoutBackPhoto'),
          checkoutMileagePhoto: getCheckoutFilePath('checkoutMileagePhoto')
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

      // 🟢 บันทึก AuditLog เมื่อทำรายการ Check-Out สำเร็จ (ย้ายเข้ามาใน Transaction)
      if (guardId) {
        await tx.auditLog.create({
          data: {
            action: "CHECK_OUT_VEHICLE",
            module: "VEHICLE_SECURITY",
            entityId: bookingId,
            entityType: "VEHICLE_BOOKING",
            userId: guardId,
            details: `Security Guard ID ${guardId} checked out vehicle for booking ID ${bookingId}`
          }
        });
      }
    });

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
    const {
      vehicleBookingId,
      returnMileage,
      returnFuelLevel,
      returnFrontPhoto,
      returnBackPhoto,
      returnMileagePhoto
    } = req.body;
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

      const serverReturnTime = new Date(); // 🎯 ดึงเวลาจาก Server ปัจจุบัน

      const getReturnFilePath = (field) => {
        if (req.files && req.files[field] && req.files[field][0]) {
          return req.files[field][0].path.replace(/\\/g, '/');
        }
        return req.body[field] || null;
      };

      await tx.vehicleLog.update({
        where: { id: existingLog.id },
        data: {
          returnById: guardId,
          returnTime: serverReturnTime,
          returnMileage: mileage,
          returnFuelLevel: fuelLevel,
          returnFrontPhoto: getReturnFilePath('returnFrontPhoto') || existingLog.returnFrontPhoto,
          returnBackPhoto: getReturnFilePath('returnBackPhoto') || existingLog.returnBackPhoto,
          returnMileagePhoto: getReturnFilePath('returnMileagePhoto') || existingLog.returnMileagePhoto
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

      // 🟢 บันทึก AuditLog เมื่อทำรายการ Check-In สำเร็จ (ย้ายเข้ามาใน Transaction)
      if (guardId) {
        await tx.auditLog.create({
          data: {
            action: "CHECK_IN_VEHICLE",
            module: "VEHICLE_SECURITY",
            entityId: bookingId,
            entityType: "VEHICLE_BOOKING",
            userId: guardId,
            details: `Security Guard ID ${guardId} checked in vehicle for booking ID ${bookingId}`
          }
        });
      }
    });

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

    const booking = log.vehicleBooking;
    let formattedBooking = booking;
    
    if (booking) {
      const logData = log;
      const logReleaseImages = logData ? [logData.checkoutFrontPhoto, logData.checkoutBackPhoto, logData.checkoutMileagePhoto].filter(Boolean).map(a => a.replace(/\\/g, '/')) : [];
      const logReturnImages = logData ? [logData.returnFrontPhoto, logData.returnBackPhoto, logData.returnMileagePhoto].filter(Boolean).map(a => a.replace(/\\/g, '/')) : [];

      const releaseImages = [
        ...(booking.attachments || [])
          .filter(a => a.entityType === 'VEHICLE_RELEASE_IMAGE' && !a.isDeleted)
          .map(a => a.filePath ? a.filePath.replace(/\\/g, '/') : ''),
        ...logReleaseImages
      ];

      const returnImages = [
        ...(booking.attachments || [])
          .filter(a => a.entityType === 'VEHICLE_RETURN_IMAGE' && !a.isDeleted)
          .map(a => a.filePath ? a.filePath.replace(/\\/g, '/') : ''),
        ...logReturnImages
      ];

      formattedBooking = {
        ...booking,
        checkoutTime: logData?.checkoutTime || null,
        returnTime: logData?.returnTime || null,
        actualCheckoutTime: logData?.checkoutTime || null,
        actualReturnTime: logData?.returnTime || null,
        checkoutBy: logData?.checkoutBy || null,
        returnBy: logData?.returnBy || null,
        checkoutByName: logData?.checkoutBy?.employee?.fullName || null,
        returnByName: logData?.returnBy?.employee?.fullName || null,
        releaseImages,
        returnImages,
        releasePhotos: releaseImages,
        returnPhotos: returnImages,
        attachments: (booking.attachments || []).map(a => ({
          ...a,
          url: a.filePath ? a.filePath.replace(/\\/g, '/') : '',
          filePath: a.filePath ? a.filePath.replace(/\\/g, '/') : ''
        }))
      };
    }

    return res.status(200).json({
      success: true,
      data: {
        ...log,
        vehicleBooking: formattedBooking
      }
    });
  } catch (error) {
    next(error);
  }
};

exports.getHistory = async (req, res, next) => {
  try {
    const bookings = await prisma.vehicleBooking.findMany({
      where: {
        status: { in: ['COMPLETED', 'IN_USE', 'CANCELLED', 'EXPIRED'] }
      },
      orderBy: {
        updatedAt: 'desc'
      },
      include: {
        vehicle: true,
        user: {
          include: {
            employee: true
          }
        },
        attachments: {
          where: { isDeleted: false }
        },
        vehicleLogs: {
          include: {
            checkoutBy: { include: { employee: true } },
            returnBy: { include: { employee: true } }
          }
        }
      }
    });

    const formattedBookings = bookings.map(booking => {
      const log = booking.vehicleLogs;
      const logReleaseImages = log ? [log.checkoutFrontPhoto, log.checkoutBackPhoto, log.checkoutMileagePhoto].filter(Boolean).map(a => a.replace(/\\/g, '/')) : [];
      const logReturnImages = log ? [log.returnFrontPhoto, log.returnBackPhoto, log.returnMileagePhoto].filter(Boolean).map(a => a.replace(/\\/g, '/')) : [];

      const releaseImages = [
        ...(booking.attachments || [])
          .filter(a => a.entityType === 'VEHICLE_RELEASE_IMAGE' && !a.isDeleted)
          .map(a => a.filePath ? a.filePath.replace(/\\/g, '/') : ''),
        ...logReleaseImages
      ];

      const returnImages = [
        ...(booking.attachments || [])
          .filter(a => a.entityType === 'VEHICLE_RETURN_IMAGE' && !a.isDeleted)
          .map(a => a.filePath ? a.filePath.replace(/\\/g, '/') : ''),
        ...logReturnImages
      ];

      return {
        ...booking,
        checkoutTime: log?.checkoutTime || null,
        returnTime: log?.returnTime || null,
        actualCheckoutTime: log?.checkoutTime || null,
        actualReturnTime: log?.returnTime || null,
        checkoutBy: log?.checkoutBy || null,
        returnBy: log?.returnBy || null,
        checkoutByName: log?.checkoutBy?.employee?.fullName || null,
        returnByName: log?.returnBy?.employee?.fullName || null,
        releaseImages,
        returnImages,
        releasePhotos: releaseImages,
        returnPhotos: returnImages,
        attachments: (booking.attachments || []).map(a => ({
          ...a,
          url: a.filePath ? a.filePath.replace(/\\/g, '/') : '',
          filePath: a.filePath ? a.filePath.replace(/\\/g, '/') : ''
        }))
      };
    });

    return res.status(200).json({
      success: true,
      data: formattedBookings
    });
  } catch (error) {
    next(error);
  }
};