const express = require('express');
const { authenticateToken } = require('../middlewares/auth');
const bookingController = require('../controllers/bookingController');

const router = express.Router();

// 🚗 [GET] /api/bookings - ดึงประวัติรายการจองทั้งหมดจาก Database (รองรับระบบ Booking History)
router.get('/', authenticateToken, bookingController.getBookingHistory);

// 🔍 [POST] /api/bookings/check-availability - เส้นทางสำหรับเช็คเวลาว่าง (ย้ายลอจิกไปรวมศูนย์ที่ Controller เพื่อความปลอดภัย)
router.post('/check-availability', authenticateToken, bookingController.checkAvailability);

// ➕ [POST] /api/bookings - เส้นทางสำหรับสร้างรายการจองใหม่ (ดักจับบั๊ก Foreign Key)
router.post('/', authenticateToken, bookingController.createBooking);

// ❌ [PATCH] /api/bookings/:id/cancel - เส้นทางสำหรับยกเลิกการจอง (Soft Delete)
router.patch('/:id/cancel', authenticateToken, bookingController.cancelBooking);

// 🚨 ส่งออก router นี้ออกไปให้ index.js เรียกใช้งาน
module.exports = router;