const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { authenticateToken } = require('../middlewares/auth');

const router = express.Router();
const prisma = new PrismaClient();

// =============================================================
// 🏢 1. โซนจัดการข้อมูลห้องประชุม (Rooms)
// =============================================================

// 🏢 API: ดึงรายชื่อห้องประชุมทั้งหมด
router.get('/rooms', authenticateToken, async (req, res, next) => {
  try {
    // 💡 แก้ไขบัก: เปลี่ยนจาก prisma.room เป็น prisma.rooms (Prisma Generator ใช้พหูพจน์ตามแผนผังตาราง)
    const rooms = await prisma.rooms.findMany({
      orderBy: { id: 'asc' }
    });
    res.json(rooms);
  } catch (error) {
    next(error); 
  }
});


// =============================================================
// 🚗 2. โซนจัดการข้อมูลรถยนต์บริษัท (Vehicles) - ล็อกสิทธิ์ ADMIN
// =============================================================

// 🚗 API: ดึงรายชื่อรถยนต์ทั้งหมด
router.get('/vehicles', authenticateToken, async (req, res, next) => {
  try {
    // 💡 แก้ไขบัก: เปลี่ยนจาก prisma.vehicle เป็น prisma.vehicles
    const vehicles = await prisma.vehicles.findMany({
      orderBy: { id: 'asc' }
    });
    res.json(vehicles);
  } catch (error) {
    next(error);
  }
});

// ➕ API: เพิ่มรถคันใหม่เข้าระบบ (🔒 เฉพาะ ADMIN เท่านั้น)
router.post('/vehicles', authenticateToken, async (req, res, next) => {
  try {
    if (req.user.role !== 'ADMIN') {
      return res.status(403).json({ error: "ไม่มีสิทธิ์เข้าถึง: ฟังก์ชันนี้สำหรับผู้ดูแลระบบ (ADMIN) เท่านั้น" });
    }

    // 💡 แก้ไขบัก: อ้างอิงตามแผนผัง DB ฟิลด์ในตารางคือ licensePlate, uploadUrl, brand, model, status
    const { brand, model, licensePlate, uploadUrl } = req.body;

    if (!brand || !model || !licensePlate) {
      return res.status(400).json({ error: "กรุณากรอกข้อมูลรถให้ครบถ้วน (brand, model, licensePlate)" });
    }

    const newVehicle = await prisma.vehicles.create({
      data: {
        brand,
        model,
        licensePlate, // ใช้ชื่อฟิลด์ตามแผนผังดาต้าเบสจริง
        uploadUrl: uploadUrl || null,
        status: "available" // เพิ่มค่าเริ่มต้นของสถานะรถยนต์
      }
    });

    res.status(201).json({ success: true, message: "เพิ่มรถคันใหม่เข้าสู่ระบบสำเร็จเรียบร้อย!", data: newVehicle });
  } catch (error) {
    next(error);
  }
});

// ✏️ API: แก้ไขข้อมูลรถยนต์ (🔒 เฉพาะ ADMIN เท่านั้น)
router.put('/vehicles/:id', authenticateToken, async (req, res, next) => {
  try {
    if (req.user.role !== 'ADMIN') {
      return res.status(403).json({ error: "ไม่มีสิทธิ์เข้าถึง: เฉพาะแอดมินเท่านั้นที่แก้ไขข้อมูลได้" });
    }

    const vehicleId = parseInt(req.params.id); 
    const { brand, model, licensePlate, status, uploadUrl } = req.body;

    const updatedVehicle = await prisma.vehicles.update({
      where: { id: vehicleId },
      data: { brand, model, licensePlate, status, uploadUrl }
    });

    res.json({ success: true, message: "อัปเดตข้อมูลรถเรียบร้อยแล้ว!", data: updatedVehicle });
  } catch (error) {
    next(error);
  }
});

// ❌ API: ลบรถออกจากระบบ (🔒 เฉพาะ ADMIN เท่านั้น)
router.delete('/vehicles/:id', authenticateToken, async (req, res, next) => {
  try {
    if (req.user.role !== 'ADMIN') {
      return res.status(403).json({ error: "ไม่มีสิทธิ์เข้าถึง: เฉพาะแอดมินเท่านั้นที่ลบข้อมูลได้" });
    }

    const vehicleId = parseInt(req.params.id);

    await prisma.vehicles.delete({
      where: { id: vehicleId }
    });

    res.json({ success: true, message: "ลบรถออกจากระบบสำเร็จเรียบร้อยแล้ว!" });
  } catch (error) {
    next(error);
  }
});

module.exports = router;