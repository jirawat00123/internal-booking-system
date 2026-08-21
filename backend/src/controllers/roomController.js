const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Helper: ตรวจสอบว่าห้องนี้มีการจองในอนาคตหรือไม่
const checkFutureRoomBookings = async (roomId) => {
  const now = new Date();
  const futureBooking = await prisma.roomBooking.findFirst({
    where: {
      roomId: parseInt(roomId, 10),
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
    const now = new Date();

    // 1. รับ Query Parameters สำหรับ Search & Filter
    const { search, status, location, minCapacity, page, limit } = req.query;

    // 2. ตั้งค่า Pagination (ถ้าไม่ส่งมา ให้ใช้ default ที่เยอะๆ ไปก่อนเพื่อไม่ให้กระทบระบบเก่า)
    const pageNum = parseInt(page) || 1;
    const limitNum = parseInt(limit) || 50; 
    const skip = (pageNum - 1) * limitNum;

    // 3. สร้าง whereClause สำหรับ Prisma
    const whereClause = {
      isDeleted: false,
    };

    // --- เพิ่ม Logic ของ Phase 8 ---
    if (search) {
      whereClause.roomName = { contains: search, mode: 'insensitive' };
    }
    if (status) {
      whereClause.status = status;
    }
    if (location) {
      whereClause.location = { contains: location, mode: 'insensitive' };
    }
    if (minCapacity) {
      whereClause.capacity = { gte: parseInt(minCapacity, 10) };
    }

    // 4. Query Database (คัดกรองเฉพาะรายการจองที่ยังไม่ถูกยกเลิก/ปฏิเสธ และยังไม่หมดอายุ)
    const [totalItems, roomsList] = await Promise.all([
      prisma.room.count({ where: whereClause }),
      prisma.room.findMany({
        where: whereClause,
        include: {
          bookings: {
            where: {
              status: { notIn: ['CANCELLED', 'REJECTED'] },
              endDatetime: { gte: now }
            }
          }
        },
        orderBy: { id: 'asc' },
        skip: skip,
        take: limitNum,
      })
    ]);

    // คำนวณ Runtime Field (availabilityStatus) ตามช่วงเวลาปัจจุบันโดยไม่แก้ Room.status ใน DB
    const rooms = roomsList.map(room => {
      let availabilityStatus = room.status;

      if (room.status === 'AVAILABLE') {
        const activeBookings = room.bookings || [];
        const nowTime = Date.now();

        const isCurrentlyInUse = activeBookings.some(b => {
          const start = new Date(b.startDatetime).getTime();
          const end = new Date(b.endDatetime).getTime();
          return start <= nowTime && nowTime < end;
        });

        const hasUpcomingBooking = activeBookings.some(b => {
          const start = new Date(b.startDatetime).getTime();
          return nowTime < start;
        });

        if (isCurrentlyInUse) {
          availabilityStatus = 'IN_USE';
        } else if (hasUpcomingBooking) {
          availabilityStatus = 'RESERVED';
        } else {
          availabilityStatus = 'AVAILABLE';
        }
      }

      const { bookings, ...roomData } = room;

      return {
        ...roomData,
        availabilityStatus
      };
    });

    // 5. ส่ง Response แบบมี Pagination (สอดคล้องกับ Blueprint ข้อ 8.6)
    return res.status(200).json({
      success: true,
      data: rooms,
      pagination: {
        page: pageNum,
        limit: limitNum,
        total: totalItems,
        totalPages: Math.ceil(totalItems / limitNum)
      }
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
    const { roomName, capacity, location, status, floor, description, room_code } = req.body;
    // 💡 รองรับทั้งกรณีอัปโหลดไฟล์ผ่าน multer (req.file) และส่ง URL/Path มาใน req.body
    let uploadUrl = null;
    if (req.file) {
      uploadUrl = '/uploads/rooms/' + req.file.filename;
    } else if (req.body.uploadUrl) {
      const fileName = req.body.uploadUrl.split(/[\/\\]/).pop();
      uploadUrl = fileName ? '/uploads/rooms/' + fileName : null;
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
        floor: floor ? floor.toString() : null,
        description: description ? description.toString() : null,
        room_code: room_code ? room_code.toString() : null,
      },
    });

    // 🟢 บันทึก AuditLog เมื่อสร้างห้องประชุมสำเร็จ (รองรับทั้ง req.user.id และ req.user.userId)
    const rawUserId = req.user?.id || req.user?.userId;
    const userId = rawUserId ? parseInt(rawUserId, 10) : null;
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
    const roomId = parseInt(id, 10);
    const { roomName, location, capacity, status, floor, description, room_code } = req.body;
    let uploadUrl;

    // 🟢 ตรวจสอบก่อนว่ามีห้องนี้อยู่จริงและไม่ได้ถูกลบ (isDeleted: false)
    const currentRoom = await prisma.room.findFirst({
      where: { id: roomId, isDeleted: false }
    });
    if (!currentRoom) {
      return res.status(404).json({ success: false, message: 'ไม่พบข้อมูลห้องประชุม หรือห้องนี้ถูกลบไปแล้ว' });
    }

    if (req.file) {
      // ประกอบ Web URL Path โดยใช้ filename เพื่อให้พร้อมสำหรับ Frontend นำไปใช้งาน
      uploadUrl = '/uploads/rooms/' + req.file.filename;
    } else if (req.body.uploadUrl) {
      const fileName = req.body.uploadUrl.split(/[\/\\]/).pop();
      if (fileName) {
        uploadUrl = '/uploads/rooms/' + fileName;
      }
    }

    const updateData = {};
    
    if (roomName) {
      const existingRoom = await prisma.room.findFirst({
        where: { 
          roomName: roomName.toString(), 
          isDeleted: false,
          id: { not: roomId }
        }
      });
      if (existingRoom) {
        return res.status(409).json({ success: false, message: 'ชื่อห้องประชุมนี้มีในระบบแล้ว' });
      }
      updateData.roomName = roomName.toString();
    }
    
    if (location !== undefined) updateData.location = location ? location.toString() : null;
    if (capacity && !isNaN(parseInt(capacity, 10))) updateData.capacity = parseInt(capacity, 10);
    if (floor !== undefined) updateData.floor = floor ? floor.toString() : null;
    if (description !== undefined) updateData.description = description ? description.toString() : null;
    if (room_code !== undefined) updateData.room_code = room_code ? room_code.toString() : null;
    
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
      where: { id: roomId },
      data: updateData,
    });

    // 🟢 บันทึก AuditLog เมื่ออัปเดตข้อมูลห้องประชุมสำเร็จ (รองรับทั้ง req.user.id และ req.user.userId)
    const rawUserId = req.user?.id || req.user?.userId;
    const userId = rawUserId ? parseInt(rawUserId, 10) : null;
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

    // 🟢 1. อัปเดตให้รองรับเฉพาะสถานะของ Room ตาม Prisma Schema
    const allowedStatuses = ['AVAILABLE', 'MAINTENANCE', 'INACTIVE'];
    if (!allowedStatuses.includes(status)) {
      return res.status(400).json({ success: false, message: 'สถานะไม่ถูกต้อง (รองรับเฉพาะ AVAILABLE, MAINTENANCE, INACTIVE)' });
    }

    // Validation ID
    const roomId = parseInt(id, 10);
    if (isNaN(roomId)) {
      return res.status(400).json({ success: false, message: 'ID ของห้องประชุมไม่ถูกต้อง' });
    }

    const room = await prisma.room.findFirst({ where: { id: roomId, isDeleted: false } });
    if (!room) return res.status(404).json({ success: false, message: 'ไม่พบข้อมูลห้องประชุม' });

    // 🟢 2. ปรับเงื่อนไข: บล็อกเฉพาะเวลาจะซ่อมแซมหรือปิดใช้งาน หากยังมีคิวจองล่วงหน้าค้างอยู่
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
      where: { id: roomId },
      data: { status }
    });

    // 🟢 บันทึก AuditLog เมื่ออัปเดตสถานะสำเร็จ (รองรับทั้ง req.user.id และ req.user.userId)
    const rawUserId = req.user?.id || req.user?.userId;
    const userId = rawUserId ? parseInt(rawUserId, 10) : null;
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

    // 🟢 บันทึก AuditLog เมื่อ Soft Delete สำเร็จ (รองรับทั้ง req.user.id และ req.user.userId)
    const rawUserId = req.user?.id || req.user?.userId;
    const userId = rawUserId ? parseInt(rawUserId, 10) : null;
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