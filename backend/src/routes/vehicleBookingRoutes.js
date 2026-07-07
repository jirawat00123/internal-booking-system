const express = require('express');
const router = express.Router();
const vehicleBookingController = require('../controllers/vehicleBookingController');

// API สำหรับตรวจสอบเวลาว่างของรถยนต์
router.post('/check-availability', vehicleBookingController.checkAvailability);

// API สำหรับสร้างการจองรถยนต์
router.post('/', vehicleBookingController.createBooking);

// API สำหรับดึงข้อมูลประวัติการจองรถยนต์
router.get('/', vehicleBookingController.getBookingHistory);

// API สำหรับยกเลิกการจองรถยนต์
router.patch('/:id/cancel', vehicleBookingController.cancelBooking);

module.exports = router;