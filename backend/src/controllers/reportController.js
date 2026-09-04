const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// ... (ฟังก์ชันเดิมที่มีอยู่) ...

// ==========================================
// Phase 7: Aggregated Dashboard Controllers
// ==========================================

/**
 * 1. Admin Dashboard Aggregation API
 * GET /api/reports/dashboard/admin
 */
const getAdminDashboard = async (req, res) => {
  try {
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    const todayEnd = new Date();
    todayEnd.setHours(23, 59, 59, 999);

    // รัน Query พร้อมกันด้วย Promise.all ป้องกัน N+1
    const [
      totalRooms,
      totalVehicles,
      todayRoomBookings,
      todayVehicleBookings,
      roomStatusStats,
      vehicleStatusStats,
      activeUsersCount
    ] = await Promise.all([
      prisma.room.count({ where: { isDeleted: false } }),
      prisma.vehicle.count({ where: { isDeleted: false } }),
      prisma.roomBooking.count({
        where: { createdAt: { gte: todayStart, lte: todayEnd } }
      }),
      prisma.vehicleBooking.count({
        where: { createdAt: { gte: todayStart, lte: todayEnd } }
      }),
      prisma.roomBooking.groupBy({
        by: ['status'],
        _count: { status: true }
      }),
      prisma.vehicleBooking.groupBy({
        by: ['status'],
        _count: { status: true }
      }),
      prisma.user.count({ where: { active: true } })
    ]);

    // แปลง groupBy ให้เป็น Key-Value Pair ที่อ่านง่าย
    const roomStatusMap = {};
    roomStatusStats.forEach(item => {
      roomStatusMap[item.status] = item._count.status;
    });

    const vehicleStatusMap = {};
    vehicleStatusStats.forEach(item => {
      vehicleStatusMap[item.status] = item._count.status;
    });

    return res.status(200).json({
      success: true,
      data: {
        summary: {
          totalRooms,
          totalVehicles,
          todayTotalBookings: todayRoomBookings + todayVehicleBookings,
          activeUsers: activeUsersCount
        },
        roomStats: roomStatusMap,
        vehicleStats: vehicleStatusMap,
        permissions: {
          canExportReport: (req.user?.role || '').toUpperCase() === 'ADMIN',
          canManageSystem: true
        }
      }
    });
  } catch (error) {
    console.error('[Dashboard Error - Admin]:', error);
    return res.status(500).json({
      success: false,
      error: 'ไม่สามารถดึงข้อมูล Admin Dashboard ได้: ' + error.message
    });
  }
};

/**
 * 2. User Dashboard Aggregation API
 * GET /api/reports/dashboard/user
 */
const getUserDashboard = async (req, res) => {
  try {
    const userId = parseInt(req.user.userId, 10);

    const [
      myTotalRoomBookings,
      myTotalVehicleBookings,
      pendingRoomBookings,
      pendingVehicleBookings,
      recentRoomBookings,
      recentVehicleBookings
    ] = await Promise.all([
      prisma.roomBooking.count({ where: { userId } }),
      prisma.vehicleBooking.count({ where: { userId } }),
      prisma.roomBooking.count({ where: { userId, status: 'PENDING' } }),
      prisma.vehicleBooking.count({ where: { userId, status: 'PENDING' } }),
      prisma.roomBooking.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        take: 5,
        include: { room: true }
      }),
      prisma.vehicleBooking.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        take: 5,
        include: { vehicle: true }
      })
    ]);

    return res.status(200).json({
      success: true,
      data: {
        summary: {
          myTotalBookings: myTotalRoomBookings + myTotalVehicleBookings,
          pendingApprovals: pendingRoomBookings + pendingVehicleBookings
        },
        recentBookings: {
          rooms: recentRoomBookings,
          vehicles: recentVehicleBookings
        },
        permissions: {
          canCreateRoomBooking: true,
          canCreateVehicleBooking: true
        }
      }
    });
  } catch (error) {
    console.error('[Dashboard Error - User]:', error);
    return res.status(500).json({
      success: false,
      error: 'ไม่สามารถดึงข้อมูล User Dashboard ได้: ' + error.message
    });
  }
};

/**
 * 3. Security Dashboard Aggregation API
 * GET /api/reports/dashboard/security
 */
