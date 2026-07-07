// src/routes/resources.js
const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { authenticateToken } = require('../middlewares/auth');

const router = express.Router();
const prisma = new PrismaClient();

// =============================================================
// 🏢 1. โซนจัดการข้อมูลห้องประชุม (Rooms Resource)
// =============================================================

// 🏢 API ข้อ 5: ดึงรายชื่อห้องประชุมทั้งหมด (สำหรับหน้าจอตัวเลือกฟอร์มใส่ Dropdown)
router.get('/rooms', authenticateToken, async (req, res, next) => {
  try {
    // แก้ไขบั๊ก: เรียกใช้งานผ่าน prisma.room ให้ตรงตามโมเดลหลักในระบบฐานข้อมูล Schema
    const rooms = await prisma.room.findMany({
      orderBy: { id: 'asc' }
    });
    return res.json(rooms);
  } catch (error) {
    next(error); 
  }
});

// =============================================================
// 🚗 2. โซนจัดการข้อมูลรถยนต์บริษัท (Vehicles Resource)
// =============================================================

// 🚗 API ข้อ 12: ดึงรายชื่อรถยนต์ทั้งหมด (สำหรับหน้าจอตัวเลือกฟอร์มใส่ Dropdown)
router.get('/vehicles', authenticateToken, async (req, res, next) => {
  try {
    // Optimize: ดึงเฉพาะคันที่ยังไม่ถูกลบ และมีสถานะพร้อมใช้งาน (AVAILABLE) 
    // พร้อมดึงเฉพาะฟิลด์ที่จำเป็นในการทำ Dropdown เพื่อเพิ่มความเร็วในการโหลดข้อมูล
    const vehicles = await prisma.vehicle.findMany({
      where: {
        isDeleted: false,
        status: "AVAILABLE"
      },
      select: {
        id: true,
        plateNumber: true,
        brand: true,
        model: true,
        seats: true
      },
      orderBy: { id: 'asc' }
    });
    return res.json(vehicles);
  } catch (error) {
    next(error);
  }
});

module.exports = router;