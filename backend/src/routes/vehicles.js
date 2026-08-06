// src/routes/vehicles.js
const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// นำเข้า Middleware
const authMiddleware = require('../middlewares/auth');
const verifyToken = authMiddleware.verifyToken;
const requireRole = authMiddleware.requireRole;

// นำเข้า Controller
const vehicleController = require('../controllers/vehicleController');
const vehicleBookingController = require('../controllers/vehicleBookingController');

// ==========================================
// 🛡️ [เพิ่มระบบดักจับข้อผิดพลาด] ตรวจสอบ Middleware & Controller
// ==========================================
const checkHandler = (handler, name) => {
    if (typeof handler !== 'function') {
        console.error(`❌ ERROR: ตัวแปรหรือฟังก์ชัน "${name}" มีค่าเป็น undefined หรือไม่ใช่ฟังก์ชัน!`);
        console.error(`👉 กรุณาเช็กในไฟล์ Controller หรือ Middleware ว่าสะกดชื่อถูกต้อง หรือได้ทำการ module.exports ออกมาแล้วหรือยัง`);
        return (req, res) => res.status(500).json({ 
            error: `ฟังก์ชัน ${name} ยังไม่ได้ถูกติดตั้งหรือเขียนไม่ถูกต้องในระบบ Backend` 
        });
    }
    return handler;
};

// ==========================================
// 🛠️ ตั้งค่า Multer สำหรับอัปโหลดรูปภาพและเอกสาร
// ==========================================
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        // ✅ บังคับใช้ __dirname เพื่อให้ถอยกลับไปหา backend/uploads/vehicles อย่างแม่นยำเสมอ
        const dir = path.join(__dirname, '../../uploads/vehicles'); 
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
    console.log('--- Debug Multer fileFilter ---');
    console.log('Fieldname:', file.fieldname);
    console.log('Originalname:', file.originalname);
    console.log('Mimetype:', file.mimetype);
    console.log('-------------------------------');

    // 🎯 แก้ไข: เพิ่ม pdf, doc, docx ให้รองรับเอกสาร พรบ.
    const allowedTypes = /jpeg|jpg|png|pdf|doc|docx/;
    
    // ตรวจสอบนามสกุลไฟล์
    const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
    
    // ตรวจสอบ Mimetype 
    const isImageOrDocMimetype = allowedTypes.test(file.mimetype) || 
                                 file.mimetype === 'application/pdf' || 
                                 file.mimetype === 'application/msword' || 
                                 file.mimetype === 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    
    const isFlutterWebBinary = file.mimetype === 'application/octet-stream' || file.mimetype === 'binary/octet-stream';
    
    // เงื่อนไข: นามสกุลต้องถูกต้องเสมอ และ Mimetype ตรงกับรูปภาพ/เอกสาร หรือเป็น Binary จาก Web
    if (extname && (isImageOrDocMimetype || isFlutterWebBinary)) {
        return cb(null, true);
    } else {
        return cb(new Error('รองรับเฉพาะไฟล์รูปภาพ (png, jpg) และเอกสาร (pdf, docx) เท่านั้น'));
    }
};

const upload = multer({ 
    storage: storage,
    fileFilter: fileFilter,
    limits: { fileSize: 10 * 1024 * 1024 } // 🎯 ขยายขนาดจำกัดเป็น 10MB เผื่อเอกสาร PDF ขนาดใหญ่
});

// ==========================================
// 🚗 แมปปิ้งเส้นทาง API ไปยัง Controller (ผ่านตัวกรองตรวจสอบบั๊ก)
// ==========================================

// 💡 1. ปลดล็อก GET (ดึงข้อมูลรถทั้งหมด) เพื่อให้ User ทั่วไปเข้าดูได้โดยไม่ต้องมี Token
router.get('/', 
    checkHandler(vehicleController.getVehicles, 'vehicleController.getVehicles')
);

// 📺 API Monitor ยานพาหนะสำหรับ Guest/User ดูรายการรถและสถานะ
router.get('/monitor/vehicles',
    checkHandler(verifyToken, 'verifyToken'),
    checkHandler(vehicleController.getVehicles, 'vehicleController.getVehicles')
);

// 📜 ดึงประวัติการใช้งานรถ 
router.get('/history', 
    checkHandler(verifyToken, 'verifyToken'),
    checkHandler(requireRole ? requireRole(['ADMIN', 'USER', 'GUARD', 'GUEST']) : null, 'requireRole'), 
    checkHandler(vehicleBookingController.getHistory, 'vehicleBookingController.getHistory')
);

// 🔒 เพิ่มข้อมูลรถ (ต้องใช้ Token และสิทธิ์ ADMIN)
router.post('/', 
    checkHandler(verifyToken, 'verifyToken'), 
    checkHandler(requireRole ? requireRole(['ADMIN']) : null, 'requireRole'), 
    // 🎯 แก้ไข: ให้รองรับทั้งรูปรถและเอกสาร พรบ. 
    upload.fields([
        { name: 'image', maxCount: 1 }, 
        { name: 'document', maxCount: 1 }
    ]), 
    checkHandler(vehicleController.createVehicle, 'vehicleController.createVehicle')
);

// 💡 2. ปลดล็อก GET by ID (ดึงข้อมูลรถแต่ละคัน) ให้ User เข้าดูได้
router.get('/:id', 
    checkHandler(vehicleController.getVehicleById, 'vehicleController.getVehicleById')
);

// 🔒 แก้ไขข้อมูลรถ (ต้องใช้ Token และสิทธิ์ ADMIN)
router.put('/:id', 
    checkHandler(verifyToken, 'verifyToken'), 
    checkHandler(requireRole ? requireRole(['ADMIN']) : null, 'requireRole'), 
    // 🎯 แก้ไข: เปลี่ยนจาก single('image') เป็น fields(...) รับ 2 ไฟล์พร้อมกัน
    upload.fields([
        { name: 'image', maxCount: 1 }, 
        { name: 'document', maxCount: 1 }
    ]), 
    checkHandler(vehicleController.updateVehicle, 'vehicleController.updateVehicle')
);

// 🔒 ลบข้อมูลรถ (ต้องใช้ Token และสิทธิ์ ADMIN)
router.delete('/:id', 
    checkHandler(verifyToken, 'verifyToken'), 
    checkHandler(requireRole ? requireRole(['ADMIN']) : null, 'requireRole'), 
    checkHandler(vehicleController.deleteVehicle, 'vehicleController.deleteVehicle')
);

module.exports = router;