const getSecurityDashboard = async (req, res) => {
  try {
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    const todayEnd = new Date();
    todayEnd.setHours(23, 59, 59, 999);

    const [
      vehiclesInUse,
      todayCheckoutCount,
      waitingReturnCount,
      todayVehicleLogs
    ] = await Promise.all([
      prisma.vehicleBooking.count({ where: { status: 'IN_USE' } }),
      prisma.vehicleBooking.count({
        where: {
          status: { in: ['APPROVED', 'IN_USE'] },
          startDatetime: { gte: todayStart, lte: todayEnd }
        }
      }),
      prisma.vehicleBooking.count({ where: { status: 'IN_USE' } }),
      prisma.vehicleBooking.findMany({
        where: {
          status: { in: ['APPROVED', 'IN_USE', 'COMPLETED'] },
          startDatetime: { gte: todayStart, lte: todayEnd }
        },
        include: { vehicle: true, user: true },
        orderBy: { startDatetime: 'asc' },
        take: 10
      })
    ]);

    return res.status(200).json({
      success: true,
      data: {
        summary: {
          vehiclesInUse,
          todayCheckoutCount,
          waitingReturnCount
        },
        todayLogs: todayVehicleLogs,
        permissions: {
          canCheckOut: true,
          canCheckIn: true
        }
      }
    });
  } catch (error) {
    console.error('[Dashboard Error - Security]:', error);
    return res.status(500).json({
      success: false,
      error: 'ไม่สามารถดึงข้อมูล Security Dashboard ได้: ' + error.message
    });
  }
};

/**
 * 4. Export Report API + AuditLog Integration
 * GET /api/reports/export
 */
const exportReport = async (req, res) => {
  try {
    const { type = 'room', format = 'json', startDate, endDate } = req.query;

    let filter = {};
    if (startDate && endDate) {
      filter.createdAt = {
        gte: new Date(startDate),
        lte: new Date(endDate)
      };
    }

    let reportData = [];
    if (type === 'room') {
      reportData = await prisma.roomBooking.findMany({
        where: filter,
        include: { room: true, user: true },
        orderBy: { createdAt: 'desc' }
      });
    } else {
      reportData = await prisma.vehicleBooking.findMany({
        where: filter,
        include: { vehicle: true, user: true },
        orderBy: { createdAt: 'desc' }
      });
    }

// บันทึก AuditLog อัตโนมัติเมื่อมีการ Export รายงาน
    await prisma.auditLog.create({
      data: {
        userId: parseInt(req.user.userId, 10),
        action: 'EXPORT_REPORT',
        module: 'REPORT',
        entityId: 0,
        entityType: type === 'room' ? 'ROOM_BOOKING_REPORT' : 'VEHICLE_BOOKING_REPORT',
        details: JSON.stringify({
          format,
          recordCount: reportData.length,
          startDate,
          endDate
        })
      }
    }).catch(err => console.error("AuditLog Error [EXPORT_REPORT]:", err.message));

// 🟢 ส่งออกเป็นไฟล์ CSV ให้เบราว์เซอร์ดาวน์โหลดเสมอ
    if (true) {
      const header = 'ID,รายการ/สถานที่,ผู้จอง,สถานะ,วันที่เริ่ม,วันที่สิ้นสุด\n';
      const rows = reportData.map(item => {
        const title = type === 'room' 
          ? (item.room?.roomName || item.purpose || '') 
          : (item.vehicle?.plateNumber || item.destination || '');
        const booker = item.user?.employee 
          ? `${item.user.employee.firstName || ''} ${item.user.employee.lastName || ''}`.trim()
          : (item.user?.username || '-');
        const start = item.startDatetime ? new Date(item.startDatetime).toLocaleString('th-TH') : '-';
        const end = item.endDatetime ? new Date(item.endDatetime).toLocaleString('th-TH') : '-';

        return `"${item.id}","${title}","${booker}","${item.status}","${start}","${end}"`;
      }).join('\n');

      // ใส่ BOM (\uFEFF) เพื่อให้ Excel เปิดภาษาไทยได้โดยอักษรไม่ต่างดาว
      const csvContent = '\uFEFF' + header + rows;

      res.setHeader('Content-Type', 'text/csv; charset=utf-8');
      res.setHeader('Content-Disposition', `attachment; filename=report_${type}_${Date.now()}.csv`);
      return res.status(200).send(csvContent);
    }

    return res.status(200).json({
      success: true,
      exportInfo: {
        type,
        format,
        totalRecords: reportData.length,
        exportedAt: new Date()
      },
      data: reportData
    });
} catch (error) {
    console.error('[Export Error]:', error);
    return res.status(500).json({
      success: false,
      error: 'ไม่สามารถ Export รายงานได้: ' + error.message
    });
  }
};

