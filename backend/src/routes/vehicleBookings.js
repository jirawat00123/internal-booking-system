const { authenticateToken } = require('../middlewares/auth');
const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// ==========================================
// 📂 ตั้งค่าระบบจัดการไฟล์ (Multer Configuration)
// ==========================================
const uploadDir = 'uploads/vehicles/';
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true }); // สร้างโฟลเดอร์อัตโนมัติถ้ายังไม่มี
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
  const mimetype = allowedTypes.test(file.mimetype);

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

// Helper Function: สำหรับลบไฟล์ขยะ (Garbage Collection)
const deleteGarbageFile = (filePath) => {
  if (filePath && fs.existsSync(filePath)) {
    fs.unlinkSync(filePath);
    console.log(`🗑️ Deleted garbage file: ${filePath}`);
  }
};

// ==========================================
// 🟢 สเตปที่ 1: สร้างการจอง อัปโหลดไฟล์ และ The Brain (เช็กรถ + เช็กคนขับ)
// ==========================================
// 💡 เพิ่ม authenticateToken เพื่อยืนยันตัวตนผู้จองเสมอ
router.post('/', authenticateToken, upload.single('document'), async (req, res) => {
  try {
    const { vehicleId, destination, passengerCount, passengers, startDatetime, endDatetime, purpose, driverType } = req.body;

    // 🛑 1. ตรวจสอบข้อมูลเบื้องต้น
    if (!vehicleId || !startDatetime || !endDatetime) {
      deleteGarbageFile(req.file?.path);
      return res.status(400).json({
        success: false,
        error: "กรุณากรอกข้อมูลให้ครบถ้วน (รหัสรถ, วันเวลาเริ่มและสิ้นสุด)"
      });
    }

    const parsedVehicleId = parseInt(vehicleId, 10);
    // 💡 รองรับทั้ง key แบบเก่าและใหม่ที่ Flutter ส่งมา
    const parsedPassengers = parseInt(passengers || passengerCount || 1, 10);
    
    // 👤 2. ดึง User ID จาก Token ที่ผ่านการตรวจสอบแล้ว (มั่นใจได้ว่าถูกคน 100%)
    const finalUserId = parseInt(req.user.userId, 10);

    if (!finalUserId || isNaN(finalUserId)) {
      deleteGarbageFile(req.file?.path);
      return res.status(401).json({ success: false, error: "ไม่พบสิทธิ์ผู้ใช้งาน กรุณาล็อกอินใหม่" });
    }

    // 🧠 3. The Brain & Transaction (รวมการเช็กคิวและล็อกสถานะรถเข้าด้วยกัน)
    const newBooking = await prisma.$transaction(async (tx) => {
      
      // 3.1 ตรวจสอบรถยนต์ว่ามีในระบบ และ "ว่าง (AVAILABLE)" หรือไม่
      const vehicle = await tx.vehicle.findFirst({
        where: { id: parsedVehicleId, isDeleted: false }
      });

      if (!vehicle) throw new Error('NOT_FOUND');
      if (vehicle.status !== 'AVAILABLE') throw new Error('NOT_AVAILABLE');

      // 3.2 ตรวจสอบคิวรถทับซ้อน
      const overlappingVehicle = await tx.vehicleBooking.findFirst({
        where: {
          vehicleId: parsedVehicleId,
          status: { notIn: ["Cancelled", "Completed", "Rejected", "CANCELLED", "REJECTED"] },
          startDatetime: { lt: new Date(endDatetime) },
          endDatetime: { gt: new Date(startDatetime) }
        }
      });

      if (overlappingVehicle) throw new Error('OVERLAP');

      // 🔥 3.3 อัปเดตสถานะรถเป็น RESERVED ทันที
      await tx.vehicle.update({
        where: { id: parsedVehicleId },
        data: { status: 'RESERVED' }
      });

      // 🟢 3.4 บันทึกข้อมูลลงฐานข้อมูล
      return await tx.vehicleBooking.create({
        data: {
          vehicleId: parsedVehicleId,
          userId: finalUserId,
          destination: destination || 'ไม่ระบุเป้าหมาย',
          passengers: parsedPassengers,
          startDatetime: new Date(startDatetime),
          endDatetime: new Date(endDatetime),
          purpose: purpose || 'ใช้งานรถยนต์ของบริษัท',
          driverType: driverType || 'ขับขี่เอง',
          status: 'Pending'
        }
      });
    });

    // 📎 4. บันทึกข้อมูลไฟล์แนบ (ถ้ามีการอัปโหลด)
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

    if (!userId || isNaN(userId)) {
      return res.status(400).json({ success: false, error: "กรุณาระบุ userId ที่ถูกต้อง" });
    }

    const historyBookings = await prisma.vehicleBooking.findMany({
  where: { userId: userId },
  include: {
    vehicle: true,
    attachments: true
  },
  orderBy: { createdAt: 'desc' }
});

    return res.status(200).json({
      success: true,
      count: historyBookings.length,
      data: historyBookings
    });
  } catch (error) {
    console.error("🔴 Get History Error:", error);
    return res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลประวัติการจองได้" });
  }
});

