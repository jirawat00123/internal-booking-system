const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// API: ดึงข้อมูลห้องประชุมทั้งหมด
// Method: GET /api/rooms
exports.getAllRooms = async (req, res) => {
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