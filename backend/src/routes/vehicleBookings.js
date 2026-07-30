const { authenticateToken } = require('../middlewares/auth');
const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// นำเข้า Controller ที่เราเพิ่งสร้าง
const { completeVehicleBooking } = require('../controllers/vehicleBookingController');

// ==========================================
// 📂 ตั้งค่าระบบจัดการไฟล์ (Multer Configuration)
// ==========================================
const uploadDir = 'uploads/vehicles/';
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    cb(null, 'booking-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const fileFilter = (req, file, cb) => {
  const allowedTypes = /jpeg|jpg|png|pdf/;
  const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
  const mimetype = allowedTypes.test(file.mimetype) || file.mimetype === 'application/octet-stream';

  if (extname && mimetype) {
    return cb(null, true);
  } else {
    cb(new Error("รองรับเฉพาะไฟล์ PDF, PNG และ JPG เท่านั้น!"));
  }
};

const upload = multer({
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // จำกัดขนาด 5MB
  fileFilter: fileFilter
});

const deleteGarbageFile = (filePath) => {
  if (filePath && fs.existsSync(filePath)) {
    fs.unlinkSync(filePath);
    console.log(`🗑️ Deleted garbage file: ${filePath}`);
  }
};

// ==========================================
// 🟢 สร้างการจอง อัปโหลดไฟล์ และ The Brain (เช็กรถ + เช็กคนขับ)
// ==========================================
router.post('/', authenticateToken, upload.single('document'), async (req, res) => {
  try {
    const { vehicleId, destination, passengerCount, passengers, startDatetime, endDatetime, purpose } = req.body;

    if (!vehicleId || !startDatetime || !endDatetime) {
      deleteGarbageFile(req.file?.path);
      return res.status(400).json({ success: false, error: "กรุณากรอกข้อมูลให้ครบถ้วน" });
    }

    const parsedVehicleId = parseInt(vehicleId, 10);
    const parsedPassengers = parseInt(passengers || passengerCount || 1, 10);
    const finalUserId = parseInt(req.user.userId, 10);

    if (!finalUserId || isNaN(finalUserId)) {
      deleteGarbageFile(req.file?.path);
      return res.status(401).json({ success: false, error: "ไม่พบสิทธิ์ผู้ใช้งาน กรุณาล็อกอินใหม่" });
    }

    const newBooking = await prisma.$transaction(async (tx) => {
      const vehicle = await tx.vehicle.findFirst({
        where: { id: parsedVehicleId, isDeleted: false }
      });

      if (!vehicle) throw new Error('NOT_FOUND');
      if (vehicle.status !== 'AVAILABLE') throw new Error('NOT_AVAILABLE');

      const overlappingVehicle = await tx.vehicleBooking.findFirst({
        where: {
          vehicleId: parsedVehicleId,
          status: { notIn: ["Cancelled", "Completed", "Rejected", "CANCELLED", "REJECTED"] },
          startDatetime: { lt: new Date(endDatetime) },
          endDatetime: { gt: new Date(startDatetime) }
        }
      });

      if (overlappingVehicle) throw new Error('OVERLAP');

      await tx.vehicle.update({
        where: { id: parsedVehicleId },
        data: { status: 'RESERVED' }
      });

      return await tx.vehicleBooking.create({
        data: {
          vehicleId: parsedVehicleId,
          userId: finalUserId,
          destination: destination || 'ไม่ระบุเป้าหมาย',
          passengers: parsedPassengers,
          startDatetime: new Date(startDatetime),
          endDatetime: new Date(endDatetime),
          purpose: purpose || 'ใช้งานรถยนต์ของบริษัท',
          status: 'Pending'
        }
      });
    });

    if (req.file) {
      try {
        await prisma.attachment.create({
          data: {
            entityType: "VEHICLE_BOOKING",
            entityId: newBooking.id,
            fileName: req.file.originalname,
            filePath: req.file.path,
            fileType: req.file.mimetype,
            uploadedBy: { connect: { id: finalUserId } },
            bookingVehicle: { connect: { id: newBooking.id } }
          }
        });
      } catch (attachError) {
        console.error("⚠️ Attachment saving warning:", attachError);
      }
    }

    return res.status(201).json({
      success: true,
      message: "บันทึกคำขอจองรถยนต์และล็อกคิวรถเรียบร้อยแล้ว",
      data: newBooking
    });

  } catch (error) {
    deleteGarbageFile(req.file?.path);
    console.error("🔴 Create Vehicle Booking Error:", error);
    
    if (error.message === 'OVERLAP') return res.status(409).json({ success: false, error: "รถคันนี้มีการจองในช่วงเวลาดังกล่าวแล้ว กรุณาเลือกช่วงเวลาอื่น" });
    if (error.message === 'NOT_FOUND') return res.status(404).json({ success: false, error: "ไม่พบข้อมูลรถยนต์ในระบบ" });
    if (error.message === 'NOT_AVAILABLE') return res.status(400).json({ success: false, error: "รถคันนี้ไม่ว่างพร้อมใช้งาน (อาจถูกล็อกคิวไปแล้ว)" });

    return res.status(500).json({ success: false, error: "เกิดข้อผิดพลาดในการประมวลผล", developerMessage: error.message });
  }
});

