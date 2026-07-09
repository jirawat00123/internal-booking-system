const express = require('express');
const { authenticateToken } = require('../middlewares/auth');
const bookingController = require('../controllers/bookingController');

const router = express.Router();

// ดึงประวัติ
router.get('/', authenticateToken, bookingController.getBookingHistory);
// เช็คเวลาซ้ำ
router.post('/check-availability', authenticateToken, bookingController.checkAvailability);
// สร้างการจอง
router.post('/', authenticateToken, bookingController.createBooking);
// ยกเลิกการจอง
router.patch('/:id/cancel', authenticateToken, bookingController.cancelBooking);

// 🚀 เพิ่ม Route ใหม่สำหรับรับการอัปเดตสถานะทั่วไป (เช่น คืนห้อง) 
router.put('/:id', authenticateToken, bookingController.updateBookingStatus);

module.exports = router;