const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { authenticateToken } = require('../middlewares/auth'); // ✅ นำเข้า Middleware ป้องกันสิทธิ์

// ==========================================
// 📂 ตั้งค่าระบบจัดการไฟล์ (Multer Configuration) - คงเดิม 100%
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
  const mimetype = allowedTypes.test(file.mimetype);

  if (extname && mimetype) {
    return cb(null, true);
  } else {
    cb(new Error("รองรับเฉพาะไฟล์ PDF, PNG และ JPG เท่านั้น!"));
  }
};

const upload = multer({
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: fileFilter
});

const deleteGarbageFile = (filePath) => {
  if (filePath && fs.existsSync(filePath)) {
    fs.unlinkSync(filePath);
    console.log(`🗑️ Deleted garbage file: ${filePath}`);
  }
};

// ==========================================
// 🟢 สเตปที่ 1: สร้างการจอง อัปโหลดไฟล์ (แก้ไข IDOR & Schema Mismatch)
// ==========================================
router.post('/', authenticateToken, upload.single('document'), async (req, res) => {
  try {
    // ✅ ตัด driverEmployeeId และ userId ออกจาก body ป้องกันสวมรอย
    const { vehicleId, destination, passengers, startDatetime, endDatetime, purpose } = req.body;
    const tokenUserId = req.user.userId; // ✅ ดึง ID จริงจาก Token

    // 🛑 1. ตรวจสอบข้อมูลเบื้องต้น
    if (!vehicleId || !destination || !startDatetime || !endDatetime) {
      deleteGarbageFile(req.file?.path);
      return res.status(400).json({
        success: false,
        error: "กรุณากรอกข้อมูลให้ครบถ้วน (รหัสรถ, จุดหมายปลายทาง, วันเวลาเริ่มและสิ้นสุด)"
      });
    }

    const parsedVehicleId = parseInt(vehicleId, 10);
    const parsedPassengers = passengers ? parseInt(passengers, 10) : 1;

    if (isNaN(parsedVehicleId)) {
      deleteGarbageFile(req.file?.path);
      return res.status(400).json({ success: false, error: "รหัสรถยนต์ไม่ถูกต้อง" });
    }

    // 🔍 2. ตรวจสอบรถยนต์ว่ามีในระบบ
    const vehicleExists = await prisma.vehicle.findFirst({
      where: { id: parsedVehicleId, isDeleted: false }
    });

    if (!vehicleExists) {
      deleteGarbageFile(req.file?.path);
      return res.status(404).json({ success: false, error: "ไม่พบข้อมูลรถยนต์ในระบบ" });
    }

    // 🧠 3. The Brain: ตรวจสอบคิวรถทับซ้อน (แก้ไข Logic ให้มองข้ามคิวที่ Cancelled/Completed)
    const overlappingVehicle = await prisma.vehicleBooking.findFirst({
      where: {
        vehicleId: parsedVehicleId,
        status: { 
          notIn: ['Cancelled', 'CANCELLED', 'COMPLETED', 'Completed', 'Rejected', 'REJECTED'] 
        },
        startDatetime: { lt: new Date(endDatetime) },
        endDatetime: { gt: new Date(startDatetime) }
      }
    });

    if (overlappingVehicle) {
      deleteGarbageFile(req.file?.path);
      return res.status(409).json({
        success: false,
        error: "รถคันนี้มีการจองในช่วงเวลาดังกล่าวแล้ว กรุณาเลือกช่วงเวลาอื่น"
      });
    }

    // 🟢 4. บันทึกข้อมูลลงฐานข้อมูล (ด้วย Transaction ป้องกันข้อมูลรั่วไหล)
    const newBooking = await prisma.$transaction(async (tx) => {
      // 4.1 สร้างการจอง
      const booking = await tx.vehicleBooking.create({
        data: {
          vehicleId: parsedVehicleId,
          userId: tokenUserId,
          destination,
          passengers: parsedPassengers,
          startDatetime: new Date(startDatetime),
          endDatetime: new Date(endDatetime),
          purpose: purpose || "",
          status: "Pending"
        }
      });

      // 4.2 ล็อคสถานะรถยนต์ป้องกันคนแย่งคิว
      await tx.vehicle.update({
        where: { id: parsedVehicleId },
        data: { status: 'RESERVED' }
      });

      // 4.3 สร้างประวัติ
      await tx.vehicleBookingHistory.create({
        data: {
          vehicleBookingId: booking.id,
          changedById: tokenUserId,
          action: 'CREATED',
          statusSnapshot: 'Pending',
          remark: 'สร้างคำขอจองรถยนต์และอัปโหลดเอกสารแนบ'
        }
      });

      return booking;
    });

    // 📎 5. บันทึกข้อมูลไฟล์แนบ (ถ้ามีการอัปโหลด)
    if (req.file) {
      try {
        await prisma.attachment.create({
          data: {
            entityType: "VEHICLE_BOOKING",
            entityId: newBooking.id,
            fileName: req.file.originalname,
            filePath: req.file.path,
            fileType: req.file.mimetype,
            uploadedBy: { connect: { id: tokenUserId } }
            // ตัด bookingVehicle ทิ้งหากไม่มีใน Schema เพื่อความปลอดภัย
          }
        });
      } catch (attachError) {
        console.error("⚠️ Attachment saving warning:", attachError);
      }
    }

    return res.status(201).json({
      success: true,
      message: "บันทึกคำขอจองรถยนต์เรียบร้อยแล้ว",
      data: newBooking
    });

  } catch (error) {
    deleteGarbageFile(req.file?.path);
    console.error("🔴 Create Vehicle Booking Error:", error);
    return res.status(500).json({
      success: false,
      error: "เกิดข้อผิดพลาดในการประมวลผลการจอง"
    });
  }
});

