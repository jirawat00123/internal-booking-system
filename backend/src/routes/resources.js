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
    // 💡 แก้ไขบั๊ก: เปลี่ยนจาก prisma.rooms เป็น prisma.room ให้ตรงตามโมเดลจริงใน Schema
    const rooms = await prisma.room.findMany({
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

// 🚗 API: ดึงรายชื่อรถยนต์ทั้งหมด (ดึงเฉพาะคันที่ยังไม่ถูกลบ)
router.get('/vehicles', authenticateToken, async (req, res, next) => {
  try {
    // 💡 แก้ไขบั๊ก: เปลี่ยนเป็น prisma.vehicle และ Optimize ให้กรองตัวที่ลบออกไปแล้ว
    const vehicles = await prisma.vehicle.findMany({
      where: {
        isDeleted: false
      },
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

    // 💡 ลบฟิลด์ที่ไม่มีใน Schema ออก (type, province, color) และดึงฟิลด์ที่มีจริงมาใช้งาน (seats)
    const { brand, model, licensePlate, plateNumber, seats, uploadUrl } = req.body;

    // รองรับการส่งชื่อฟิลด์ทะเบียนรถจากทั้ง frontend สองฝั่งมารวมกันที่ฟิลด์จริง
    const finalPlate = plateNumber || licensePlate;

    if (!brand || !model || !finalPlate) {
      return res.status(400).json({ error: "กรุณากรอกข้อมูลรถให้ครบถ้วน (brand, model, ทะเบียนรถ [plateNumber])" });
    }

    // 💡 แก้ไขบั๊ก: บันทึกข้อมูลเข้า prisma.vehicle โดยใช้ฟิลด์ที่แมปตรงกับฐานข้อมูลจริง
    const newVehicle = await prisma.vehicle.create({
      data: {
        brand,
        model,
        plateNumber: finalPlate,
        seats: seats ? parseInt(seats) : 4, // ถ้าไม่ได้ส่งมาให้เป็นค่าเริ่มต้น 4 ที่นั่งตาม Schema
        uploadUrl: uploadUrl || null,
        status: "AVAILABLE" // ใช้ ENUM ตัวพิมพ์ใหญ่ให้ตรงตามระบบ Database
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
    const { brand, model, licensePlate, plateNumber, seats, status, uploadUrl } = req.body;
    
    const finalPlate = plateNumber || licensePlate;

    // 💡 แก้ไขบั๊กและ Optimize: อัปเดตผ่าน prisma.vehicle ด้วยฟิลด์ข้อมูลที่ถูกต้องและปลอดภัย
    const updatedVehicle = await prisma.vehicle.update({
      where: { id: vehicleId },
      data: { 
        brand, 
        model, 
        plateNumber: finalPlate, 
        seats: seats ? parseInt(seats) : undefined,
        status: status ? status.toUpperCase() : undefined, // แปลงเป็นตัวพิมพ์ใหญ่ให้ตรงตาม ENUM
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

    // 💡 Optimize: เปลี่ยนจากการลบแบบถาวร (Hard Delete) เป็นการทำ Soft Delete 
    // โดยเปลี่ยนสถานะ flag isDeleted เป็น true เพื่อไม่ให้ประวัติการจองรถในตารางอื่นพัง
    await prisma.vehicle.update({
      where: { id: vehicleId },
      data: { isDeleted: true }
    });

    res.json({ success: true, message: "ลบรถออกจากระบบสำเร็จเรียบร้อยแล้ว!" });
  } catch (error) {
    next(error);
  }
});

module.exports = router;