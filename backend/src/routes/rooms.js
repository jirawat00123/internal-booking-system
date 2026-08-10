const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs'); 
const roomController = require('../controllers/roomController'); 
const {
  authenticateToken,
  isAdmin // ✅ นำเข้า isAdmin สำหรับบังคับสิทธิ์ของ Admin Management Module
} = require('../middlewares/auth');
const { PrismaClient, BookingStatus } = require('@prisma/client');
const prisma = new PrismaClient();

// ตั้งค่า multer สำหรับรองรับการอัปโหลดไฟล์รูปห้องประชุม
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        const dir = path.join(__dirname, '../../uploads/rooms');
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }
        cb(null, dir);
    },
    filename: function (req, file, cb) {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, 'room-' + uniqueSuffix + path.extname(file.originalname).toLowerCase());
    }
});
const upload = multer({ storage: storage });

// ==========================================
// 🚨 จุดสำคัญ: โยง Route ไปหา Controller เท่านั้น ห้ามมี Logic ลบข้อมูลในหน้านี้
// ==========================================
router.get('/monitor/rooms', authenticateToken, roomController.getAllRooms);
router.get('/', authenticateToken, roomController.getAllRooms);
// ดึงข้อมูลห้องตาม ID
router.get('/:id', authenticateToken, roomController.getRoomById);

// 🔒 ADMIN ONLY: จัดการข้อมูลห้องและสถานะ (ใช้ isAdmin)
router.post('/', authenticateToken, isAdmin, upload.single('image'), roomController.createRoom);
router.put('/:id', authenticateToken, isAdmin, upload.single('image'), roomController.updateRoom);

// อัปเดตเฉพาะสถานะของห้อง
router.patch('/:id/status', authenticateToken, isAdmin, roomController.updateRoomStatus);

// ลบข้อมูลห้อง (Soft Delete)
router.delete('/:id', authenticateToken, isAdmin, roomController.deleteRoom);

// 💡 API: ดึงตารางเวลาการจองของห้องประชุมรายห้อง (เพื่อแก้ 404 และกันการจองซ้อน)
router.get('/:id/schedule', authenticateToken, async (req, res, next) => {
  try {
    const roomId = parseInt(req.params.id, 10);
    if (isNaN(roomId)) {
      return res.status(400).json({ success: false, error: "ID ของห้องประชุมไม่ถูกต้อง" });
    }

    const schedules = await prisma.roomBooking.findMany({
      where: { 
        roomId: roomId,
        // ใช้ Prisma BookingStatus Enum เพื่อให้ตรงกับ Type ที่ Prisma คาดหวัง
        // ตัดค่าที่ไม่ใช่ Enum ออก เพื่อไม่ให้เกิด Error และดึงเฉพาะคิวที่ยังแอคทีฟอยู่ (เช่น ยกเว้น CANCELLED หรือ REJECTED)
        status: { 
          notIn: [BookingStatus.CANCELLED, BookingStatus.REJECTED] 
        } 
      },
      select: {
        id: true,
        status: true,
        startDatetime: true,
        endDatetime: true,
      },
      orderBy: {
        startDatetime: 'asc'
      }
    });

    console.log(`\n================================`);
    console.log(`📡 มีคนกำลังเช็กคิวห้อง ID: ${id}`);
    console.log(`📦 คิวที่ระบบมองว่า "ยังถูกจองอยู่" มีทั้งหมด ${schedules.length} คิว ได้แก่:`);
    console.log(schedules);
    console.log(`================================\n`);

    return res.json(schedules);
  } catch (error) {
    console.error('Error fetching room schedule:', error);
    next(error);
  }
});

module.exports = router;