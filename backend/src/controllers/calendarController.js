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
      // ดึงการจองที่คาบเกี่ยวอยู่ในช่วงเวลาที่ขอดู (Day/Week/Month)
      startDatetime: { lte: new Date(endDate) },
      endDatetime: { gte: new Date(startDate) }
    };

    if (roomId) whereClause.roomId = parseInt(roomId);
    if (status) whereClause.status = status;
    
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
      startDatetime: { lte: new Date(endDate) },
      endDatetime: { gte: new Date(startDate) }
    };

    if (vehicleId) whereClause.vehicleId = parseInt(vehicleId);
    if (status) whereClause.status = status;
    
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