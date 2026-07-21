const express = require('express');
const bookingController = require('../controllers/bookingController');
const { authenticateToken, requireRole } = require('../middlewares/auth');

const router = express.Router();

// 📺 API Monitor รายการจองสำหรับ Guest/Dashboard Display (Requirement Week 13)
router.get('/monitor/bookings', authenticateToken, bookingController.getBookingHistory);

// 📜 ดึงประวัติการจอง (เปิดให้ทุก Role รวมทั้ง GUARD และ GUEST ดูได้แบบ Read-only)
router.get('/', authenticateToken, bookingController.getBookingHistory);
router.get('/history', authenticateToken, requireRole(['ADMIN', 'USER', 'GUARD', 'GUEST']), bookingController.getBookingHistory);

// 🔍 เช็กเวลาซ้ำก่อนทำการจอง
router.post('/check-availability', authenticateToken, bookingController.checkAvailability);

// 🔒 สร้างการจอง (อนุญาตเฉพาะ ADMIN และ USER - บล็อก GUEST/GUARD)
router.post('/', authenticateToken, requireRole(['ADMIN', 'USER']), bookingController.createBooking);

// 🔒 อัปเดตสถานะการจอง / คืนห้อง (อนุญาต ADMIN, USER, และ GUARD - บล็อก GUEST)
router.put('/:id', authenticateToken, requireRole(['ADMIN', 'USER', 'GUARD']), bookingController.updateBookingStatus);

// 🔒 ยกเลิกการจอง (อนุญาตเฉพาะ ADMIN และ USER)
router.patch('/:id/cancel', authenticateToken, requireRole(['ADMIN', 'USER']), bookingController.cancelBooking);

module.exports = router;