const express = require('express');
const { PrismaClient } = require('@prisma/client');
const jwt = require('jsonwebtoken');
const { JWT_SECRET, authenticateToken } = require('../middlewares/auth');

const router = express.Router();
const prisma = new PrismaClient();

// 🚀 API Setup ข้อมูลตั้งต้น
router.post('/setup', async (req, res) => {
  try {
    const roleUser = await prisma.role.upsert({ where: { name: 'USER' }, update: {}, create: { name: 'USER' } });
    const roleAdmin = await prisma.role.upsert({ where: { name: 'ADMIN' }, update: {}, create: { name: 'ADMIN' } });
    const roleGuard = await prisma.role.upsert({ where: { name: 'GUARD' }, update: {}, create: { name: 'GUARD' } });

    await prisma.user.upsert({ where: { email: 'user@company.com' }, update: {}, create: { email: 'user@company.com', name: 'พนักงาน A', roleId: roleUser.id } });
    await prisma.user.upsert({ where: { email: 'admin@company.com' }, update: {}, create: { email: 'admin@company.com', name: 'หัวหน้า B', roleId: roleAdmin.id } });
    await prisma.user.upsert({ where: { email: 'guard@company.com' }, update: {}, create: { email: 'guard@company.com', name: 'รปภ. สมหมาย', roleId: roleGuard.id } });

    await prisma.pinAccess.createMany({
      data: [
        { roleId: roleAdmin.id, pinCode: '1234', isActive: true },
        { roleId: roleGuard.id, pinCode: '5678', isActive: true }
      ],
      skipDuplicates: true,
    });

    await prisma.vehicle.upsert({ where: { id: 1 }, update: {}, create: { id: 1, name: 'Toyota Camry (รถส่วนกลาง)', plateNumber: 'กข-1234' } });
    await prisma.room.upsert({ where: { id: 1 }, update: {}, create: { id: 1, name: 'Meeting Room A', capacity: 10 } });

    res.status(201).json({ message: "เสกข้อมูลตั้งต้นสำเร็จ!" });
  } catch (error) {
    res.status(500).json({ error: "เกิดข้อผิดพลาดในการ Setup" });
  }
});

// 🔑 API Login
router.post('/login', async (req, res) => {
  const { email, pin } = req.body;
  try {
    const user = await prisma.user.findUnique({ where: { email }, include: { role: true } });
    if (!user) return res.status(404).json({ error: "ไม่พบผู้ใช้งานนี้ในระบบ" });

    if (user.role.name === 'ADMIN' || user.role.name === 'GUARD') {
      if (!pin) return res.status(400).json({ error: "กรุณาใส่รหัส PIN" });
      const validPin = await prisma.pinAccess.findFirst({ where: { roleId: user.role.id, pinCode: pin, isActive: true } });
      if (!validPin) return res.status(401).json({ error: "รหัส PIN ไม่ถูกต้อง" });
    }

    const token = jwt.sign({ userId: user.id, role: user.role.name }, JWT_SECRET, { expiresIn: '1d' });
    res.json({ message: "เข้าสู่ระบบสำเร็จ", token });
  } catch (error) {
    res.status(500).json({ error: "ระบบขัดข้อง" });
  }
});

// 👤 API เช็กโปรไฟล์ของคนที่ถือ Token ปัจจุบัน (Frontend จำเป็นต้องใช้ตอนโหลดหน้าเว็บใหม่)
router.get('/me', authenticateToken, async (req, res) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.userId },
      include: { role: true } // ดึงชื่อสิทธิ์ (USER, ADMIN, GUARD) ไปให้หน้าบ้านเช็กด้วย
    });
    
    if (!user) return res.status(404).json({ error: "ไม่พบข้อมูลผู้ใช้งานนี้" });
    
    res.json({
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role.name
    });
  } catch (error) {
    res.status(500).json({ error: "ระบบไม่สามารถตรวจสอบ Token ได้" });
  }
});

module.exports = router;