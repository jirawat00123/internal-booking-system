const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// =========================================================================
// [GET] /api/calendar/rooms - สำหรับแสดงปฏิทินห้องประชุม
// =========================================================================
exports.getRoomCalendar = async (req, res, next) => {
  try {
    const { startDate, endDate, roomId, departmentId, status } = req.query;

    // ต้องระบุช่วงเวลาเสมอ เพื่อไม่ให้ดึงข้อมูลทั้ง Database (Performance Optimization)
    if (!startDate || !endDate) {
      return res.status(400).json({ 
        success: false, 
        message: 'กรุณาระบุ startDate และ endDate' 
      });
    }

    // สร้างเงื่อนไขการค้นหา (Filter)
    let whereClause = {
      // ดึงการจองที่คาบเกี่ยวอยู่ในช่วงเวลาที่ขอดู และเวลายังไม่สิ้นสุด (ไม่แสดงประวัติในอดีต)
      startDatetime: { lte: new Date(endDate) },
      endDatetime: { gte: new Date() }
    };

    if (roomId) whereClause.roomId = parseInt(roomId);
    
    if (status) {
      whereClause.status = status;
    } else {
      whereClause.status = { in: ['PENDING', 'APPROVED', 'IN_USE'] };
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

    let whereClause = {
      // ดึงการจองที่คาบเกี่ยวอยู่ในช่วงเวลาที่ขอดู และเวลายังไม่สิ้นสุด (ไม่แสดงประวัติในอดีต)
      startDatetime: { lte: new Date(endDate) },
      endDatetime: { gte: new Date() }
    };

    if (vehicleId) whereClause.vehicleId = parseInt(vehicleId);
    
    if (status) {
      whereClause.status = status;
    } else {
      whereClause.status = { in: ['PENDING', 'APPROVED', 'IN_USE'] };
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

    let roomWhereClause = {
      startDatetime: { lte: new Date(endDate) },
      endDatetime: { gte: new Date() } // กรองรายการในอดีตออก
    };

    let vehicleWhereClause = {
      startDatetime: { lte: new Date(endDate) },
      endDatetime: { gte: new Date() } // กรองรายการในอดีตออก
    };

    // กรองประวัติที่เสร็จสิ้นหรือยกเลิกแล้วออก เพื่อแสดงเฉพาะรายการที่ยังต้องดำเนินการบนปฏิทิน
    if (status) {
      roomWhereClause.status = status;
      vehicleWhereClause.status = status;
    } else {
      const activeStatus = { in: ['PENDING', 'APPROVED', 'IN_USE'] };
      roomWhereClause.status = activeStatus;
      vehicleWhereClause.status = activeStatus;
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
        status: b.status
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
        status: b.status
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