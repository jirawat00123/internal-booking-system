const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// ==========================================
// 📺 1. ดึงข้อมูลสถานะห้องประชุมทั้งหมด (GET /monitor/rooms)
// ==========================================
exports.getRooms = async (req, res) => {
  try {
    const rooms = await prisma.room.findMany({
      where: { active: true },
      include: {
        // ดึงการจองของวันนี้ที่กำลังใช้งานอยู่มาแสดงด้วย
        bookings: {
          where: {
            status: { in: ['APPROVED', 'IN_PROGRESS'] },
            startTime: { gte: new Date(new Date().setHours(0,0,0,0)) }
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
    const vehicles = await prisma.vehicle.findMany({
      where: { active: true },
      include: {
        bookings: {
          where: {
            status: { in: ['APPROVED', 'IN_PROGRESS'] },
            startTime: { gte: new Date(new Date().setHours(0,0,0,0)) }
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

    const bookings = await prisma.booking.findMany({
      where: {
        startTime: { gte: today },
        status: { in: ['APPROVED', 'IN_PROGRESS'] }
      },
      include: {
        room: true,
        vehicle: true,
        user: { include: { employee: true } }
      },
      orderBy: { startTime: 'asc' }
    });
    return res.status(200).json({ success: true, data: bookings });
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
    const history = await prisma.booking.findMany({
      where: {
        status: { in: ['COMPLETED', 'CANCELLED', 'REJECTED'] }
      },
      include: {
        room: true,
        vehicle: true,
        user: { include: { employee: true } }
      },
      orderBy: { updatedAt: 'desc' },
      take: 50 // จำกัดแค่ 50 รายการล่าสุดเพื่อไม่ให้หน้าจอมอนิเตอร์โหลดหนักเกินไป
    });
    return res.status(200).json({ success: true, data: history });
  } catch (error) {
    console.error('Monitor History Error:', error);
    return res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลประวัติได้" });
  }
};