// ==========================================
// 🕒 ดึงประวัติการจองของตนเอง (GET /history)
// ==========================================
router.get('/history', async (req, res) => {
  try {
    const userId = parseInt(req.query.userId, 10);
    if (!userId || isNaN(userId)) return res.status(400).json({ success: false, error: "กรุณาระบุ userId ที่ถูกต้อง" });

    const historyBookings = await prisma.vehicleBooking.findMany({
      where: { userId: userId },
      include: { vehicle: true, attachments: true },
      orderBy: { createdAt: 'desc' }
    });

    return res.status(200).json({ success: true, count: historyBookings.length, data: historyBookings });
  } catch (error) {
    return res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลประวัติการจองได้" });
  }
});

// ==========================================
// 🔍 ดึงรายละเอียดการจองรายตัว (GET /:id)
// ==========================================
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const bookingId = parseInt(req.params.id, 10);
    if (isNaN(bookingId)) return res.status(400).json({ success: false, error: "รหัสการจองไม่ถูกต้อง" });

    const booking = await prisma.vehicleBooking.findUnique({
      where: { id: bookingId },
      include: {
        vehicle: true,
        user: { include: { employee: true } },
        attachments: true
      }
    });

    if (!booking) return res.status(404).json({ success: false, error: "ไม่พบข้อมูลการจองนี้" });

    return res.status(200).json({ success: true, data: booking });
  } catch (error) {
    return res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลรายละเอียดการจองได้" });
  }
});

// ==========================================
// 🚗 ดึงรายการประวัติการจองรถยนต์ทั้งหมด (GET /)
// ==========================================
router.get('/', authenticateToken, async (req, res) => {
  try {
    const bookings = await prisma.vehicleBooking.findMany({
      include: {
        vehicle: true,
        user: { include: { employee: true } }
      },
      orderBy: { createdAt: 'desc' },
      take: 100
    });

    return res.status(200).json({ success: true, count: bookings.length, data: bookings });
  } catch (error) {
    return res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลรายการจองรถยนต์ได้" });
  }
});

// ==========================================
// 🟡 ยกเลิกการจองรถยนต์ (PATCH /:id/cancel)
// ==========================================
router.patch('/:id/cancel', authenticateToken, async (req, res) => {
  try {
    const bookingId = parseInt(req.params.id, 10);
    if (isNaN(bookingId)) return res.status(400).json({ success: false, error: "รหัสการจองไม่ถูกต้อง" });

    const bookingExists = await prisma.vehicleBooking.findUnique({
      where: { id: bookingId }
    });

    if (!bookingExists) return res.status(404).json({ success: false, error: `ไม่พบรายการจองรหัส #${bookingId} ในระบบ` });

    if (req.user.role === 'GUARD' || req.user.role === 'SECURITY') {
      return res.status(403).json({ success: false, error: "คุณไม่มีสิทธิ์ยกเลิกการจอง" });
    }

    if (req.user.role === 'USER' && bookingExists.userId !== req.user.userId) {
      return res.status(403).json({ success: false, error: "คุณไม่มีสิทธิ์ยกเลิกการจองของผู้อื่น" });
    }

    if (bookingExists.status === "Cancelled") {
      return res.status(400).json({ success: false, error: "รายการนี้ถูกยกเลิกไปแล้ว" });
    }

    const result = await prisma.$transaction(async (tx) => {
      // คืนสถานะรถเป็น AVAILABLE
      await tx.vehicle.update({
        where: { id: bookingExists.vehicleId },
        data: { status: 'AVAILABLE' }
      });

      return await tx.vehicleBooking.update({
        where: { id: bookingId },
        data: { status: "Cancelled" }
      });
    });

    return res.status(200).json({ success: true, message: "ยกเลิกการจองเรียบร้อยแล้ว", data: result });

  } catch (error) {
    return res.status(500).json({ success: false, error: "เกิดข้อผิดพลาดในการยกเลิกรายการจอง" });
  }
});

