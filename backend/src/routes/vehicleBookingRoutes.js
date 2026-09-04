const express = require('express');
const router = express.Router();
const vehicleBookingController = require('../controllers/vehicleBookingController');

// ✅ นำเข้า Middleware สำหรับตรวจสอบ Token และสิทธิ์
const { authenticateToken } = require('../middlewares/auth');
const upload = require('../middlewares/uploadMiddleware'); // 🟢 เพิ่ม Middleware สำหรับจัดการอัปโหลดรูปภาพ

// =========================================================================
// 🚀 บังคับใช้ authenticateToken ในทุกๆ Route เพื่อความปลอดภัยระดับ Production
// =========================================================================

// API สำหรับตรวจสอบเวลาว่างของรถยนต์
router.post('/check-availability', authenticateToken, vehicleBookingController.checkAvailability);

// API สำหรับสร้างการจองรถยนต์
router.post('/', authenticateToken, upload.any(), vehicleBookingController.createBooking);

// API สำหรับดึงข้อมูลประวัติการจองของตัวเอง (⚠️ ต้องวางก่อน /:id เพื่อไม่ให้ Express สับสน Route)
router.get('/history', authenticateToken, vehicleBookingController.getUserBookings);

// API สำหรับดึงข้อมูลประวัติการจองรถยนต์ทั้งหมด (มีการดักสิทธิ์ ADMIN ไว้ใน Controller แล้ว)
router.get('/', authenticateToken, vehicleBookingController.getBookings);

// API สำหรับดึงรายละเอียดการจองรถยนต์แบบรายตัว
router.get('/:id', authenticateToken, vehicleBookingController.getBookingById);

// API สำหรับยกเลิกการจองรถยนต์
router.patch('/:id/cancel', authenticateToken, vehicleBookingController.cancelBooking);

// API สำหรับบันทึกคืนรถ (ไม่ต้องมี Multer อัปโหลดไฟล์)
router.put('/:id/complete', authenticateToken, vehicleBookingController.completeVehicleBooking);

// 🟢 API สำหรับ รปภ. ปล่อยรถออก (Vehicle Out)
router.put('/:id/release', authenticateToken, upload.fields([
  { name: 'frontImage', maxCount: 1 },
  { name: 'backImage', maxCount: 1 },
  { name: 'plateImage', maxCount: 1 }
]), vehicleBookingController.releaseVehicle);

// 🟢 API สำหรับ รปภ. รับรถเข้า (Vehicle In)
router.put('/:id/return', authenticateToken, upload.fields([
  { name: 'frontImage', maxCount: 1 },
  { name: 'backImage', maxCount: 1 },
  { name: 'plateImage', maxCount: 1 }
]), vehicleBookingController.returnVehicle);

// 🟢 API สำหรับ รปภ. ส่งคำขอรับรถก่อนเวลา
router.post('/:id/early-request', authenticateToken, vehicleBookingController.requestEarlyRelease);

// 🟢 API สำหรับ ผู้จอง ตอบรับหรือปฏิเสธ คำขอรับรถก่อนเวลา
router.post('/:id/early-respond', authenticateToken, vehicleBookingController.respondEarlyRelease);

// 🟢 API สำหรับ รปภ. ส่งคำขอคืนรถก่อนเวลา
router.post('/:id/early-return-request', authenticateToken, vehicleBookingController.requestEarlyReturn);

// 🟢 API สำหรับ ผู้จอง ตอบรับหรือปฏิเสธ คำขอคืนรถก่อนเวลา
router.post('/:id/early-return-respond', authenticateToken, vehicleBookingController.respondEarlyReturn);

module.exports = router;