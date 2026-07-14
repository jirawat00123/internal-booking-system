// src/routes/resources.js
const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { authenticateToken } = require('../middlewares/auth');

const router = express.Router();
const prisma = new PrismaClient();

// =============================================================
// 🏢 1. โซนจัดการข้อมูลห้องประชุม (Rooms Resource)
// =============================================================

router.get('/rooms', authenticateToken, async (req, res, next) => {
  try {
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

router.get('/vehicles', authenticateToken, async (req, res, next) => {
  try {
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