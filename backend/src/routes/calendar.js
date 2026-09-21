const express = require('express');
const router = express.Router();
const calendarController = require('../controllers/calendarController');
const authModule = require('../middlewares/auth');
const authenticateToken = (req, res, next) => {
  const fn = authModule?.authenticateToken || authModule?.verifyToken || (typeof authModule === 'function' ? authModule : null);
  return fn ? fn(req, res, next) : next();
};
const optionalAuth = (req, res, next) => {
  const fn = authModule?.optionalAuth || authModule?.verifyOptionalToken;
  return fn ? fn(req, res, next) : next();
}; 

// GET /api/calendar/rooms
router.get('/rooms', optionalAuth, (req, res, next) => {
  if (typeof calendarController?.getRoomCalendar === 'function') {
    return calendarController.getRoomCalendar(req, res, next);
  }
  return res.status(500).json({ success: false, message: 'getRoomCalendar handler not found' });
});

// GET /api/calendar/vehicles
router.get('/vehicles', optionalAuth, (req, res, next) => {
  if (typeof calendarController?.getVehicleCalendar === 'function') {
    return calendarController.getVehicleCalendar(req, res, next);
  }
  return res.status(500).json({ success: false, message: 'getVehicleCalendar handler not found' });
});

// GET /api/calendar/all - สำหรับดึงข้อมูลปฏิทินรวม (Room + Vehicle) รูปแบบ Unified Event
router.get('/all', optionalAuth, (req, res, next) => {
  if (typeof calendarController?.getUnifiedCalendar === 'function') {
    return calendarController.getUnifiedCalendar(req, res, next);
  }
  return res.status(500).json({ success: false, message: 'getUnifiedCalendar handler not found' });
});

// GET /api/calendar/vehicles-grid - สำหรับแสดงปฏิทินรถยนต์รูปแบบตาราง (Matrix)
router.get('/vehicles-grid', optionalAuth, (req, res, next) => {
  if (typeof calendarController?.getVehicleCalendarGrid === 'function') {
    return calendarController.getVehicleCalendarGrid(req, res, next);
  }
  return res.status(500).json({ success: false, message: 'getVehicleCalendarGrid handler not found' });
});

// GET /api/calendar/rooms-grid - สำหรับแสดงปฏิทินห้องประชุมรูปแบบตาราง (Matrix)
router.get('/rooms-grid', optionalAuth, (req, res, next) => {
  if (typeof calendarController?.getRoomCalendarGrid === 'function') {
    return calendarController.getRoomCalendarGrid(req, res, next);
  }
  return res.status(500).json({ success: false, message: 'getRoomCalendarGrid handler not found' });
});

module.exports = router;