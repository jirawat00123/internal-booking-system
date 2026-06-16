const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { authenticateToken } = require('../middlewares/auth');

const router = express.Router();
const prisma = new PrismaClient();

// 🏢 API: ดึงรายชื่อห้องประชุมทั้งหมด (เอาไปทำ Dropdown เลือกห้อง)
router.get('/rooms', authenticateToken, async (req, res) => {
  try {
    const rooms = await prisma.room.findMany();
    res.json(rooms);
  } catch (error) {
    res.status(500).json({ error: "ไม่สามารถดึงข้อมูลห้องประชุมได้" });
  }
});

// 🚗 API: ดึงรายชื่อรถยนต์ทั้งหมด (เอาไปทำ Dropdown เลือกรถ)
router.get('/vehicles', authenticateToken, async (req, res) => {
  try {
    const vehicles = await prisma.vehicle.findMany();
    res.json(vehicles);
  } catch (error) {
    res.status(500).json({ error: "ไม่สามารถดึงข้อมูลรถยนต์ได้" });
  }
});

module.exports = router;