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
    console.log('📥 ข้อมูลที่ได้รับจาก Frontend:', req.body); // พิมพ์เช็กข้อมูล
    const { name, capacity, location } = req.body;

    // ตรวจสอบข้อมูลเบื้องต้น
    if (!name || !capacity) {
      return res.status(400).json({
        success: false,
        message: 'กรุณาระบุชื่อห้องประชุมและจำนวนความจุให้ครบถ้วน',
      });
    }

    // 💡 แก้ไขบั๊ก Prisma: ใช้ 'roomName' แทน 'name' ให้ตรงกับ Schema
    const newRoom = await prisma.room.create({
      data: {
        roomName: name.toString(), 
        capacity: parseInt(capacity),
        location: location ? location.toString() : null,
        // 💡 เพิ่มการบันทึกที่อยู่รูปภาพลงฐานข้อมูล
        uploadUrl: req.file ? `uploads/${req.file.filename}` : null,
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

exports.updateRoom = async (req, res, next) => {
  try {
    const roomId = parseInt(req.params.id);
    const { name, capacity, location, status } = req.body;

    // 1. ตรวจสอบว่ามีห้องนี้อยู่จริงไหม
    const existingRoom = await prisma.room.findUnique({
      where: { id: roomId },
    });

    if (!existingRoom) {
      return res.status(404).json({
        success: false,
        message: 'ไม่พบห้องประชุมที่ต้องการแก้ไข',
      });
    }

    // 2. ดึงชื่อไฟล์รูปภาพเดิมมาใช้ กรณีที่ไม่ได้อัปโหลดรูปใหม่มา
    let uploadUrl = existingRoom.uploadUrl;
    if (req.file) {
      // ถ้ามีการอัปโหลดรูปใหม่ (ผ่าน multer)
      uploadUrl = `/uploads/${req.file.filename}`;
    }

    // 3. อัปเดตข้อมูลลง Database
    const updatedRoom = await prisma.room.update({
      where: { id: roomId },
      data: {
        roomName: name || existingRoom.roomName,
        capacity: capacity ? parseInt(capacity) : existingRoom.capacity,
        location: location || existingRoom.location,
        status: status || existingRoom.status,
        uploadUrl: uploadUrl, // อัปเดต Path รูปภาพ
      },
    });

    return res.status(200).json({
      success: true,
      message: '✅ แก้ไขข้อมูลห้องประชุมเรียบร้อยแล้ว',
      data: updatedRoom,
    });
  } catch (error) {
    console.error('❌ Error updating room:', error);
    return res.status(500).json({
      success: false,
      message: 'เกิดข้อผิดพลาดในการแก้ไขข้อมูล',
      error: error.message,
    });
  }
};

// =========================================================================
// [DELETE] /api/rooms/:id - ลบห้องประชุม
// =========================================================================
exports.deleteRoom = async (req, res, next) => {
  try {
    const roomId = parseInt(req.params.id);

    // 1. ตรวจสอบว่ามีห้องนี้อยู่จริงไหม
    const existingRoom = await prisma.room.findUnique({
      where: { id: roomId },
    });

    if (!existingRoom) {
      return res.status(404).json({
        success: false,
        message: 'ไม่พบห้องประชุมที่ต้องการลบ',
      });
    }

    // 2. สั่งลบข้อมูลจาก Database
    await prisma.room.delete({
      where: { id: roomId },
    });

    return res.status(200).json({
      success: true,
      message: '🗑️ ลบห้องประชุมสำเร็จ',
    });
  } catch (error) {
    // 💡 ดัก Error กรณีห้องนี้ถูกจองไปแล้ว (ผูกอยู่กับ Foreign Key ในตาราง RoomBooking)
    if (error.code === 'P2003') {
      return res.status(400).json({
        success: false,
        message: 'ไม่สามารถลบห้องนี้ได้ เนื่องจากมีประวัติการจองค้างอยู่ในระบบ',
      });
    }
    
    console.error('❌ Error deleting room:', error);
    return res.status(500).json({
      success: false,
      message: 'เกิดข้อผิดพลาดในการลบห้องประชุม',
      error: error.message,
    });
  }
};