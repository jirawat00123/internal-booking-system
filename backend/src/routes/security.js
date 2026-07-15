const express = require('express');
const router = express.Router();
const securityController = require('../controllers/securityController');

// โดลดการดึง Middleware ความปลอดภัยชุดเดิมของระบบขึ้นมาใช้งาน
const { authenticateToken, requireRole } = require('../middlewares/auth');

// ตั้งค่าดักสิทธิ์การทำงานสำหรับความปลอดภัยของพนักงานรักษาความปลอดภัย (GUARD)
router.use(authenticateToken);
router.use(requireRole(['GUARD']));

router.get('/available', securityController.getAvailableVehicles);
router.get('/in-use', securityController.getInUseVehicles);
router.post('/check-out', securityController.checkOut);
router.post('/check-in', securityController.checkIn);

module.exports = router;