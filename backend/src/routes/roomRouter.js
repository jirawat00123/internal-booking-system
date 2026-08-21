const express = require('express');
const { authenticateToken } = require('../middlewares/auth'); // ✅ นำเข้า Middleware ตรวจสอบสิทธิ์
const roomController = require('../controllers/roomController'); // 🟢 นำเข้า Controller เพื่อดึง Logic มาใช้

const router = express.Router();

// =========================================================================
// 🏢 กำหนดเส้นทาง (Route) ของระบบห้องประชุม (Rooms)
// =========================================================================

// [GET] / - ดึงรายชื่อห้องประชุมทั้งหมด (ลำดับที่ 3 ในตาราง)
// 🔒 บังคับตรวจสอบ Token (Guest & User: Read Only)
router.get('/', authenticateToken, roomController.getAllRooms);

// [GET] /:id - ดึงรายละเอียดของห้องประชุมเดี่ยวๆ ตาม ID (ลำดับที่ 4 ในตาราง)
// 🔒 บังคับตรวจสอบ Token (Guest & User: Read Only)
router.get('/:id', authenticateToken, roomController.getRoomById);

module.exports = router;