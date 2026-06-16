const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { authenticateToken } = require('../middlewares/auth');

const router = express.Router();
const prisma = new PrismaClient();

// ==========================================
// 🏢 ส่วนของห้องประชุม (ROOM BOOKING)
// ==========================================

// 1. จองห้องประชุม (อัปเกรด: เช็กคิวซ้ำ + ป้องกันข้อมูลว่าง)
router.post('/room', authenticateToken, async (req, res) => {
  const { roomId, startTime, endTime } = req.body;
  const userId = req.user.userId;

  // เช็กว่าส่งข้อมูลมาครบไหม
  if (!roomId || !startTime || !endTime) {
    return res.status(400).json({ error: "ข้อมูลไม่ครบถ้วน กรุณาระบุห้องและเวลาให้ชัดเจน" });
  }

  try {
    // เช็กเวลาทับซ้อน (Conflict Prevention)
    const isConflict = await prisma.roomBooking.findFirst({
      where: {
        roomId: parseInt(roomId),
        AND: [
          { startTime: { lt: new Date(endTime) } },
          { endTime: { gt: new Date(startTime) } }
        ]
      }
    });

    if (isConflict) {
      return res.status(400).json({ error: "เสียใจด้วยครับ ห้องประชุมนี้มีคนจองในช่วงเวลานี้ไปแล้ว 😭" });
    }

    const booking = await prisma.roomBooking.create({
      data: { roomId: parseInt(roomId), userId: userId, startTime: new Date(startTime), endTime: new Date(endTime) }
    });
    res.status(201).json({ message: "จองห้องประชุมสำเร็จ! 🎉", booking });
  } catch (error) {
    res.status(500).json({ error: "เกิดข้อผิดพลาดในการจองห้องประชุม" });
  }
});

// 2. ดึงประวัติการจองห้องประชุม (แยกสิทธิ์)
router.get('/room', authenticateToken, async (req, res) => {
  try {
    const userRole = req.user.role;
    const userId = req.user.userId;
    const whereCondition = (userRole === 'ADMIN' || userRole === 'GUARD') ? {} : { userId: userId };

    const bookings = await prisma.roomBooking.findMany({
      where: whereCondition,
      include: {
        room: true,
        user: { select: { id: true, name: true, email: true } }
      },
      orderBy: { startTime: 'desc' }
    });
    res.json(bookings);
  } catch (error) {
    res.status(500).json({ error: "ดึงข้อมูลประวัติห้องประชุมล้มเหลว" });
  }
});


// ==========================================
// 🚗 ส่วนของรถยนต์บริษัท (VEHICLE BOOKING)
// ==========================================

// 3. จองรถบริษัท (มีระบบเช็กคิวซ้ำ)
router.post('/vehicle', authenticateToken, async (req, res) => {
  const { vehicleId, startTime, endTime } = req.body;
  const userId = req.user.userId;
  try {
    const isConflict = await prisma.vehicleBooking.findFirst({
      where: {
        vehicleId: parseInt(vehicleId),
        status: { not: 'REJECTED' },
        AND: [
          { startTime: { lt: new Date(endTime) } },
          { endTime: { gt: new Date(startTime) } }
        ]
      }
    });

    if (isConflict) {
      return res.status(400).json({ error: "เสียใจด้วยครับ รถคันนี้มีคนจองในช่วงเวลานี้ไปแล้ว 😭" });
    }

    const booking = await prisma.vehicleBooking.create({
      data: { vehicleId: parseInt(vehicleId), userId: userId, startTime: new Date(startTime), endTime: new Date(endTime) }
    });
    res.status(201).json({ message: "จองรถบริษัทสำเร็จ! 🚗", booking });
  } catch (error) {
    res.status(500).json({ error: "เกิดข้อผิดพลาดในการจองรถ" });
  }
});

