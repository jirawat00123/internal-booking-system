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
router.post('/', upload.single('document'), async (req, res) => {
  try {
    const { vehicleId, userId, driverEmployeeId, destination, passengers, startDatetime, endDatetime, purpose } = req.body;

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
    const parsedDriverId = driverEmployeeId ? parseInt(driverEmployeeId, 10) : null;

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

    // 👤 3. จัดการ User ID (Fallback)
    let finalUserId = userId ? parseInt(userId, 10) : null;
    if (!finalUserId || isNaN(finalUserId)) {
      const activeUser = await prisma.user.findFirst({ where: { active: true } });
      if (!activeUser) {
        deleteGarbageFile(req.file?.path);
        return res.status(400).json({ success: false, error: "ไม่พบผู้ใช้งาน (User) ในระบบ" });
      }
      finalUserId = activeUser.id;
    }

    // 🧠 4. The Brain (ส่วนที่ 1): ตรวจสอบคิวรถทับซ้อน
    const overlappingVehicle = await prisma.vehicleBooking.findFirst({
      where: {
        vehicleId: parsedVehicleId,
        status: { not: "Cancelled" },
        startDatetime: { lt: new Date(endDatetime) },
        endDatetime: { gt: new Date(startDatetime) }
      }
    });

    if (overlappingVehicle) {
      deleteGarbageFile(req.file?.path); // เช็กชนปุ๊บ ลบไฟล์ทิ้งปั๊บ
      return res.status(400).json({
        success: false,
        error: "รถคันนี้มีการจองในช่วงเวลาดังกล่าวแล้ว กรุณาเลือกช่วงเวลาอื่น"
      });
    }

    // 🧠 5. The Brain (ส่วนที่ 2): ตรวจสอบคิวคนขับทับซ้อน (ถ้ามีการเลือกคนขับ)
    // 🧠 5. The Brain (ส่วนที่ 2): ตรวจสอบคิวคนขับทับซ้อน (ถ้ามีการเลือกคนขับ)
    if (parsedDriverId && !isNaN(parsedDriverId)) {
      const overlappingDriver = await prisma.vehicleBooking.findFirst({
        where: {
          driverId: parsedDriverId, // ✅ แก้เป็น driverId ให้ตรงกับ Schema จริง
          status: { not: "Cancelled" },
          startDatetime: { lt: new Date(endDatetime) },
          endDatetime: { gt: new Date(startDatetime) }
        }
      });

      if (overlappingDriver) {
        deleteGarbageFile(req.file?.path);
        return res.status(400).json({
          success: false,
          error: "พนักงานขับรถท่านนี้ติดคิวงานอื่นในช่วงเวลาดังกล่าวแล้ว"
        });
      }
    }

    // 🟢 6. บันทึกข้อมูลลงฐานข้อมูล
    const bookingData = {
      vehicle: { connect: { id: parsedVehicleId } },
      user: { connect: { id: finalUserId } },
      destination,
      passengers: parsedPassengers,
      startDatetime: new Date(startDatetime),
      endDatetime: new Date(endDatetime),
      purpose: purpose || "",
      status: "Pending"
    };

    if (parsedDriverId && !isNaN(parsedDriverId)) {
      bookingData.driver = { connect: { id: parsedDriverId } };
    }

    const newBooking = await prisma.vehicleBooking.create({
      data: bookingData
    });

    // 📎 7. บันทึกข้อมูลไฟล์แนบ (ถ้ามีการอัปโหลด)
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
        // อนุญาตให้การจองสำเร็จแม้บันทึกไฟล์ลงฐานข้อมูลพลาด เพื่อไม่ให้ User เสียเวลาจองใหม่
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
      error: "เกิดข้อผิดพลาดในการประมวลผลการจอง",
      developerMessage: error.message
    });
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
        driver: true,
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
router.get('/:id', async (req, res) => {
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
        driver: true,
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
router.get('/', async (req, res) => {
  try {
    const bookings = await prisma.vehicleBooking.findMany({
      include: {
        vehicle: true,
        user: { include: { employee: true } },
        driver: true
      },
      orderBy: { createdAt: 'desc' },
      take: 100 // ป้องกันปัญหา Out of Memory
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
router.patch('/:id/cancel', async (req, res) => {
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