// =========================================================================
// [GET] /api/reports/bookings - Aggregated Search API (Phase 8)
// =========================================================================
const getAggregatedBookings = async (req, res, next) => {
  try {
    const { 
      search, resourceType, departmentId, employeeId, 
      status, startDate, endDate, page, limit 
    } = req.query;

    const pageNum = parseInt(page) || 1;
    const limitNum = parseInt(limit) || 20;

    const dateFilter = {};
    if (startDate) dateFilter.gte = new Date(startDate);
    if (endDate) {
      const end = new Date(endDate);
      end.setHours(23, 59, 59, 999);
      dateFilter.lte = end;
    }

    const userFilter = {};
    if (employeeId) userFilter.id = parseInt(employeeId);
    if (departmentId) {
      userFilter.employee = { departmentId: parseInt(departmentId) };
    }

    const roomWhere = {
      ...(Object.keys(dateFilter).length > 0 && { startDatetime: dateFilter }),
      ...(status && { status: status }),
      ...(Object.keys(userFilter).length > 0 && { user: userFilter }),
      ...(search && { purpose: { contains: search, mode: 'insensitive' } })
    };

    const vehicleWhere = {
      ...(Object.keys(dateFilter).length > 0 && { startDatetime: dateFilter }),
      ...(status && { status: status }),
      ...(Object.keys(userFilter).length > 0 && { user: userFilter }),
      ...(search && { destination: { contains: search, mode: 'insensitive' } })
    };

    let roomBookings = [];
    let vehicleBookings = [];

    if (!resourceType || resourceType.toUpperCase() === 'ROOM') {
      roomBookings = await prisma.roomBooking.findMany({
        where: roomWhere,
        include: {
          room: true,
          user: { include: { employee: { include: { department: true } } } }
        }
      });
    }

    if (!resourceType || resourceType.toUpperCase() === 'VEHICLE') {
      vehicleBookings = await prisma.vehicleBooking.findMany({
        where: vehicleWhere,
        include: {
          vehicle: true,
          user: { include: { employee: { include: { department: true } } } }
        }
      });
    }

    const formattedRooms = roomBookings.map(b => ({
      id: b.id,
      originalId: `R-${b.id}`,
      resourceType: 'ROOM',
      resourceName: b.room?.roomName || 'ไม่ระบุ',
      title: b.purpose,
      status: b.status,
      startDatetime: b.startDatetime,
      endDatetime: b.endDatetime,
      bookerName: b.user?.employee ? `${b.user.employee.firstName} ${b.user.employee.lastName}` : (b.user?.username || 'ไม่ทราบชื่อ'),
      departmentName: b.user?.employee?.department?.name || 'ไม่ระบุ'
    }));

    const formattedVehicles = vehicleBookings.map(b => ({
      id: b.id,
      originalId: `V-${b.id}`,
      resourceType: 'VEHICLE',
      resourceName: b.vehicle?.plateNumber || 'ไม่ระบุ',
      title: b.destination,
      status: b.status,
      startDatetime: b.startDatetime,
      endDatetime: b.endDatetime,
      bookerName: b.user?.employee ? `${b.user.employee.firstName} ${b.user.employee.lastName}` : (b.user?.username || 'ไม่ทราบชื่อ'),
      departmentName: b.user?.employee?.department?.name || 'ไม่ระบุ'
    }));

    let combinedBookings = [...formattedRooms, ...formattedVehicles];
    
    // เรียงวันที่จากใหม่ไปเก่า
    combinedBookings.sort((a, b) => new Date(b.startDatetime) - new Date(a.startDatetime));

    const totalItems = combinedBookings.length;
    const totalPages = Math.ceil(totalItems / limitNum);
    const paginatedData = combinedBookings.slice((pageNum - 1) * limitNum, pageNum * limitNum);

    return res.status(200).json({
      success: true,
      pagination: {
        page: pageNum,
        limit: limitNum,
        total: totalItems,
        totalPages: totalPages
      },
      data: paginatedData
    });

  } catch (error) {
    console.error('❌ Aggregated Search Error:', error);
    return res.status(500).json({ success: false, message: 'เกิดข้อผิดพลาดในการดึงข้อมูลรายงาน' });
  }
};

/**
 * 5. Dashboard Summary & Overview Stats API
 * GET /api/reports/dashboard-stats
 */
