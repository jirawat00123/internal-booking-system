const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { authenticateToken } = require('../middlewares/auth'); // ✅ นำเข้า Middleware ตรวจสอบสิทธิ์

const router = express.Router();
const prisma = new PrismaClient();

// =========================================================================
// 🏢 กำหนดเส้นทาง (Route) ของระบบห้องประชุม (Rooms)
// =========================================================================

// [GET] / - ดึงรายชื่อห้องประชุมทั้งหมด (ลำดับที่ 3 ในตาราง)
// 🔒 บังคับตรวจสอบ Token (Guest & User: Read Only)
router.get('/', authenticateToken, async (req, res, next) => {
  try {
    const rooms = await prisma.room.findMany({
      where: { isDeleted: false }, // 🟢 เพิ่มเงื่อนไขเพื่อซ่อนห้องที่ถูก Soft Delete
      orderBy: { id: 'asc' }
    });
    
    res.status(200).json({ success: true, data: rooms });
  } catch (error) {
    next(error);
  }
});

// [GET] /:id - ดึงรายละเอียดของห้องประชุมเดี่ยวๆ ตาม ID (ลำดับที่ 4 ในตาราง)
// 🔒 บังคับตรวจสอบ Token (Guest & User: Read Only)
router.get('/:id', authenticateToken, async (req, res, next) => {
  try {
    const roomId = parseInt(req.params.id, 10);
    
    // 💡 ป้องกันบั๊ก: เช็กว่า ID ที่ส่งมาทาง URL เป็นตัวเลขหรือไม่
    if (isNaN(roomId)) {
      return res.status(400).json({ 
        success: false, 
        message: "ID ของห้องประชุมต้องเป็นตัวเลขเท่านั้น" 
      });
    }

// 🟢 เปลี่ยนมาใช้ findFirst แทน เพื่อให้เช็กเงื่อนไข isDeleted ร่วมกับ id ได้
    const room = await prisma.room.findFirst({
      where: { 
        id: roomId,
        isDeleted: false // 🟢 ป้องกันการดึงห้องที่ถูกลบไปแล้วมาแสดงผล
      }
    });

    // 💡 กรณีหาห้องไม่เจอ (เช่น ใส่ ID มั่ว หรือห้องถูกลบไปแล้ว)
    if (!room) {
      return res.status(404).json({ 
        success: false, 
        message: "ไม่พบข้อมูลห้องประชุมนี้ในระบบ" 
      });
    }

    res.status(200).json({ success: true, data: room });
  } catch (error) {
    next(error);
  }
});

module.exports = router;