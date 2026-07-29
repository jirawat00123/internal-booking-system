const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Helper: ตรวจสอบว่าห้องนี้มีการจองในอนาคตหรือไม่
const checkFutureRoomBookings = async (roomId) => {
  const now = new Date();
  const futureBooking = await prisma.roomBooking.findFirst({
    where: {
      roomId: parseInt(roomId),
      endDatetime: { gt: now },
      status: { notIn: ['CANCELLED', 'REJECTED'] } 
    }
  });
  return futureBooking !== null;
};

// =========================================================================
// [GET] /api/rooms - ดึงข้อมูลห้องประชุมทั้งหมด
// =========================================================================
exports.getAllRooms = async (req, res, next) => {
  try {
    // ใช้ Prisma ดึงข้อมูลจากตาราง rooms ทั้งหมด
    const rooms = await prisma.room.findMany({
      where: {
        isDeleted: false,
      },
      orderBy: {
        id: 'asc',
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
// [GET] /api/rooms/:id - ดึงข้อมูลห้องประชุมรายห้อง
// =========================================================================
exports.getRoomById = async (req, res, next) => {
  try {
    const { id } = req.params;
    const room = await prisma.room.findFirst({
      where: { id: parseInt(id, 10), isDeleted: false }
    });

    if (!room) {
      return res.status(404).json({ success: false, message: 'ไม่พบข้อมูลห้องประชุม' });
    }

    return res.status(200).json({ success: true, data: room });
  } catch (error) {
    console.error('❌ Error fetching room by id:', error);
    return res.status(500).json({ success: false, message: 'เกิดข้อผิดพลาดภายในเซิร์ฟเวอร์', error: error.message });
  }
};

// =========================================================================
// [POST] /api/rooms - สร้างห้องประชุมใหม่
// =========================================================================
exports.createRoom = async (req, res, next) => {
  try {
    const { roomName, capacity, location, status } = req.body;
    let uploadUrl = null; 

    if (req.file) {
      uploadUrl = `/uploads/${req.file.filename}`;
    }

    if (!roomName || !capacity) {
      return res.status(400).json({
        success: false,
        message: 'กรุณาระบุชื่อห้องประชุม (roomName) และจำนวนความจุให้ครบถ้วน',
      });
    }

    // Validation: เช็คชื่อห้องซ้ำ
    const existingRoom = await prisma.room.findFirst({
      where: { roomName: roomName.toString(), isDeleted: false }
    });
    if (existingRoom) {
      return res.status(409).json({
        success: false,
        message: 'ชื่อห้องประชุมนี้มีในระบบแล้ว (Conflict)'
      });
    }

    const newRoom = await prisma.room.create({
      data: {
        roomName: roomName.toString(),
        capacity: parseInt(capacity),
        location: location ? location.toString() : null,
        status: status || 'AVAILABLE',
        uploadUrl: uploadUrl, 
      },
    });

    // 🟢 บันทึก AuditLog เมื่อสร้างห้องประชุมสำเร็จ
    const userId = req.user?.userId ? parseInt(req.user.userId, 10) : null;
    if (userId) {
      await prisma.auditLog.create({
        data: {
          action: "CREATE_ROOM",
          module: "ROOM",
          entityId: newRoom.id,
          entityType: "ROOM",
          userId: userId,
          details: `User ${userId} created room: ${newRoom.roomName}`
        }
      }).catch(err => console.error("AuditLog Error [CREATE_ROOM]:", err.message));
    }

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
// [PUT] /api/rooms/:id - อัปเดตข้อมูลห้องประชุม
// =========================================================================
exports.updateRoom = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { roomName, location, capacity, status } = req.body;
    let uploadUrl;

    if (req.file) {
      uploadUrl = `/uploads/${req.file.filename}`;
    }

    const updateData = {};
    
    if (roomName) {
      const existingRoom = await prisma.room.findFirst({
        where: { 
          roomName: roomName.toString(), 
          isDeleted: false,
          id: { not: parseInt(id) }
        }
      });
      if (existingRoom) {
        return res.status(409).json({ success: false, message: 'ชื่อห้องประชุมนี้มีในระบบแล้ว' });
      }
      updateData.roomName = roomName.toString();
    }
    
    if (location) updateData.location = location.toString();
    if (capacity) updateData.capacity = parseInt(capacity);
    
    if (status) {
      if (status === 'MAINTENANCE' || status === 'INACTIVE') {
        const hasFutureBookings = await checkFutureRoomBookings(id);
        if (hasFutureBookings) {
          return res.status(409).json({ 
            success: false, 
            message: `ไม่สามารถเปลี่ยนสถานะเป็น ${status} ได้ เนื่องจากมีคิวจองห้องล่วงหน้า` 
          });
        }
      }
      updateData.status = status;
    }
    
    if (uploadUrl) updateData.uploadUrl = uploadUrl;

    const updatedRoom = await prisma.room.update({
      where: { id: parseInt(id) },
      data: updateData,
    });

    // 🟢 บันทึก AuditLog เมื่ออัปเดตข้อมูลห้องประชุมสำเร็จ
    const userId = req.user?.userId ? parseInt(req.user.userId, 10) : null;
    if (userId) {
      await prisma.auditLog.create({
        data: {
          action: "UPDATE_ROOM",
          module: "ROOM",
          entityId: updatedRoom.id,
          entityType: "ROOM",
          userId: userId,
          details: `User ${userId} updated data for room ID ${updatedRoom.id}`
        }
      }).catch(err => console.error("AuditLog Error [UPDATE_ROOM]:", err.message));
    }

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
// [PATCH] /api/rooms/:id/status - อัปเดตเฉพาะสถานะห้อง
// =========================================================================
exports.updateRoomStatus = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    const allowedStatuses = ['AVAILABLE', 'IN_USE', 'RESERVED', 'MAINTENANCE', 'INACTIVE'];
    if (!allowedStatuses.includes(status)) {
      return res.status(400).json({ success: false, message: 'สถานะไม่ถูกต้อง (Invalid Status)' });
    }

    const room = await prisma.room.findFirst({ where: { id: parseInt(id, 10), isDeleted: false } });
    if (!room) return res.status(404).json({ success: false, message: 'ไม่พบข้อมูลห้องประชุม' });

    if (status === 'MAINTENANCE' || status === 'INACTIVE') {
      const hasFuture = await checkFutureRoomBookings(id);
      if (hasFuture) {
        return res.status(409).json({ 
          success: false, 
          message: `ไม่สามารถเปลี่ยนสถานะเป็น ${status} ได้ เนื่องจากมีคิวจองล่วงหน้า` 
        });
      }
    }

    const updatedRoom = await prisma.room.update({
      where: { id: parseInt(id, 10) },
      data: { status }
    });

    // 🟢 บันทึก AuditLog เมื่ออัปเดตสถานะสำเร็จ
    const userId = req.user?.userId ? parseInt(req.user.userId, 10) : null;
    if (userId) {
      await prisma.auditLog.create({
        data: {
          action: "UPDATE_ROOM_STATUS",
          module: "ROOM",
          entityId: updatedRoom.id,
          entityType: "ROOM",
          userId: userId,
          details: `User ${userId} updated room ID ${updatedRoom.id} status to ${status}`
        }
      }).catch(err => console.error("AuditLog Error [UPDATE_ROOM_STATUS]:", err.message));
    }

    return res.status(200).json({ success: true, message: 'อัปเดตสถานะสำเร็จ', data: updatedRoom });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'เกิดข้อผิดพลาด', error: error.message });
  }
};

// =========================================================================
// [DELETE] /api/rooms/:id - ลบห้องประชุมออกจากฐานข้อมูลถาวร (Soft Delete)
// =========================================================================
exports.deleteRoom = async (req, res, next) => {
  try {
    const { id } = req.params;

    console.log(`\n🚨กำลังทำ SOFT DELETE ห้องหมายเลข: ${id}🚨\n`);

    const room = await prisma.room.findFirst({ where: { id: parseInt(id, 10), isDeleted: false } });
    if (!room) {
      return res.status(404).json({ success: false, message: 'ไม่พบข้อมูลห้องประชุมที่ต้องการลบในระบบ' });
    }

    const hasFutureBookings = await checkFutureRoomBookings(id);
    if (hasFutureBookings) {
      return res.status(409).json({
        success: false,
        message: 'ไม่สามารถลบห้องได้เนื่องจากมีคิวจองล่วงหน้าค้างอยู่ (Conflict)',
      });
    }

    const deletedRoom = await prisma.room.update({
      where: {
        id: parseInt(id, 10),
      },
      data: {
        isDeleted: true, 
      },
    });

    // 🟢 บันทึก AuditLog เมื่อ Soft Delete สำเร็จ
    const userId = req.user?.userId ? parseInt(req.user.userId, 10) : null;
    if (userId) {
      await prisma.auditLog.create({
        data: {
          action: "DELETE_ROOM",
          module: "ROOM",
          entityId: deletedRoom.id,
          entityType: "ROOM",
          userId: userId,
          details: `User ${userId} soft deleted room ID ${deletedRoom.id}`
        }
      }).catch(err => console.error("AuditLog Error [DELETE_ROOM]:", err.message));
    }

    return res.status(200).json({
      success: true,
      message: 'ลบห้องประชุมออกจากฐานข้อมูลสำเร็จ (Soft Delete)',
      data: deletedRoom,
    });
  } catch (error) {
    console.error('❌ Error deleting room:', error);

    if (error.code === 'P2025') {
      return res.status(404).json({
        success: false,
        message: 'ไม่พบข้อมูลห้องประชุมที่ต้องการลบในระบบ',
      });
    }

    return res.status(500).json({
      success: false,
      message: 'เกิดข้อผิดพลาดในการอัปเดตสถานะห้องประชุม',
      error: error.message,
    });
  }
};