const getDashboardStats = async (req, res) => {
  try {
    const totalEmployees = await prisma.employee.count({ 
      where: { isActive: true } 
    });
    
    const totalVehicles = await prisma.vehicle.count({ 
      where: { isDeleted: false } 
    });
    
    const totalRooms = await prisma.room.count({ 
      where: { isDeleted: false } 
    });

    const vehicleStatusGroup = await prisma.vehicle.groupBy({
      by: ['status'],
      _count: { status: true },
      where: { isDeleted: false }
    });

    const vehicleOverview = {
      AVAILABLE: 0,
      IN_USE: 0,
      MAINTENANCE: 0,
      INACTIVE: 0,
      RESERVED: 0
    };

    vehicleStatusGroup.forEach(item => {
      const key = item.status === 'IN USE' ? 'IN_USE' : item.status;
      if (vehicleOverview.hasOwnProperty(key)) {
        vehicleOverview[key] = item._count.status;
      }
    });

    const roomBookingGroup = await prisma.roomBooking.groupBy({
      by: ['status'],
      _count: { status: true }
    });

    const vehicleBookingGroup = await prisma.vehicleBooking.groupBy({
      by: ['status'],
      _count: { status: true }
    });

    const defaultBookingStatus = {
      PENDING: 0,
      APPROVED: 0,
      IN_USE: 0,
      COMPLETED: 0,
      CANCELLED: 0,
      REJECTED: 0
    };

    const roomBookingOverview = { ...defaultBookingStatus };
    roomBookingGroup.forEach(item => {
      const key = item.status === 'IN USE' ? 'IN_USE' : item.status;
      if (roomBookingOverview.hasOwnProperty(key)) {
        roomBookingOverview[key] = item._count.status;
      }
    });

    const vehicleBookingOverview = { ...defaultBookingStatus };
    vehicleBookingGroup.forEach(item => {
      const key = item.status === 'IN USE' ? 'IN_USE' : item.status;
      if (vehicleBookingOverview.hasOwnProperty(key)) {
        vehicleBookingOverview[key] = item._count.status;
      }
    });

    const totalRoomBookings = Object.values(roomBookingOverview).reduce((a, b) => a + b, 0);
    const totalVehicleBookings = Object.values(vehicleBookingOverview).reduce((a, b) => a + b, 0);
    const totalBookings = totalRoomBookings + totalVehicleBookings;
    
    const totalPending = roomBookingOverview.PENDING + vehicleBookingOverview.PENDING;
    const totalApproved = roomBookingOverview.APPROVED + vehicleBookingOverview.APPROVED;
    const totalInUse = roomBookingOverview.IN_USE + vehicleBookingOverview.IN_USE;

    const recentRoomBookings = await prisma.roomBooking.findMany({
      take: 5,
      orderBy: { createdAt: 'desc' },
      include: {
        user: { include: { employee: true } },
        room: true
      }
    });

    const recentVehicleBookings = await prisma.vehicleBooking.findMany({
      take: 5,
      orderBy: { createdAt: 'desc' },
      include: {
        user: { include: { employee: true } },
        vehicle: true
      }
    });

    const formattedRecent = [
      ...recentRoomBookings.map(b => ({
        id: `ROOM_${b.id}`,
        bookerName: b.user?.employee?.fullName || 'ไม่ระบุชื่อ',
        type: 'ห้องประชุม',
        itemName: b.room?.roomName || 'ห้องประชุม',
        date: b.startDatetime,
        status: b.status === 'IN USE' ? 'IN_USE' : b.status,
        createdAt: b.createdAt
      })),
      ...recentVehicleBookings.map(b => ({
        id: `VEHICLE_${b.id}`,
        bookerName: b.user?.employee?.fullName || 'ไม่ระบุชื่อ',
        type: 'ยานพาหนะ',
        itemName: b.vehicle?.plateNumber 
          ? `${b.vehicle.vehicleName || b.vehicle.brand} (${b.vehicle.plateNumber})` 
          : (b.vehicle?.vehicleName || 'รถยนต์'),
        date: b.startDatetime,
        status: b.status === 'IN USE' ? 'IN_USE' : b.status,
        createdAt: b.createdAt
      }))
    ]
      .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
      .slice(0, 5);

    return res.status(200).json({
      success: true,
      data: {
        summary: {
          totalEmployees,
          totalVehicles,
          totalRooms,
          totalBookings,
          totalPending,
          totalApproved,
          totalInUse
        },
        vehicleOverview,
        bookingOverview: {
          room: roomBookingOverview,
          vehicle: vehicleBookingOverview
        },
        recentBookings: formattedRecent
      }
    });
  } catch (error) {
    console.error('Error fetching dashboard stats:', error);
    return res.status(500).json({ success: false, error: 'ไม่สามารถดึงข้อมูล Dashboard ได้' });
  }
};

module.exports = {
  // ... (export เดิมที่มีอยู่) ...
  getAdminDashboard,
  getUserDashboard,
  getSecurityDashboard,
  exportReport,
  getAggregatedBookings,
  getDashboardStats
};