// ==========================================
// 🕒 ดึงประวัติการจองของตนเอง (GET /history)
// ==========================================
router.get('/history', authenticateToken, async (req, res) => {
  try {
    const tokenUserId = req.user.userId; // ✅ ป้องกัน IDOR โดยใช้ Token แทน Query
    
    const historyBookings = await prisma.vehicleBooking.findMany({
      where: { userId: tokenUserId },
      include: {
        vehicle: true
        // ❌ ตัด driver ออกป้องกัน Crash
      },
      orderBy: { startDatetime: 'desc' }
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
    const tokenUserId = req.user.userId;
    const tokenRole = req.user.role;

    if (isNaN(bookingId)) {
      return res.status(400).json({ success: false, error: "รหัสการจองไม่ถูกต้อง" });
    }

    const booking = await prisma.vehicleBooking.findUnique({
      where: { id: bookingId },
      include: {
        vehicle: true,
        user: { include: { employee: true } }
        // ❌ ตัด driver และ attachments ออกชั่วคราวหากยังจัดการ Relation Schema ไม่สมบูรณ์
      }
    });

    if (!booking) {
      return res.status(404).json({ success: false, error: "ไม่พบข้อมูลการจองนี้" });
    }

    // ✅ ป้องกัน IDOR: ดูได้เฉพาะของตัวเอง (ยกเว้น ADMIN)
    if (tokenRole !== 'ADMIN' && booking.userId !== tokenUserId) {
      return res.status(403).json({ success: false, error: "ปฏิเสธการเข้าถึง: ไม่มีสิทธิ์ดูรายการของผู้อื่น" });
    }

    return res.status(200).json({ success: true, data: booking });
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
    const tokenRole = req.user.role;

    // ✅ บังคับให้เฉพาะ ADMIN หรือผู้ดูแลเท่านั้นที่ดูข้อมูลทั้งหมดได้
    if (tokenRole !== 'ADMIN' && tokenRole !== 'SECURITY' && tokenRole !== 'GUARD') {
       return res.status(403).json({ success: false, error: "ปฏิเสธการเข้าถึง: เฉพาะผู้ดูแลระบบเท่านั้น" });
    }

    const bookings = await prisma.vehicleBooking.findMany({
      include: {
        vehicle: true,
        user: { include: { employee: true } }
      },
      orderBy: { startDatetime: 'desc' },
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
    const tokenUserId = req.user.userId;
    const tokenRole = req.user.role;

    if (isNaN(bookingId)) {
      return res.status(400).json({ success: false, error: "รหัสการจองไม่ถูกต้อง" });
    }

    const bookingExists = await prisma.vehicleBooking.findUnique({
      where: { id: bookingId }
    });

    if (!bookingExists) {
      return res.status(404).json({ success: false, error: `ไม่พบรายการจองรหัส #${bookingId} ในระบบ` });
    }

    // ✅ ป้องกัน IDOR: ยกเลิกได้เฉพาะของตัวเอง (ยกเว้น ADMIN)
    if (tokenRole !== 'ADMIN' && bookingExists.userId !== tokenUserId) {
      return res.status(403).json({ success: false, error: "ปฏิเสธการเข้าถึง: ไม่มีสิทธิ์ยกเลิกรายการของผู้อื่น" });
    }

    if (bookingExists.status === "Cancelled" || bookingExists.status === "CANCELLED") {
      return res.status(400).json({ success: false, error: "รายการนี้ถูกยกเลิกไปแล้ว" });
    }

    // ✅ ทำ Transaction เพื่ออัปเดตสถานะรถ และสร้าง History ไปพร้อมกัน
    const updatedBooking = await prisma.$transaction(async (tx) => {
      const booking = await tx.vehicleBooking.update({
        where: { id: bookingId },
        data: { status: "CANCELLED" }
      });

      // คืนสถานะรถให้ว่าง
      await tx.vehicle.update({
        where: { id: booking.vehicleId },
        data: { status: 'AVAILABLE' }
      });

      // บันทึก Log
      await tx.vehicleBookingHistory.create({
        data: {
          vehicleBookingId: bookingId,
          changedById: tokenUserId,
          action: 'CANCELLED',
          statusSnapshot: 'CANCELLED',
          remark: 'ผู้ใช้งานยกเลิกการจองด้วยตนเอง'
        }
      });

      return booking;
    });

    return res.status(200).json({
      success: true,
      message: "ยกเลิกการจองและคืนสถานะรถเรียบร้อยแล้ว",
      data: updatedBooking
    });

  } catch (error) {
    console.error("🔴 Cancel Vehicle Booking Error:", error);
    return res.status(500).json({ success: false, error: "เกิดข้อผิดพลาดในการยกเลิกรายการจอง" });
  }
});

module.exports = router;