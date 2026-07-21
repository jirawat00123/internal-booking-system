const express = require('express');
const router = express.Router();

// ดึง Middleware ตรวจสอบ Token (แค่มี Token ก็เข้าถึงได้ เพราะเป็น Read-Only)
const { authenticateToken } = require('../middlewares/auth');
const monitorController = require('../controllers/monitorController');

// 🛡️ ต้อง Login ก่อน (เพื่อป้องกันบุคคลภายนอกดึงข้อมูลองค์กรไปใช้)
router.use(authenticateToken);

// ==========================================
// 📺 Phase 5: Guest / Monitor Mode APIs
// ==========================================
router.get('/rooms', monitorController.getRooms);
router.get('/vehicles', monitorController.getVehicles);
router.get('/bookings', monitorController.getActiveBookings);
router.get('/history', monitorController.getHistory);

module.exports = router;