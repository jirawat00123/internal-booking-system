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
    const { roomName, capacity, location, status } = req.body;
    let uploadUrl = null; // 💡 1. เพิ่มตัวแปรสำหรับเก็บ path รูปภาพ

    // 💡 2. ตรวจสอบว่ามีการแนบไฟล์มาด้วยหรือไม่
    if (req.file) {
      uploadUrl = `/uploads/${req.file.filename}`;
    }

    if (!roomName || !capacity) {
      return res.status(400).json({
        success: false,
        message: 'กรุณาระบุชื่อห้องประชุม (roomName) และจำนวนความจุให้ครบถ้วน',
      });
    }

    const newRoom = await prisma.room.create({
      data: {
        roomName: roomName.toString(),
        capacity: parseInt(capacity),
        location: location ? location.toString() : null,
        status: status || 'AVAILABLE',
        uploadUrl: uploadUrl, // 💡 3. บันทึก path รูปภาพลงฐานข้อมูล
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

// =========================================================================
// [PUT] /api/rooms/:id - อัปเดตข้อมูลห้องประชุมพร้อมรองรับการอัปโหลดไฟล์รูปภาพใหม่
// =========================================================================
exports.updateRoom = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { roomName, location, capacity, status } = req.body;
    let uploadUrl;

    // หากมีการส่งไฟล์ภาพใหม่ผ่าน MultipartRequest มาให้ทำการบันทึกพาธลงตัวแปร
    if (req.file) {
      uploadUrl = `/uploads/${req.file.filename}`;
    }

    // ตรวจสอบฟิลด์และเตรียมข้อมูลสำหรับทำการอัปเดตแบบ Dynamic
    const updateData = {};
    if (roomName) updateData.roomName = roomName.toString();
    if (location) updateData.location = location.toString();
    if (capacity) updateData.capacity = parseInt(capacity);
    if (status) updateData.status = status;
    if (uploadUrl) updateData.uploadUrl = uploadUrl;

    const updatedRoom = await prisma.room.update({
      where: { id: parseInt(id) },
      data: updateData,
    });

    return res.status(200).json({
      success: true,
      message: 'อัปเดตข้อมูลห้องประชุมสำเร็จ',
      data: updatedRoom,
    });

  } catch (error) {
    console.error('❌ Error updating room:', error);
    return res.status(500).json({
      success: false,
      message: 'เกิดข้อผิดพลาดในการอัปเดตข้อมูลห้องประชุม',
      error: error.message,
    });
  }
};
// =========================================================================
// [DELETE] /api/rooms/:id - ลบห้องประชุมออกจากฐานข้อมูลถาวร (เพิ่มใหม่ 🔥)
// =========================================================================
exports.deleteRoom = async (req, res, next) => {
  try {
    const { id } = req.params;

    // สั่ง Prisma ลบข้อมูลในตาราง PostgreSQL ตาม ID ที่ส่งมาจากหน้าบ้าน
    const deletedRoom = await prisma.room.delete({
      where: {
        id: parseInt(id, 10), 
      },
    });

    return res.status(200).json({
      success: true,
      message: 'ลบห้องประชุมออกจากฐานข้อมูลสำเร็จ',
      data: deletedRoom,
    });
  } catch (error) {
    console.error('❌ Error deleting room:', error);

    // ดักจับกรณีส่ง ID มาลบ แต่ไม่มี ID นี้อยู่ในฐานข้อมูลแล้ว (Prisma Error Code P2025)
    if (error.code === 'P2025') {
      return res.status(404).json({
        success: false,
        message: 'ไม่พบข้อมูลห้องประชุมที่ต้องการลบในระบบ',
      });
    }

    return res.status(500).json({
      success: false,
      message: 'เกิดข้อผิดพลาดในการลบข้อมูลห้องประชุม',
      error: error.message,
    });
  }
};