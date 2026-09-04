const express = require('express');
const path = require('path');
const router = express.Router();
const securityController = require('../controllers/securityController');
const vehicleBookingController = require('../controllers/vehicleBookingController');

router.use('/uploads', express.static(path.join(__dirname, '../../uploads')));

// โหลดการดึง Middleware ความปลอดภัยชุดเดิมของระบบขึ้นมาใช้งาน
const { authenticateToken, requireRole } = require('../middlewares/auth');

// ตั้งค่าดักสิทธิ์การทำงานสำหรับความปลอดภัยของพนักงานรักษาความปลอดภัย (GUARD, SECURITY และ ADMIN)
router.use(authenticateToken);
router.use(requireRole(['GUARD', 'SECURITY', 'ADMIN'])); // 🟢 เพิ่มสิทธิ์ ADMIN เพื่อให้ผู้ดูแลระบบสามารถเข้าถึงและตรวจสอบข้อมูลได้

router.get('/available', securityController.getAvailableVehicles);
router.get('/in-use', securityController.getInUseVehicles);
router.post('/check-out', securityController.checkOut);
router.post('/check-in', securityController.checkIn);

// เพิ่ม Endpoint สำหรับเรียกดูข้อมูลประวัติ Log รายรายการ (Week 11 Requirement)
router.get('/vehicle-logs/:id', securityController.getVehicleLogById);

router.get('/history', vehicleBookingController.getVehicleHistory);

// 🟢 เพิ่ม Endpoint สำหรับ รปภ. ส่งคำขอปล่อยรถก่อนเวลา และ คำขอคืนรถก่อนเวลา
router.post('/request-early-release/:id', (req, res, next) => require('../controllers/vehicleBookingController').requestEarlyRelease(req, res, next));
router.post('/request-early-return/:id', (req, res, next) => require('../controllers/vehicleBookingController').requestEarlyReturn(req, res, next));

module.exports = router;