const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// =========================================================================
// [GET] /api/calendar/rooms - สำหรับแสดงปฏิทินห้องประชุม
// =========================================================================
exports.getRoomCalendar = async (req, res, next) => {
  try {
    const { startDate, endDate, roomId, departmentId, status, location } = req.query;

    // ต้องระบุช่วงเวลาเสมอ เพื่อไม่ให้ดึงข้อมูลทั้ง Database (Performance Optimization)
    if (!startDate || !endDate) {
      return res.status(400).json({ 
        success: false, 
        message: 'กรุณาระบุ startDate และ endDate' 
      });
    }

    const now = new Date();
    const effectiveStartDate = new Date(startDate) > now ? new Date(startDate) : now;

    let whereClause = {
      startDatetime: { lte: new Date(endDate) },
      endDatetime: { 
        gte: effectiveStartDate
      }
    };

    if (roomId) whereClause.roomId = parseInt(roomId);
    
    // Filter ตามฝั่ง (Location)
    if (location) {
      whereClause.room = {
        location: location
      };
    }
    
    if (status) {
      whereClause.status = status;
    } else {
      whereClause.status = { notIn: ['COMPLETED', 'CANCELLED', 'EXPIRED', 'REJECTED'] };
    }
    
    // Filter ตามแผนก (Department)
    if (departmentId) {
      whereClause.user = {
        employee: {
          departmentId: parseInt(departmentId)
        }
      };
    }

    const bookings = await prisma.roomBooking.findMany({
      where: whereClause,
      include: {
        room: true, // ดึงข้อมูลห้อง
        user: {
          include: {
            employee: {
              include: { department: true } // ดึงข้อมูลพนักงานและแผนก
            }
          }
        }
      },
      orderBy: { startDatetime: 'asc' } // เรียงลำดับเวลา
    });

    return res.status(200).json({
      success: true,
      data: bookings
    });

  } catch (error) {
    next(error);
  }
};

// =========================================================================
// [GET] /api/calendar/vehicles - สำหรับแสดงปฏิทินรถยนต์
// =========================================================================
exports.getVehicleCalendar = async (req, res, next) => {
  try {
    const { startDate, endDate, vehicleId, departmentId, status } = req.query;

    if (!startDate || !endDate) {
      return res.status(400).json({ 
        success: false, 
        message: 'กรุณาระบุ startDate และ endDate' 
      });
    }

    const now = new Date();
    const effectiveStartDate = new Date(startDate) > now ? new Date(startDate) : now;

    let whereClause = {
      startDatetime: { lte: new Date(endDate) },
      endDatetime: { 
        gte: effectiveStartDate
      }
    };

    if (vehicleId) whereClause.vehicleId = parseInt(vehicleId);
    
    if (status) {
      whereClause.status = status;
    } else {
      whereClause.status = { notIn: ['COMPLETED', 'CANCELLED', 'EXPIRED', 'REJECTED'] };
    }
    if (departmentId) {
      whereClause.user = {
        employee: {
          departmentId: parseInt(departmentId)
        }
      };
    }

    const bookings = await prisma.vehicleBooking.findMany({
      where: whereClause,
      include: {
        vehicle: true,
        user: {
          include: {
            employee: {
              include: { department: true }
            }
          }
        }
      },
      orderBy: { startDatetime: 'asc' }
    });

    return res.status(200).json({
      success: true,
      data: bookings
    });

  } catch (error) {
    next(error);
  }
};

// =========================================================================
// [GET] /api/calendar/all - สำหรับแสดงปฏิทินรวม (Room + Vehicle) รูปแบบ Unified Event
// =========================================================================
exports.getUnifiedCalendar = async (req, res, next) => {
  try {
    const { startDate, endDate, status } = req.query;

    if (!startDate || !endDate) {
      return res.status(400).json({ 
        success: false, 
        message: 'กรุณาระบุ startDate และ endDate' 
      });
    }

    const now = new Date();
    const effectiveStartDate = new Date(startDate) > now ? new Date(startDate) : now;

    let roomWhereClause = {
      startDatetime: { lte: new Date(endDate) },
      endDatetime: { 
        gte: effectiveStartDate
      }
    };

    let vehicleWhereClause = {
      startDatetime: { lte: new Date(endDate) },
      endDatetime: { 
        gte: effectiveStartDate
      }
    };

    if (status) {
      roomWhereClause.status = status;
      vehicleWhereClause.status = status;
    } else {
      roomWhereClause.status = { notIn: ['COMPLETED', 'CANCELLED', 'EXPIRED', 'REJECTED'] };
      vehicleWhereClause.status = { notIn: ['COMPLETED', 'CANCELLED', 'EXPIRED', 'REJECTED'] };
    }

    // 1. ดึงข้อมูลการจองห้อง
    const roomBookings = await prisma.roomBooking.findMany({
      where: roomWhereClause,
      include: {
        room: true,
        user: { include: { employee: true } }
      }
    });

    // 2. ดึงข้อมูลการจองรถ
    const vehicleBookings = await prisma.vehicleBooking.findMany({
      where: vehicleWhereClause,
      include: {
        vehicle: true,
        user: { include: { employee: true } }
      }
    });

    // 3. รวมข้อมูลและ Map Data Format (Unified Event)
    const unifiedEvents = [
      ...roomBookings.map(b => ({
        eventId: `ROOM-${b.id}`,
        originalId: b.id,
        type: 'ROOM',
        title: b.room?.roomName || 'ไม่ระบุห้อง',
        bookerName: b.user?.employee?.fullName || 'ไม่ระบุชื่อผู้จอง',
        start: b.startDatetime,
        end: b.endDatetime,
        color: '#42BCA4', // สามารถระบุสีแยกประเภทให้ Frontend ได้เลย
        status: b.status,
        roomInfo: b.room // ส่งข้อมูลห้องไปแสดงใน Modal ฝั่งแอป
      })),
      ...vehicleBookings.map(b => ({
        eventId: `VEHICLE-${b.id}`,
        originalId: b.id,
        type: 'VEHICLE',
        title: `${b.vehicle?.brand || ''} ${b.vehicle?.model || ''} (${b.vehicle?.plateNumber || ''})`.trim() || 'ไม่ระบุรถ',
        bookerName: b.user?.employee?.fullName || 'ไม่ระบุชื่อผู้จอง',
        start: b.startDatetime,
        end: b.endDatetime,
        color: '#FF9800',
        status: b.status,
        vehicleInfo: b.vehicle // ส่งข้อมูลรถไปแสดงใน Modal ฝั่งแอป
      }))
    ];

    // เรียงลำดับรายการตามเวลาเริ่มต้น
    unifiedEvents.sort((a, b) => new Date(a.start) - new Date(b.start));

    return res.status(200).json({
      success: true,
      data: unifiedEvents
    });

  } catch (error) {
    console.error('[getUnifiedCalendar Error]:', error);
    next(error);
  }
};