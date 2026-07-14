const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs'); 
const roomController = require('../controllers/roomController'); 
const { authenticateToken } = require('../middlewares/auth');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// สร้างโฟลเดอร์ uploads อัตโนมัติ ป้องกัน Multer Error
const uploadDir = 'uploads/';
if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
}

// ตั้งค่า multer สำหรับรองรับการอัปโหลดไฟล์
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, uploadDir);
    },
    filename: function (req, file, cb) {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, 'room-' + uniqueSuffix + path.extname(file.originalname));
    }
});
const upload = multer({ storage: storage });

// ==========================================
// 🚨 จุดสำคัญ: โยง Route ไปหา Controller เท่านั้น ห้ามมี Logic ลบข้อมูลในหน้านี้
// ==========================================
router.get('/', authenticateToken, roomController.getAllRooms);
router.post('/', authenticateToken, upload.single('image'), roomController.createRoom);
router.put('/:id', authenticateToken, upload.single('image'), roomController.updateRoom);

// 💡 บรรทัดนี้คือหัวใจ: ชี้ไปที่ฟังก์ชัน deleteRoom เท่านั้น
router.delete('/:id', authenticateToken, roomController.deleteRoom);

// 💡 API: ดึงตารางเวลาการจองของห้องประชุมรายห้อง (เพื่อแก้ 404 และกันการจองซ้อน)
// 💡 API: ดึงตารางเวลาการจองของห้องประชุมรายห้อง
// 💡 API: ดึงตารางเวลาการจองของห้องประชุมรายห้อง
router.get('/:id/schedule', authenticateToken, async (req, res, next) => {
  try {
    const { id } = req.params;

    const schedules = await prisma.roomBooking.findMany({
      where: { 
        roomId: parseInt(id),
        // 🟢 เพิ่ม 'CANCELLED' (ตัวพิมพ์ใหญ่ทั้งหมด) เข้าไปใน List นี้ครับ
        status: { 
          notIn: ['CANCELLED', 'Cancelled', 'Cancel', 'Canceled', 'ยกเลิก', 'เสร็จสิ้น', 'Completed'] 
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