// ==========================================
// 🚙 บันทึกการปล่อยรถออก (PUT /:id/release) - รปภ. ปล่อยรถ
// ==========================================
router.put('/:id/release', authenticateToken, upload.fields([
  { name: 'frontImage', maxCount: 1 },
  { name: 'backImage', maxCount: 1 },
  { name: 'plateImage', maxCount: 1 }
]), async (req, res) => {
  try {
    const bookingId = parseInt(req.params.id, 10);
    const finalUserId = parseInt(req.user.userId, 10);

    if (isNaN(bookingId)) return res.status(400).json({ success: false, error: "รหัสการจองไม่ถูกต้อง" });

    const result = await prisma.$transaction(async (tx) => {
      const updatedBooking = await tx.vehicleBooking.update({
        where: { id: bookingId },
        data: { status: 'In_Use' }
      });

      const newLog = await tx.vehicleLog.create({
        data: {
          vehicleBookingId: bookingId,
          checkoutById: finalUserId,
          checkoutTime: new Date(),
          checkoutMileage: 0,
          checkoutFuelLevel: 0,
          remark: 'ปล่อยรถออก' // ❌ เอา parking slot ออกแล้ว
        }
      });

      if (req.files) {
        const imageFields = [
          { key: 'frontImage', type: 'VEHICLE_CHECKOUT_FRONT' },
          { key: 'backImage', type: 'VEHICLE_CHECKOUT_BACK' },
          { key: 'plateImage', type: 'VEHICLE_CHECKOUT_MILEAGE' }
        ];

        for (const field of imageFields) {
          if (req.files[field.key] && req.files[field.key][0]) {
            const file = req.files[field.key][0];
            await tx.attachment.create({
              data: {
                entityType: field.type,
                entityId: newLog.id,
                fileName: file.originalname,
                filePath: file.path,
                fileType: file.mimetype,
                uploadedById: finalUserId,
                vehicleBookingId: bookingId
              }
            });
          }
        }
      }

      return updatedBooking;
    });

    return res.status(200).json({ success: true, message: "อัปเดตการปล่อยรถและบันทึกรูปภาพสำเร็จ", data: result });

  } catch (error) {
    if (req.files) {
      if (req.files.frontImage) deleteGarbageFile(req.files.frontImage[0].path);
      if (req.files.backImage) deleteGarbageFile(req.files.backImage[0].path);
      if (req.files.plateImage) deleteGarbageFile(req.files.plateImage[0].path);
    }
    console.error("🔴 Release Vehicle Error:", error);
    return res.status(500).json({ success: false, error: "เกิดข้อผิดพลาดในการบันทึกข้อมูลปล่อยรถ" });
  }
});

// ==========================================
// 📥 บันทึกการรับรถเข้า (PUT /:id/return) - รปภ. รับรถคืน
// ==========================================
router.put('/:id/return', authenticateToken, upload.fields([
  { name: 'frontImage', maxCount: 1 }, 
  { name: 'backImage', maxCount: 1 }, 
  { name: 'plateImage', maxCount: 1 }
]), async (req, res) => {
  try {
    const bookingId = parseInt(req.params.id, 10);
    const finalUserId = parseInt(req.user.userId, 10);

    if (isNaN(bookingId)) return res.status(400).json({ success: false, error: "รหัสการจองไม่ถูกต้อง" });

    const result = await prisma.$transaction(async (tx) => {
      
      const updatedBooking = await tx.vehicleBooking.update({
        where: { id: bookingId },
        data: { status: 'Completed' } 
      });

      // 🎯 คืนสถานะรถให้กลับมาว่าง (AVAILABLE) เพื่อให้รอบต่อไปจองได้
      await tx.vehicle.update({
        where: { id: updatedBooking.vehicleId },
        data: { status: 'AVAILABLE' }
      });

      const existingLog = await tx.vehicleLog.findFirst({
        where: { vehicleBookingId: bookingId },
        orderBy: { createdAt: 'desc' }
      });

      let targetLogId = bookingId;
      if (existingLog) {
        const updatedLog = await tx.vehicleLog.update({
          where: { id: existingLog.id },
          data: {
            returnById: finalUserId,
            returnTime: new Date(),
            returnMileage: 0,
            returnFuelLevel: 0,
            remark: 'รับรถเข้าเรียบร้อย'
          }
        });
        targetLogId = updatedLog.id;
      }

      if (req.files) {
        const imageFields = [
          { key: 'frontImage', type: 'VEHICLE_RETURN_FRONT' },
          { key: 'backImage', type: 'VEHICLE_RETURN_BACK' },
          { key: 'plateImage', type: 'VEHICLE_RETURN_MILEAGE' }
        ];

        for (const field of imageFields) {
          if (req.files[field.key] && req.files[field.key][0]) {
            const file = req.files[field.key][0];
            await tx.attachment.create({
              data: {
                entityType: field.type,
                entityId: targetLogId,
                fileName: file.originalname,
                filePath: file.path,
                fileType: file.mimetype,
                uploadedById: finalUserId,
                vehicleBookingId: bookingId
              }
            });
          }
        }
      }

      return updatedBooking;
    });

    return res.status(200).json({ success: true, message: "บันทึกการรับรถเข้าและอัปเดตสถานะสำเร็จ", data: result });

  } catch (error) {
    if (req.files) {
        if (req.files.frontImage) deleteGarbageFile(req.files.frontImage[0].path);
        if (req.files.backImage) deleteGarbageFile(req.files.backImage[0].path);
        if (req.files.plateImage) deleteGarbageFile(req.files.plateImage[0].path);
    }
    console.error("🔴 Return Vehicle Error:", error);
    return res.status(500).json({ success: false, error: "ไม่สามารถบันทึกการรับรถเข้าได้" });
  }
});

// ==========================================
// 🏁 บันทึกการเสร็จสิ้นการใช้งานรถเพิ่มเติม (PUT /:id/complete)
// ==========================================
router.put('/:id/complete', authenticateToken, completeVehicleBooking);

module.exports = router;