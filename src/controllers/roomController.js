const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// =========================================================================
// [GET] /api/rooms - ดึงข้อมูลห้องประชุมทั้งหมด
// =========================================================================
exports.getAllRooms = async (req, res, next) => {
  try {
    // ใช้ Prisma ดึงข้อมูลจากตาราง rooms ทั้งหมด
    const rooms = await prisma.room.findMany({
      orderBy: {
        id: 'asc', // เรียงตาม ID จากน้อยไปมาก
      },
    });

    // ส่งข้อมูลกลับไปให้ Frontend ในรูปแบบ JSON
    return res.status(200).json({
      success: true,
      count: rooms.length,
      data: rooms,
    });

  } catch (error) {
    console.error('❌ Error fetching rooms:', error);
    return res.status(500).json({
      success: false,
      message: 'เกิดข้อผิดพลาดในการดึงข้อมูลห้องประชุม',
      error: error.message,
    });
  }
};

// =========================================================================
// [POST] /api/rooms - สร้างห้องประชุมใหม่ (เพิ่มฟังก์ชันนี้เพื่อแก้บั๊กข้อมูลหาย)
// =========================================================================
exports.createRoom = async (req, res, next) => {
  try {
    const { name, capacity, location } = req.body;

    // ตรวจสอบว่า Frontend ส่งข้อมูลมาครบหรือไม่
    if (!name || !capacity) {
      return res.status(400).json({
        success: false,
        message: 'กรุณาระบุชื่อห้องประชุมและจำนวนความจุให้ครบถ้วน',
      });
    }

    // 💡 หัวใจสำคัญ: ใช้ await เพื่อบังคับให้ระบบรอจนกว่าจะบันทึกลง PostgreSQL สำเร็จ
    const newRoom = await prisma.room.create({
      data: {
        name: name.toString(),
        capacity: parseInt(capacity),
        location: location ? location.toString() : null,
      },
    });

    return res.status(201).json({
      success: true,
      message: '🎉 สร้างห้องประชุมสำเร็จและบันทึกลงฐานข้อมูลเรียบร้อย',
      data: newRoom,
    });

  } catch (error) {
    console.error('❌ Error creating room:', error);
    return res.status(500).json({
      success: false,
      message: 'เกิดข้อผิดพลาดในการสร้างห้องประชุม',
      error: error.message,
    });
  }
};