const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// ==========================================
// 📺 1. ดึงข้อมูลสถานะห้องประชุมทั้งหมด (GET /monitor/rooms)
// ==========================================
exports.getRooms = async (req, res) => {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const rooms = await prisma.room.findMany({
      where: { status: { not: 'MAINTENANCE' } }, // ปรับให้ดึงห้องที่ไม่ได้ปิดปรับปรุง
      include: {
        // 🟢 เปลี่ยนจาก bookings เป็น roomBookings ตาม Schema ใหม่
        roomBookings: {
          where: {
            status: { in: ['APPROVED', 'IN_PROGRESS', 'PENDING'] },
            startDatetime: { gte: today } // 🟢 เปลี่ยนจาก startTime เป็น startDatetime
          }
        }
      }
    });
    return res.status(200).json({ success: true, data: rooms });
  } catch (error) {
    console.error('Monitor Rooms Error:', error);
    return res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลห้องประชุมได้" });
  }
};

// ==========================================
// 🚗 2. ดึงข้อมูลสถานะรถยนต์ทั้งหมด (GET /monitor/vehicles)
// ==========================================
exports.getVehicles = async (req, res) => {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const vehicles = await prisma.vehicle.findMany({
      where: { status: { not: 'MAINTENANCE' } },
      include: {
        // 🟢 เปลี่ยนจาก bookings เป็น vehicleBookings ตาม Schema ใหม่
        vehicleBookings: {
          where: {
            status: { in: ['APPROVED', 'IN_PROGRESS', 'PENDING'] },
            startDatetime: { gte: today } // 🟢 เปลี่ยนจาก startTime เป็น startDatetime
          }
        }
      }
    });
    return res.status(200).json({ success: true, data: vehicles });
  } catch (error) {
    console.error('Monitor Vehicles Error:', error);
    return res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลรถยนต์ได้" });
  }
};

// ==========================================
// 📅 3. ดึงรายการจองที่กำลังใช้งาน/รอใช้งานของวันนี้ (GET /monitor/bookings)
// ==========================================
exports.getActiveBookings = async (req, res) => {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    // 🟢 ดึงข้อมูลแยกจาก 2 ตาราง (RoomBooking และ VehicleBooking)
    const [roomBookings, vehicleBookings] = await Promise.all([
      prisma.roomBooking.findMany({
        where: {
          startDatetime: { gte: today },
          status: { in: ['APPROVED', 'IN_PROGRESS', 'PENDING'] }
        },
        include: {
          room: true,
          user: { include: { employee: true } }
        },
        orderBy: { startDatetime: 'asc' }
      }),
      prisma.vehicleBooking.findMany({
        where: {
          startDatetime: { gte: today },
          status: { in: ['APPROVED', 'IN_PROGRESS', 'PENDING'] }
        },
        include: {
          vehicle: true,
          user: { include: { employee: true } }
        },
        orderBy: { startDatetime: 'asc' }
      })
    ]);

    // 🟢 นำข้อมูลทั้ง 2 ประเภทมารวมกันและเรียงลำดับตามเวลาอีกครั้ง
    const combinedBookings = [...roomBookings, ...vehicleBookings].sort(
      (a, b) => new Date(a.startDatetime) - new Date(b.startDatetime)
    );

    return res.status(200).json({ success: true, data: combinedBookings });
  } catch (error) {
    console.error('Monitor Bookings Error:', error);
    return res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลการจองได้" });
  }
};

// ==========================================
// 🕰️ 4. ดึงประวัติการจองย้อนหลัง (GET /monitor/history)
// ==========================================
exports.getHistory = async (req, res) => {
  try {
    // 🟢 ดึงประวัติแยกจาก 2 ตาราง (RoomBooking และ VehicleBooking)
    const [roomHistory, vehicleHistory] = await Promise.all([
      prisma.roomBooking.findMany({
        where: { status: { in: ['COMPLETED', 'CANCELLED', 'REJECTED'] } },
        include: {
          room: true,
          user: { include: { employee: true } }
        },
        orderBy: { updatedAt: 'desc' },
        take: 25 // แบ่งดึงอย่างละ 25 รายการ
      }),
      prisma.vehicleBooking.findMany({
        where: { status: { in: ['COMPLETED', 'CANCELLED', 'REJECTED'] } },
        include: {
          vehicle: true,
          user: { include: { employee: true } }
        },
        orderBy: { updatedAt: 'desc' },
        take: 25
      })
    ]);

    const combinedHistory = [...roomHistory, ...vehicleHistory].sort(
      (a, b) => new Date(b.updatedAt) - new Date(a.updatedAt)
    );

    return res.status(200).json({ success: true, data: combinedHistory });
  } catch (error) {
    console.error('Monitor History Error:', error);
    return res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลประวัติได้" });
  }
};