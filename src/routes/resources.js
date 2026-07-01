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
    // 💡 แก้ไขบัก: ใช้ prisma.rooms ตามฝั่ง HEAD
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
    // 💡 แก้ไขบัก: ใช้ prisma.vehicles
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

    // 💡 ผสานฟิลด์ข้อมูล: นำฟิลด์จากฝั่ง dev (type, province, color) มารวมกับฝั่ง HEAD
    const { brand, model, type, licensePlate, plateNumber, province, color, uploadUrl } = req.body;

    // รองรับทั้งชื่อตัวแปรจากฝั่ง HEAD (licensePlate) และฝั่ง dev (plateNumber) จาก Frontend
    const finalPlate = licensePlate || plateNumber;

    if (!brand || !model || !finalPlate || !type || !province || !color) {
      return res.status(400).json({ error: "กรุณากรอกข้อมูลรถให้ครบถ้วน (brand, model, type, ทะเบียนรถ, province, color)" });
    }

    const newVehicle = await prisma.vehicles.create({
      data: {
        brand,
        model,
        type,                  // เพิ่มมาจากฝั่ง dev
        licensePlate: finalPlate, // อิงตามชื่อฟิลด์แผนผัง DB จริงจากฝั่ง HEAD
        province,              // เพิ่มมาจากฝั่ง dev
        color,                 // เพิ่มมาจากฝั่ง dev
        uploadUrl: uploadUrl || null,
        status: "available"    // ค่าเริ่มต้นจากฝั่ง HEAD
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
    const { brand, model, type, licensePlate, plateNumber, province, color, status, uploadUrl } = req.body;
    
    const finalPlate = licensePlate || plateNumber;

    const updatedVehicle = await prisma.vehicles.update({
      where: { id: vehicleId },
      data: { 
        brand, 
        model, 
        type, 
        licensePlate: finalPlate, 
        province, 
        color, 
        status, 
        uploadUrl 
      }
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