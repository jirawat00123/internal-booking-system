const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { authenticateToken } = require('../middlewares/auth');

const router = express.Router();
const prisma = new PrismaClient();

// 🚗 [GET] /api/bookings - ดึงรายการจองทั้งหมด (ผสานโครงสร้างพื้นฐานและระบบความปลอดภัย)
router.get('/', authenticateToken, async (req, res) => {
  try {
    // โค้ดดึงข้อมูลการจองจากฐานข้อมูล (Prisma) จะเขียนตรงนี้ในอนาคต
    res.json({
      success: true,
      message: "ดึงข้อมูลรายการจองสำเร็จ (Booking API is ready to use!)",
      bookings: []
    });
  } catch (error) {
    console.error('Get Bookings Error:', error);
    res.status(500).json({ error: "ระบบดึงข้อมูลการจองขัดข้อง" });
  }
});

// 🚨 สิ่งสำคัญที่สุด: ต้อง Export ตัว router นี้ออกไปให้ index.js เรียกใช้ได้
module.exports = router;