// 4. ดึงประวัติการจองรถ (แยกสิทธิ์พนักงาน/แอดมิน)
// 📖 ดึงประวัติการจองรถ (อัปเกรด: มีระบบแบ่งหน้าและตัวกรองสถานะ)
router.get('/vehicle', authenticateToken, async (req, res) => {
  try {
    const userRole = req.user.role;
    const userId = req.user.userId;
    
    // 1. รับค่าจาก Query String (เช่น ?page=1&limit=5&status=PENDING)
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const skip = (page - 1) * limit;
    const statusFilter = req.query.status; 

    // 2. สร้างเงื่อนไขการค้นหา
    let whereCondition = (userRole === 'ADMIN' || userRole === 'GUARD') ? {} : { userId: userId };
    if (statusFilter) {
      whereCondition.status = statusFilter; // ถ้าส่ง status มา ให้กรองตามนั้น
    }

    // 3. ค้นหาข้อมูล + นับจำนวนทั้งหมดพร้อมกัน (เพื่อเอาไปทำเลขหน้า)
    const [bookings, total] = await Promise.all([
      prisma.vehicleBooking.findMany({
        where: whereCondition,
        include: { vehicle: true, user: { select: { id: true, name: true, email: true } } },
        orderBy: { startTime: 'desc' },
        skip: skip,
        take: limit, // ดึงไปแค่จำนวน limit (เช่น 10 รายการ) ป้องกันเบราว์เซอร์ค้าง
      }),
      prisma.vehicleBooking.count({ where: whereCondition }) // นับจำนวนทั้งหมดที่ตรงเงื่อนไข
    ]);

    // 4. ส่งกลับไปแบบมีโครงสร้างมาตรฐาน
    res.json({
      success: true,
      data: bookings,
      meta: { 
        total: total, 
        currentPage: page, 
        limit: limit, 
        totalPages: Math.ceil(total / limit) 
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: "ดึงข้อมูลล้มเหลว" });
  }
});

// 5. รปภ. อัปเดตเลขไมล์
router.put('/vehicle/:id/mileage', authenticateToken, async (req, res) => {
  const bookingId = req.params.id;
  const { startMileage, endMileage, status } = req.body;

  if (req.user.role !== 'GUARD' && req.user.role !== 'ADMIN') {
    return res.status(403).json({ error: "ไม่มีสิทธิ์เข้าถึงฟังก์ชันของ รปภ." });
  }

  try {
    const updatedBooking = await prisma.vehicleBooking.update({
      where: { id: parseInt(bookingId) },
      data: {
        startMileage: startMileage ? parseInt(startMileage) : undefined,
        endMileage: endMileage ? parseInt(endMileage) : undefined,
        status: status
      }
    });
    await prisma.vehicleLog.create({
      data: { bookingId: updatedBooking.id, action: `UPDATED_MILEAGE_${status || 'NO_STATUS'}` }
    });
    res.json({ message: "อัปเดตข้อมูลการเดินรถเรียบร้อย 🫡", booking: updatedBooking });
  } catch (error) {
    res.status(500).json({ error: "อัปเดตข้อมูลล้มเหลว" });
  }
});

// 6. Admin อนุมัติใบจองรถ
router.put('/vehicle/:id/approve', authenticateToken, async (req, res) => {
  const bookingId = req.params.id;
  const { status } = req.body;

  if (req.user.role !== 'ADMIN') {
    return res.status(403).json({ error: "เฉพาะระดับหัวหน้า (ADMIN) เท่านั้นที่อนุมัติได้ 🛑" });
  }

  try {
    const updatedBooking = await prisma.vehicleBooking.update({
      where: { id: parseInt(bookingId) },
      data: { status: status }
    });
    res.json({ message: `จัดการคำขอจองสำเร็จ (สถานะ: ${status}) 👑`, booking: updatedBooking });
  } catch (error) {
    res.status(500).json({ error: "อัปเดตสถานะล้มเหลว" });
  }
});

// ❌ ยกเลิกการจองห้องประชุม
router.delete('/room/:id', authenticateToken, async (req, res) => {
  const bookingId = parseInt(req.params.id);
  try {
    const booking = await prisma.roomBooking.findUnique({ where: { id: bookingId } });
    if (!booking) return res.status(404).json({ error: "ไม่พบข้อมูลการจองนี้" });

    // ป้องกันสิทธิ์: ต้องเป็นเจ้าของใบจอง หรือเป็น ADMIN เท่านั้นถึงจะลบได้
    if (booking.userId !== req.user.userId && req.user.role !== 'ADMIN') {
      return res.status(403).json({ error: "คุณไม่มีสิทธิ์ยกเลิกใบจองของผู้อื่น" });
    }

    await prisma.roomBooking.delete({ where: { id: bookingId } });
    res.json({ message: "ยกเลิกการจองห้องประชุมเรียบร้อยแล้ว 🗑️" });
  } catch (error) {
    res.status(500).json({ error: "ไม่สามารถยกเลิกการจองได้" });
  }
});

// ❌ ยกเลิกการจองรถยนต์
router.delete('/vehicle/:id', authenticateToken, async (req, res) => {
  const bookingId = parseInt(req.params.id);
  try {
    const booking = await prisma.vehicleBooking.findUnique({ where: { id: bookingId } });
    if (!booking) return res.status(404).json({ error: "ไม่พบข้อมูลการจองนี้" });

    if (booking.userId !== req.user.userId && req.user.role !== 'ADMIN') {
      return res.status(403).json({ error: "คุณไม่มีสิทธิ์ยกเลิกใบจองของผู้อื่น" });
    }

    await prisma.vehicleBooking.delete({ where: { id: bookingId } });
    res.json({ message: "ยกเลิกการจองรถยนต์เรียบร้อยแล้ว 🗑️" });
  } catch (error) {
    res.status(500).json({ error: "ไม่สามารถยกเลิกการจองได้" });
  }
});

module.exports = router;