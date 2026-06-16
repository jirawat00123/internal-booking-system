const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { authenticateToken } = require('../middlewares/auth');

const router = express.Router();
const prisma = new PrismaClient();

// =============================================================
// 🏢 1. โซนจัดการข้อมูลห้องประชุม (Rooms)
// =============================================================

// 🏢 API: ดึงรายชื่อห้องประชุมทั้งหมด (สิทธิ์ไหนก็ดูได้เอาไปทำ Dropdown)
router.get('/rooms', authenticateToken, async (req, res, next) => {
  try {
    const rooms = await prisma.room.findMany({
      orderBy: { id: 'asc' }
    });
    res.json(rooms);
  } catch (error) {
    // 🛡️ โยนไปให้ Middleware ส่วนกลางใน index.js ช่วยจัดการและแจ้งเตือนเพื่อนหน้าบ้าน
    next(error); 
  }
});


// =============================================================
// 🚗 2. โซนจัดการข้อมูลรถยนต์บริษัท (Vehicles) - ล็อกสิทธิ์ ADMIN
// =============================================================

// 🚗 API: ดึงรายชื่อรถยนต์ทั้งหมด (สิทธิ์ไหนก็ดูได้เอาไปทำหน้าจอเลือกรถ)
router.get('/vehicles', authenticateToken, async (req, res, next) => {
  try {
    const vehicles = await prisma.vehicle.findMany({
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
    // 🚦 ด่านตรวจสิทธิ์: ถ้าไม่ใช่แอดมิน ส่ง 403 Forbidden กลับทันที
    if (req.user.role !== 'ADMIN') {
      return res.status(403).json({ error: "ไม่มีสิทธิ์เข้าถึง: ฟังก์ชันนี้สำหรับผู้ดูแลระบบ (ADMIN) เท่านั้น" });
    }

    const { brand, model, type, plateNumber, province, color, imageUrl } = req.body;

    // ตรวจสอบว่าหน้าบ้านส่งข้อมูลสำคัญมาครบถ้วนไหม
    if (!brand || !model || !type || !plateNumber || !province || !color) {
      return res.status(400).json({ error: "กรุณากรอกข้อมูลรถให้ครบถ้วน (ยี่ห้อ, รุ่น, ประเภท, ทะเบียน, จังหวัด, สี)" });
    }

    const newVehicle = await prisma.vehicle.create({
      data: {
        brand,
        model,
        type,
        plateNumber,
        province,
        color,
        imageUrl: imageUrl || null // ถ้าหน้าบ้านไม่มีรูปส่งมา ให้บันทึกเป็น null ไว้ก่อน
      }
    });

    res.status(201).json({ message: "เพิ่มรถคันใหม่เข้าสู่ระบบสำเร็จเรียบร้อย!", data: newVehicle });
  } catch (error) {
    next(error);
  }
});

// ✏️ API: แก้ไขข้อมูลรถยนต์ (🔒 เฉพาะ ADMIN เท่านั้น)
router.put('/vehicles/:id', authenticateToken, async (req, res, next) => {
  try {
    // 🚦 ด่านตรวจสิทธิ์: ถ้าไม่ใช่แอดมิน ส่ง 403 Forbidden กลับทันที
    if (req.user.role !== 'ADMIN') {
      return res.status(403).json({ error: "ไม่มีสิทธิ์เข้าถึง: เฉพาะแอดมินเท่านั้นที่แก้ไขข้อมูลได้" });
    }

    const vehicleId = parseInt(req.params.id); // ดึง ID รถจาก URL เช่น /api/resources/vehicles/5
    const { brand, model, type, plateNumber, province, color, imageUrl } = req.body;

    const updatedVehicle = await prisma.vehicle.update({
      where: { id: vehicleId },
      data: { brand, model, type, plateNumber, province, color, imageUrl }
    });

    res.json({ message: "อัปเดตข้อมูลรถเรียบร้อยแล้ว!", data: updatedVehicle });
  } catch (error) {
    next(error);
  }
});

// ❌ API: ลบรถออกจากระบบ (🔒 เฉพาะ ADMIN เท่านั้น)
router.delete('/vehicles/:id', authenticateToken, async (req, res, next) => {
  try {
    // 🚦 ด่านตรวจสิทธิ์: ถ้าไม่ใช่แอดมิน ส่ง 403 Forbidden กลับทันที
    if (req.user.role !== 'ADMIN') {
      return res.status(403).json({ error: "ไม่มีสิทธิ์เข้าถึง: เฉพาะแอดมินเท่านั้นที่ลบข้อมูลได้" });
    }

    const vehicleId = parseInt(req.params.id);

    await prisma.vehicle.delete({
      where: { id: vehicleId }
    });

    res.json({ message: "ลบรถออกจากระบบสำเร็จเรียบร้อยแล้ว!" });
  } catch (error) {
    next(error);
  }
});

module.exports = router;