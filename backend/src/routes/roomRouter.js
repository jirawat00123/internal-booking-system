const express = require('express');
const { PrismaClient } = require('@prisma/client');

const router = express.Router();
const prisma = new PrismaClient();

// =========================================================================
// 🏢 กำหนดเส้นทาง (Route) ของระบบห้องประชุม (Rooms)
// =========================================================================

// [GET] / - ดึงรายชื่อห้องประชุมทั้งหมด (ลำดับที่ 3 ในตาราง)
router.get('/', async (req, res, next) => {
  try {
    const rooms = await prisma.room.findMany({
      orderBy: { id: 'asc' }
    });
    
    res.status(200).json(rooms);
  } catch (error) {
    next(error);
  }
});

// [GET] /:id - ดึงรายละเอียดของห้องประชุมเดี่ยวๆ ตาม ID (ลำดับที่ 4 ในตาราง)
router.get('/:id', async (req, res, next) => {
  try {
    const roomId = parseInt(req.params.id);
    
    // 💡 ป้องกันบั๊ก: เช็กว่า ID ที่ส่งมาทาง URL เป็นตัวเลขหรือไม่
    if (isNaN(roomId)) {
      return res.status(400).json({ 
        success: false, 
        message: "ID ของห้องประชุมต้องเป็นตัวเลขเท่านั้น" 
      });
    }

    const room = await prisma.room.findUnique({
      where: { id: roomId }
    });

    // 💡 กรณีหาห้องไม่เจอ (เช่น ใส่ ID มั่ว)
    if (!room) {
      return res.status(404).json({ 
        success: false, 
        message: "ไม่พบข้อมูลห้องประชุมนี้ในระบบ" 
      });
    }

    res.status(200).json(room);
  } catch (error) {
    next(error);
  }
});

module.exports = router;