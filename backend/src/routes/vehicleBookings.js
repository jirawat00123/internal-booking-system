const { authenticateToken } = require('../middlewares/auth');
const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
// นำเข้า Controller ที่เราเพิ่งสร้าง
const { releaseVehicle, completeVehicleBooking } = require('../controllers/vehicleBookingController');

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
  
  // ตรวจสอบนามสกุลไฟล์ (สำคัญสุด)
  const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
  
  // 💡 ตรวจสอบ MimeType และอนุโลมให้ 'application/octet-stream' ผ่านได้ 
  // เพราะแอป Flutter หรือ Mobile มักจะส่ง Generic MimeType นี้มาเมื่อไม่ได้ระบุเจาะจง
  const mimetype = allowedTypes.test(file.mimetype) || file.mimetype === 'application/octet-stream';

  if (extname && mimetype) {
    return cb(null, true);
  } else {
    // โยน Error เดิมกลับไป แต่คราวนี้ไฟล์ .jpg จาก Flutter จะไม่หลุดเข้ามาติดบล็อกนี้แล้ว
    cb(new Error("รองรับเฉพาะไฟล์ PDF, PNG และ JPG เท่านั้น! (หรือประเภทไฟล์ที่คุณอัปโหลดไม่รองรับ)"));
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

// ==========================================
// 🚙 บันทึกการปล่อยรถออก (PUT /:id/release) - รปภ. ถ่ายรูปหน้ารถและเลขไมล์
// ==========================================
router.put('/:id/release', 
  authenticateToken, 
  // 📍 1️⃣ ดักก่อนเข้า Multer (ดูว่า Auth ผ่านจริงไหม)
  (req, res, next) => {
    console.log('\n===== [1] RELEASE START: After Auth, Entering Multer =====');
    next();
  },
  upload.fields([
    { name: 'frontImage', maxCount: 1 },
    { name: 'plateImage', maxCount: 1 }
  ]), 
  // 📍 2️⃣ ดักหลังออกจาก Multer (ดูว่าไฟล์ติดปัญหาไหม หรือ Hang อยู่ที่ Busboy)
  (req, res, next) => {
    console.log('===== [2] After Upload: Multer Processed Successfully =====');
    console.log('Files received:', req.files ? Object.keys(req.files) : 'No files');
    console.log('Body received:', req.body);
    next();
  },
  async (req, res) => {
  try {
    console.log("===== [3] Entering Route Logic =====");
    const bookingId = parseInt(req.params.id, 10);
    console.log(`===== [4] After Validation: bookingId = ${bookingId} =====`);

    if (isNaN(bookingId)) {
      return res.status(400).json({ success: false, error: "รหัสการจองไม่ถูกต้อง" });
    }

    const { status, parkingSlot } = req.body;

    console.log("===== [5] Prisma Query: findUnique =====");
    // 1. ตรวจสอบว่ามีรายการจองนี้อยู่จริง
    const bookingExists = await prisma.vehicleBooking.findUnique({
      where: { id: bookingId }
    });

    if (!bookingExists) {
      console.log("===== [STOP] Booking Not Found =====");
      return res.status(404).json({ success: false, error: `ไม่พบรายการจองรหัส #${bookingId} ในระบบ` });
    }

    console.log("===== [6] Booking Found =====");
    console.log("===== [7] Updating Booking =====");
    // 2. อัปเดตสถานะเป็น In_Use (ตามที่ Flutter ส่งมา)
    const updatedBooking = await prisma.vehicleBooking.update({
      where: { id: bookingId },
      data: { status: status || 'In_Use' }
      // หมายเหตุ: หาก schema ในฐานข้อมูลของคุณมีฟิลด์ parkingSlot ให้เพิ่ม `parkingSlot: parkingSlot` เข้าไปใน data ด้วย
    });

    console.log("===== [8] Updating Attachments (if any) =====");
    // 3. บันทึกรูปภาพลงฐานข้อมูล Attachment
    if (req.files) {
      const imagesToSave = [];
      if (req.files['frontImage']) imagesToSave.push(req.files['frontImage'][0]);
      if (req.files['plateImage']) imagesToSave.push(req.files['plateImage'][0]);

      for (const file of imagesToSave) {
        await prisma.attachment.create({
          data: {
            entityType: "VEHICLE_RELEASE_IMAGE", // สร้าง Type เพื่อแยกออกจากไฟล์เอกสารตอนจอง
            entityId: bookingId,
            fileName: file.originalname,
            filePath: file.path,
            fileType: file.mimetype,
            uploadedBy: { connect: { id: req.user.userId } },
            bookingVehicle: { connect: { id: bookingId } }
          }
        });
      }
    }

console.log("===== [9] Commit Success: Sending Response =====");
    return res.status(200).json({
      success: true,
      message: "อัปเดตการปล่อยรถและบันทึกรูปภาพสำเร็จ",
      data: updatedBooking
    });

  } catch (error) {
    console.error("===== [ERROR] Route Logic Crashed =====", error);
    return res.status(500).json({ success: false, error: "เกิดข้อผิดพลาดในการบันทึกข้อมูลปล่อยรถ" });
  }
});

// ==========================================
// 🏁 บันทึกการเสร็จสิ้นการใช้งานรถ (PUT /:id/complete)
// ==========================================
router.put('/:id/complete', authenticateToken, completeVehicleBooking);

module.exports = router;