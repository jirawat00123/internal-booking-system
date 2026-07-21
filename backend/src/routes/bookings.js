const express = require('express');
const bookingController = require('../controllers/bookingController');
const { authenticateToken, requireRole } = require('../middlewares/auth');

const router = express.Router();

// ดึงประวัติ
router.get('/', authenticateToken, bookingController.getBookingHistory);
// เช็คเวลาซ้ำ
router.post('/check-availability', authenticateToken, bookingController.checkAvailability);
// สร้างการจอง
router.post('/', authenticateToken, bookingController.createBooking);

// 🚀 เพิ่ม Route ใหม่สำหรับรับการอัปเดตสถานะทั่วไป (เช่น คืนห้อง) 
router.put('/:id', authenticateToken, bookingController.updateBookingStatus);

// ✅ แก้ไข: อนุญาตเฉพาะ ADMIN และ USER เท่านั้น GUARD จะโดนเด้ง 403 ตั้งแต่ด่านนี้
router.get('/history', authenticateToken, requireRole(['ADMIN', 'USER']), bookingController.getBookingHistory);
router.patch('/:id/cancel', authenticateToken, requireRole(['ADMIN', 'USER']), bookingController.cancelBooking);

module.exports = router;