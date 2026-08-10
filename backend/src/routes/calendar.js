const express = require('express');
const router = express.Router();
const calendarController = require('../controllers/calendarController');
// นำเข้า auth middleware ของคุณ (สมมติว่าชื่อนี้ตามโครงสร้างที่คุณมี)
const { authenticateToken } = require('../middlewares/auth'); 

// บังคับให้ต้อง Login ก่อนดูปฏิทินองค์กร
router.use(authenticateToken);

// GET /api/calendar/rooms
router.get('/rooms', calendarController.getRoomCalendar);

// GET /api/calendar/vehicles
router.get('/vehicles', calendarController.getVehicleCalendar);

module.exports = router;