// ==========================================
// 🔍 ดึงรายละเอียดการจองรายตัว (GET /:id)
// ==========================================
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const bookingId = parseInt(req.params.id, 10);
    if (isNaN(bookingId)) {
      return res.status(400).json({ success: false, error: "รหัสการจองไม่ถูกต้อง" });
    }

    const booking = await prisma.vehicleBooking.findUnique({
  where: { id: bookingId },
  include: {
    vehicle: true,
    user: { include: { employee: true } },
    attachments: true
  }
});

    if (!booking) {
      return res.status(404).json({ success: false, error: "ไม่พบข้อมูลการจองนี้" });
    }

    return res.status(200).json({
      success: true,
      data: booking
    });
  } catch (error) {
    console.error("🔴 Get Booking By ID Error:", error);
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

    return res.status(200).json({
      success: true,
      count: bookings.length,
      data: bookings
    });
  } catch (error) {
    console.error("🔴 Get Vehicle Bookings Error:", error);
    return res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลรายการจองรถยนต์ได้" });
  }
});

// ==========================================
// 🟡 ยกเลิกการจองรถยนต์ (PATCH /:id/cancel)
// ==========================================
router.patch('/:id/cancel', authenticateToken, async (req, res) => {
  try {
    const bookingId = parseInt(req.params.id, 10);
    if (isNaN(bookingId)) {
      return res.status(400).json({ success: false, error: "รหัสการจองไม่ถูกต้อง" });
    }

    const bookingExists = await prisma.vehicleBooking.findUnique({
      where: { id: bookingId }
    });

    if (!bookingExists) {
      return res.status(404).json({ success: false, error: `ไม่พบรายการจองรหัส #${bookingId} ในระบบ` });
    }

    // 🛡️ เช็กสิทธิ์ข้อ 1: GUARD และ SECURITY ดูประวัติรถได้อย่างเดียว ไม่มีสิทธิ์ยกเลิก
    if (req.user.role === 'GUARD' || req.user.role === 'SECURITY') {
      return res.status(403).json({ success: false, error: "คุณไม่มีสิทธิ์ยกเลิกการจอง" });
    }

    // 🛡️ เช็กสิทธิ์ข้อ 2: พนักงานทั่วไป (USER) ยกเลิกได้เฉพาะรายการที่ตัวเองเป็นคนจองเท่านั้น
    // (ADMIN จะหลุดรอดเงื่อนไขนี้ไป ทำให้ยกเลิกของใครก็ได้ตาม Requirement)
    if (req.user.role === 'USER' && bookingExists.userId !== req.user.userId) {
      return res.status(403).json({ success: false, error: "คุณไม่มีสิทธิ์ยกเลิกการจองของผู้อื่น" });
    }

    if (bookingExists.status === "Cancelled") {
      return res.status(400).json({ success: false, error: "รายการนี้ถูกยกเลิกไปแล้ว" });
    }

    const updatedBooking = await prisma.vehicleBooking.update({
      where: { id: bookingId },
      data: { status: "Cancelled" }
    });

    return res.status(200).json({
      success: true,
      message: "ยกเลิกการจองเรียบร้อยแล้ว",
      data: updatedBooking
    });

  } catch (error) {
    console.error("🔴 Cancel Vehicle Booking Error:", error);
    return res.status(500).json({ success: false, error: "เกิดข้อผิดพลาดในการยกเลิกรายการจอง" });
  }
});
module.exports = router;