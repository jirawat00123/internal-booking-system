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
    limits: { fileSize: 5 * 1024 * 1024 }
});

// ==========================================
// 🚗 แมปปิ้งเส้นทาง API ไปยัง Controller
// ==========================================

router.get('/', verifyToken, vehicleController.getVehicles);
router.post('/', verifyToken, requireRole(['ADMIN']), upload.single('image'), vehicleController.createVehicle);
router.get('/:id', verifyToken, vehicleController.getVehicleById);
router.put('/:id', verifyToken, requireRole(['ADMIN']), upload.single('image'), vehicleController.updateVehicle);
router.delete('/:id', verifyToken, requireRole(['ADMIN']), vehicleController.deleteVehicle);

module.exports = router;