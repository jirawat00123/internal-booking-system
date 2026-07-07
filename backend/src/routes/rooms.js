const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs'); // 📌 1. นำเข้าโมดูล fs (File System) เพื่อใช้จัดการไฟล์
const roomController = require('../controllers/roomController'); // อ้างอิงไปยัง Controller จริง
const { authenticateToken } = require('../middlewares/auth');

// 📌 2. เพิ่มโค้ดเช็กและสร้างโฟลเดอร์ uploads อัตโนมัติ ป้องกัน Multer Error
const uploadDir = 'uploads/';
if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
}

// ตั้งค่า multer สำหรับรองรับการอัปโหลดไฟล์รูปภาพห้องประชุมไปยังโฟลเดอร์ uploads
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

// ย้าย Logic ทั้งหมดไปจัดการผ่าน Controller เพื่อให้โค้ดเป็นระเบียบตามสถาปัตยกรรมที่ถูกต้อง
router.get('/', authenticateToken, roomController.getAllRooms);
router.post('/', authenticateToken, roomController.createRoom);
router.put('/:id', authenticateToken, upload.single('image'), roomController.updateRoom);

module.exports = router;