const express = require('express');
const router = express.Router();
const vehicleBookingController = require('../controllers/vehicleBookingController');

// ✅ นำเข้า Middleware สำหรับตรวจสอบ Token และสิทธิ์
const { authenticateToken } = require('../middlewares/auth');

// =========================================================================
// 🚀 บังคับใช้ authenticateToken ในทุกๆ Route เพื่อความปลอดภัยระดับ Production
// =========================================================================

// API สำหรับตรวจสอบเวลาว่างของรถยนต์
router.post('/check-availability', authenticateToken, vehicleBookingController.checkAvailability);

// API สำหรับสร้างการจองรถยนต์
router.post('/', authenticateToken, vehicleBookingController.createBooking);

// API สำหรับดึงข้อมูลประวัติการจองของตัวเอง (⚠️ ต้องวางก่อน /:id เพื่อไม่ให้ Express สับสน Route)
router.get('/history', authenticateToken, vehicleBookingController.getUserBookings);

// API สำหรับดึงข้อมูลประวัติการจองรถยนต์ทั้งหมด (มีการดักสิทธิ์ ADMIN ไว้ใน Controller แล้ว)
router.get('/', authenticateToken, vehicleBookingController.getBookingHistory);

// API สำหรับดึงรายละเอียดการจองรถยนต์แบบรายตัว
router.get('/:id', authenticateToken, vehicleBookingController.getBookingById);

// API สำหรับยกเลิกการจองรถยนต์
router.patch('/:id/cancel', authenticateToken, vehicleBookingController.cancelBooking);

module.exports = router;