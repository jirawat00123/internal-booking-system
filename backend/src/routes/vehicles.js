// src/routes/vehicles.js
const express = require('express');
const router = express.Router();
const uploadMiddleware = require('../middlewares/uploadMiddleware');

// นำเข้า Middleware
const authMiddleware = require('../middlewares/auth');
const verifyToken = authMiddleware.authenticateToken || authMiddleware.verifyToken;
const requireRole = authMiddleware.requireRole;
const isAdmin = authMiddleware.isAdmin; // ✅ นำเข้า isAdmin สำหรับสิทธิ์ Admin Management Module (Week 14)

// นำเข้า Controller
const vehicleController = require('../controllers/vehicleController');
const vehicleBookingController = require('../controllers/vehicleBookingController'); // ✅ เพิ่ม Import เพื่อแก้ Error ลืมประกาศตัวแปร

// ==========================================
// 🛡️ [เพิ่มระบบดักจับข้อผิดพลาด] ตรวจสอบ Middleware & Controller
// ==========================================
const checkHandler = (handler, name) => {
    if (typeof handler !== 'function') {
        console.error(`❌ ERROR: ตัวแปรหรือฟังก์ชัน "${name}" มีค่าเป็น undefined หรือไม่ใช่ฟังก์ชัน!`);
        console.error(`👉 กรุณาเช็กในไฟล์ Controller หรือ Middleware ว่าสะกดชื่อถูกต้อง หรือได้ทำการ module.exports ออกมาแล้วหรือยัง`);
        return (req, res) => {
            console.error(`❌ [checkHandler Execution Error] Function "${name}" is undefined or not a function.`);
            return res.status(500).json({ 
                error: `ฟังก์ชัน ${name} ยังไม่ได้ถูกติดตั้งหรือเขียนไม่ถูกต้องในระบบ Backend` 
            });
        };
    }
    return handler;
};

// ==========================================
// 🚗 แมปปิ้งเส้นทาง API ไปยัง Controller (ผ่านตัวกรองตรวจสอบบั๊ก)
// ==========================================

// 🔒 บังคับตรวจสอบ Token (Guest & User: Read Only)
router.get('/', 
    (req, res, next) => {
        console.log('[TRACE] GET /api/vehicles ROUTE HIT');
        next();
    },
    checkHandler(verifyToken, 'verifyToken'),
    (req, res, next) => {
        console.log('[TRACE] Calling vehicleController.getVehicles');
        next();
    },
    checkHandler(vehicleController.getVehicles, 'vehicleController.getVehicles')
);

// 📺 API Monitor ยานพาหนะสำหรับ Guest/User ดูรายการรถและสถานะ (Requirement Week 13)
router.get('/monitor/vehicles',
    checkHandler(verifyToken, 'verifyToken'),
    checkHandler(vehicleController.getVehicles, 'vehicleController.getVehicles')
);

// 📜 ดึงประวัติการใช้งานรถ (ย้ายขึ้นมาก่อน /:id เพื่อป้องกัน Express สับสนคำว่า 'history' เป็น parameter id)
// ✅ เพิ่ม 'GUEST' ใน requireRole เพื่อเปิดให้ Guest เข้าดูประวัติได้ตาม Requirement Week 13
router.get('/history', 
    checkHandler(verifyToken, 'verifyToken'),
    checkHandler(requireRole(['ADMIN', 'USER', 'GUARD', 'GUEST']), 'requireRole'), 
    checkHandler(vehicleBookingController.getHistory, 'vehicleBookingController.getHistory')
);

// 🔒 เพิ่มข้อมูลรถ (ต้องใช้ Token และสิทธิ์ ADMIN)
router.post('/', 
    checkHandler(verifyToken, 'verifyToken'), 
    checkHandler(isAdmin, 'isAdmin'), 
    uploadMiddleware.single('image'), 
    checkHandler(vehicleController.createVehicle, 'vehicleController.createVehicle')
);

// 🔒 บังคับตรวจสอบ Token (Guest & User: Read Only)
router.get('/:id', 
    checkHandler(verifyToken, 'verifyToken'),
    checkHandler(vehicleController.getVehicleById, 'vehicleController.getVehicleById')
);

// 🔒 แก้ไขข้อมูลรถ (ต้องใช้ Token และสิทธิ์ ADMIN)
router.put('/:id', 
    checkHandler(verifyToken, 'verifyToken'), 
    checkHandler(isAdmin, 'isAdmin'), 
    uploadMiddleware.single('image'), 
    checkHandler(vehicleController.updateVehicle, 'vehicleController.updateVehicle')
);

// 🔒 เปลี่ยนสถานะรถ (ตาม Checklist Week 14: PATCH /vehicles/:id/status)
router.patch('/:id/status', 
    checkHandler(verifyToken, 'verifyToken'), 
    checkHandler(isAdmin, 'isAdmin'), 
    checkHandler(vehicleController.updateVehicleStatus, 'vehicleController.updateVehicleStatus')
);

// 🔒 ลบข้อมูลรถ (ต้องใช้ Token และสิทธิ์ ADMIN)
router.delete('/:id', 
    checkHandler(verifyToken, 'verifyToken'), 
    checkHandler(isAdmin, 'isAdmin'), 
    checkHandler(vehicleController.deleteVehicle, 'vehicleController.deleteVehicle')
);
module.exports = router;