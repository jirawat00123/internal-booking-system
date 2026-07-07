// src/routes/vehicles.js
const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// นำเข้า Middleware
const { verifyToken, requireRole } = require('../middlewares/auth');

// นำเข้า Controller (สมองที่เราแยกไปเมื่อกี้)
const vehicleController = require('../controllers/vehicleController');

// ==========================================
// 🛠️ ตั้งค่า Multer สำหรับอัปโหลดรูปภาพ
// ==========================================
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        const dir = path.join(process.cwd(), 'uploads', 'vehicles');
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }
        cb(null, dir);
    },
    filename: function (req, file, cb) {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, 'vehicle_' + uniqueSuffix + path.extname(file.originalname).toLowerCase());
    }
});

const fileFilter = (req, file, cb) => {
    const allowedTypes = /jpeg|jpg|png/;
    const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = allowedTypes.test(file.mimetype);
    
    if (extname && mimetype) {
        return cb(null, true);
    } else {
        return cb(new Error('รองรับเฉพาะไฟล์รูปภาพ (png, jpg, jpeg) เท่านั้น'));
    }
};

const upload = multer({ 
    storage: storage,
    fileFilter: fileFilter,
    limits: { fileSize: 5 * 1024 * 1024 } // จำกัดขนาดไฟล์สูงสุด 5MB
});

// ==========================================
// 🚗 แมปปิ้งเส้นทาง API ไปยัง Controller
// ==========================================

// 1. ดึงข้อมูลรถยนต์ทั้งหมด (รองรับ Pagination)
router.get('/', verifyToken, vehicleController.getVehicles);

// ==========================================
// ⭐ เพิ่มข้อ 10: เช็กสถานะและกรองรถที่ว่างตามวันเวลา 
// (คำเตือน: ต้องวาง route นี้ก่อน /:id เสมอเพื่อป้องกันบั๊ก)
// ==========================================
router.get('/available', verifyToken, vehicleController.getAvailableVehicles);

// 2. ดึงข้อมูลรถยนต์ 1 คัน ตาม ID
router.get('/:id', verifyToken, vehicleController.getVehicleById);

// 3. เพิ่มข้อมูลรถยนต์ใหม่ (เฉพาะสิทธิ์ ADMIN) พ่วงอัปโหลดรูป
router.post('/', verifyToken, requireRole(['ADMIN']), upload.single('image'), vehicleController.createVehicle);

// 4. แก้ไขข้อมูลรถยนต์ (เฉพาะสิทธิ์ ADMIN) พ่วงอัปโหลดรูป
router.put('/:id', verifyToken, requireRole(['ADMIN']), upload.single('image'), vehicleController.updateVehicle);

// 5. ลบรถแบบ Soft Delete (เฉพาะสิทธิ์ ADMIN)
router.delete('/:id', verifyToken, requireRole(['ADMIN']), vehicleController.deleteVehicle);

module.exports = router;