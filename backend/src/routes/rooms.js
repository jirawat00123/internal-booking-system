const express = require('express');
const router = express.Router();
const roomController = require('../controllers/roomController'); 
const uploadMiddleware = require('../middlewares/uploadMiddleware');
const {
  authenticateToken,
  isAdmin // ✅ นำเข้า isAdmin สำหรับบังคับสิทธิ์ของ Admin Management Module
} = require('../middlewares/auth');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// ==========================================
// 🚨 จุดสำคัญ: โยง Route ไปหา Controller เท่านั้น ห้ามมี Logic ลบข้อมูลในหน้านี้
// ==========================================
router.get('/monitor/rooms', authenticateToken, roomController.getAllRooms);
router.get('/', roomController.getAllRooms);
// ดึงข้อมูลห้องตาม ID
router.get('/:id', authenticateToken, roomController.getRoomById);

// 🔒 ADMIN ONLY: จัดการข้อมูลห้องและสถานะ (ใช้ isAdmin)
router.post('/', authenticateToken, isAdmin, uploadMiddleware.single('image'), roomController.createRoom);
router.put('/:id', authenticateToken, isAdmin, uploadMiddleware.single('image'), roomController.updateRoom);

// อัปเดตเฉพาะสถานะของห้อง
router.patch('/:id/status', authenticateToken, isAdmin, roomController.updateRoomStatus);

// ลบข้อมูลห้อง (Soft Delete)
router.delete('/:id', authenticateToken, isAdmin, roomController.deleteRoom);

// 💡 API: ดึงตารางเวลาการจองของห้องประชุมรายห้อง (เพื่อแก้ 404 และกันการจองซ้อน)
router.get('/:id/schedule', authenticateToken, async (req, res, next) => {
  try {
    const roomId = parseInt(req.params.id, 10);
    if (isNaN(roomId)) {
      return res.status(400).json({ success: false, error: "ID ของห้องประชุมไม่ถูกต้อง" });
    }

    const schedules = await prisma.roomBooking.findMany({
      where: { 
        roomId: roomId,
        // กำหนดเป็น String Array โดยตรง เพื่อป้องกัน Error กรณีชื่อ Enum ใน Prisma Client ไม่ตรงกัน
        status: { 
          notIn: ['CANCELLED', 'REJECTED'] 
        } 
      },
      select: {
        id: true,
        status: true,
        startDatetime: true,
        endDatetime: true,
      },
      orderBy: {
        startDatetime: 'asc'
      }
    });

    console.log(`\n================================`);
    console.log(`📡 มีคนกำลังเช็กคิวห้อง ID: ${roomId}`);
    console.log(`📦 คิวที่ระบบมองว่า "ยังถูกจองอยู่" มีทั้งหมด ${schedules.length} คิว ได้แก่:`);
    console.log(schedules);
    console.log(`================================\n`);

    return res.json(schedules);
  } catch (error) {
    console.error('Error fetching room schedule:', error);
    return res.status(500).json({ success: false, error: error.message || "ระบบขัดข้องในการดึงข้อมูลตารางเวลา" });
  }
});

module.exports = router;