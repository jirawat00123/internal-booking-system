const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const fs = require('fs');
const path = require('path');

// =========================================================================
// [GET] /api/calendar/rooms - สำหรับแสดงปฏิทินห้องประชุม
// =========================================================================
exports.getRoomCalendar = async (req, res, next) => {
  try {
    const { startDate, endDate, roomId, location, departmentId, status } = req.query;
    console.log('[TRACE] getRoomCalendar START:', { startDate, endDate });

    // ต้องระบุช่วงเวลาเสมอ เพื่อไม่ให้ดึงข้อมูลทั้ง Database (Performance Optimization)
    if (!startDate || !endDate) {
      return res.status(400).json({ 
        success: false, 
        message: 'กรุณาระบุ startDate และ endDate' 
      });
    }

    const queryStart = new Date(startDate);
    const queryEnd = new Date(endDate);

    if (isNaN(queryStart.getTime()) || isNaN(queryEnd.getTime())) {
      return res.status(400).json({
        success: false,
        message: 'รูปแบบ startDate หรือ endDate ไม่ถูกต้อง'
      });
    }

    // สร้างเงื่อนไขการค้นหา (Filter)
    let whereClause = {
      room: { isDeleted: false },
      startDatetime: { lte: queryEnd },
      endDatetime: { gte: queryStart }
    };

    if (roomId) whereClause.roomId = parseInt(roomId);

    if (location) {
      whereClause.room.location = location;
    }
    
    if (status) {
      whereClause.status = status;
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
    console.log('[TRACE] getVehicleCalendar START:', { startDate, endDate });

    if (!startDate || !endDate) {
      return res.status(400).json({ 
        success: false, 
        message: 'กรุณาระบุ startDate และ endDate' 
      });
    }

    const queryStart = new Date(startDate);
    const queryEnd = new Date(endDate);

    if (isNaN(queryStart.getTime()) || isNaN(queryEnd.getTime())) {
      return res.status(400).json({
        success: false,
        message: 'รูปแบบ startDate หรือ endDate ไม่ถูกต้อง'
      });
    }

    let whereClause = {
      vehicle: { isDeleted: false },
      startDatetime: { lte: queryEnd },
      endDatetime: { gte: queryStart }
    };

    if (vehicleId) whereClause.vehicleId = parseInt(vehicleId);
    
    if (status) {
      whereClause.status = status;
    } else {
      whereClause.status = { notIn: ['CANCELLED', 'REJECTED'] };
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
        driverEmployee: true,
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
    console.log('[TRACE] getUnifiedCalendar START:', { startDate, endDate });

    if (!startDate || !endDate) {
      return res.status(400).json({ 
        success: false, 
        message: 'กรุณาระบุ startDate และ endDate' 
      });
    }

    const queryStart = new Date(startDate);
    const queryEnd = new Date(endDate);

    if (isNaN(queryStart.getTime()) || isNaN(queryEnd.getTime())) {
      return res.status(400).json({
        success: false,
        message: 'รูปแบบ startDate หรือ endDate ไม่ถูกต้อง'
      });
    }

    let roomWhereClause = {
      room: { isDeleted: false },
      startDatetime: { lte: queryEnd },
      endDatetime: { gte: queryStart }
    };

    let vehicleWhereClause = {
      vehicle: { isDeleted: false },
      startDatetime: { lte: queryEnd },
      endDatetime: { gte: queryStart }
    };

    // กรองประวัติที่เสร็จสิ้นหรือยกเลิกแล้วออก เพื่อแสดงเฉพาะรายการที่ยังต้องดำเนินการบนปฏิทิน
    if (status) {
      roomWhereClause.status = status;
      vehicleWhereClause.status = status;
    } else {
      roomWhereClause.status = { notIn: ['CANCELLED', 'REJECTED'] };
      vehicleWhereClause.status = { notIn: ['CANCELLED', 'REJECTED'] };
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

// =========================================================================
// [GET] /api/calendar/vehicles-grid - สำหรับแสดงปฏิทินรถยนต์รูปแบบตาราง (Matrix)
// =========================================================================
exports.getVehicleCalendarGrid = async (req, res, next) => {
  try {
    const { startDate, endDate } = req.query;
    console.log('[TRACE] getVehicleCalendarGrid START:', { startDate, endDate });

    if (!startDate || !endDate) {
      return res.status(400).json({ 
        success: false, 
        message: 'กรุณาระบุ startDate และ endDate' 
      });
    }

    const start = new Date(startDate);
    const end = new Date(endDate);

    if (isNaN(start.getTime()) || isNaN(end.getTime())) {
      return res.status(400).json({
        success: false,
        message: 'รูปแบบ startDate หรือ endDate ไม่ถูกต้อง'
      });
    }

    // 1. ดึงข้อมูลรถยนต์ทั้งหมดในระบบ (แกน Y ของตาราง)
    const vehicles = await prisma.vehicle.findMany({
      where: { isDeleted: false },
      orderBy: { plateNumber: 'asc' }
    });

    // 2. ดึงรายการจองในช่วงวันที่กำหนด (Overlapping Range)
    const bookings = await prisma.vehicleBooking.findMany({
      where: {
        vehicle: { isDeleted: false },
        startDatetime: { lte: end },
        endDatetime: { gte: start },
        status: { notIn: ['CANCELLED', 'REJECTED'] }
      },
      include: {
        vehicle: true,
        driverEmployee: true,
        user: { include: { employee: true } }
      }
    });

    console.log(`[DEBUG] Found ${bookings.length} vehicle bookings`);

    // 3. จัดกลุ่มการจองเข้าไปในรถแต่ละคัน (Matrix Data)
        const result = vehicles.map(vehicle => {
          const vehicleBookings = bookings.filter(b => b.vehicleId === vehicle.id);
          return {
            vehicleId: vehicle.id,
            vehicleName: `${vehicle.brand || ''} ${vehicle.model || ''}`.trim(),
            plateNumber: vehicle.plateNumber,
            upload_url: vehicle.upload_url || vehicle.uploadUrl || vehicle.imageUrl || vehicle.image || null,
            bookings: vehicleBookings.map(b => ({
              id: b.id,
              userName: b.user?.employee?.fullName || b.user?.username || '-',
              purpose: b.purpose || '-',
              startDatetime: b.startDatetime,
              endDatetime: b.endDatetime,
              status: b.status,
              driverType: b.driverType,
              driverName: b.driverEmployee?.fullName || 'ไม่ได้จัดสรรคนขับ'
            }))
          };
        });

    return res.status(200).json({ 
      success: true, 
      data: result 
    });

  } catch (error) {
    console.error('[getVehicleCalendarGrid Error]:', error);
    next(error);
  }
};

// =========================================================================
// [GET] /api/calendar/rooms-grid - สำหรับแสดงปฏิทินห้องประชุมรูปแบบตาราง (Matrix)
// =========================================================================
exports.getRoomCalendarGrid = async (req, res, next) => {
  try {
    const { startDate, endDate, location } = req.query;
    console.log('[TRACE] getRoomCalendarGrid START:', { startDate, endDate, location });

    if (!startDate || !endDate) {
      return res.status(400).json({ 
        success: false, 
        message: 'กรุณาระบุ startDate และ endDate' 
      });
    }

    const start = new Date(startDate);
    const end = new Date(endDate);

    if (isNaN(start.getTime()) || isNaN(end.getTime())) {
      return res.status(400).json({
        success: false,
        message: 'รูปแบบ startDate หรือ endDate ไม่ถูกต้อง'
      });
    }

    let roomWhere = { isDeleted: false };
    if (location) {
      roomWhere.location = location;
    }

    const rooms = await prisma.room.findMany({
      where: roomWhere,
      orderBy: { roomName: 'asc' }
    });

    const bookings = await prisma.roomBooking.findMany({
      where: {
        room: { isDeleted: false },
        startDatetime: { lte: end },
        endDatetime: { gte: start }
      },
      include: {
        room: true,
        user: { include: { employee: true } }
      }
    });

    console.log(`[DEBUG] Found ${bookings.length} room bookings`);

    const result = rooms.map(room => {
      const roomBookings = bookings.filter(b => b.roomId === room.id);
      return {
        roomId: room.id,
        roomName: room.roomName,
        location: room.location,
        floor: room.floor,
        upload_url: room.upload_url || room.uploadUrl || room.imageUrl || room.image || null,
        bookings: roomBookings.map(b => ({
          id: b.id,
          userName: b.user?.employee?.fullName || b.user?.username || '-',
          purpose: b.title || b.purpose || '-',
          startDatetime: b.startDatetime,
          endDatetime: b.endDatetime,
          status: b.status
        }))
      };
    });

    return res.status(200).json({ 
      success: true, 
      data: result 
    });

  } catch (error) {
    console.error('[getRoomCalendarGrid Error]:', error);
    next(error);
  }
};