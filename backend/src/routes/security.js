const express = require('express');
const router = express.Router();
const securityController = require('../controllers/securityController');

// โดลดการดึง Middleware ความปลอดภัยชุดเดิมของระบบขึ้นมาใช้งาน
const { authenticateToken, requireRole } = require('../middlewares/auth');

// ตั้งค่าดักสิทธิ์การทำงานสำหรับความปลอดภัยของพนักงานรักษาความปลอดภัย (GUARD)
// ตั้งค่าดักสิทธิ์การทำงานสำหรับความปลอดภัยของพนักงานรักษาความปลอดภัย (GUARD และ SECURITY)
router.use(authenticateToken);
router.use(requireRole(['GUARD', 'SECURITY']));

router.get('/available', securityController.getAvailableVehicles);
router.get('/in-use', securityController.getInUseVehicles);
router.post('/check-out', securityController.checkOut);
router.post('/check-in', securityController.checkIn);

// เพิ่ม Endpoint สำหรับเรียกดูข้อมูลประวัติ Log รายรายการ (Week 11 Requirement)
router.get('/vehicle-logs/:id', securityController.getVehicleLogById);

module.exports = router;