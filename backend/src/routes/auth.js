const express = require('express');
const { PrismaClient } = require('@prisma/client');
const jwt = require('jsonwebtoken');
const { JWT_SECRET, authenticateToken } = require('../middlewares/auth');

const router = express.Router();
const prisma = new PrismaClient();

// 🚀 API Setup ข้อมูลตั้งต้น (ผมขอคอมเมนต์ปิดไว้นะครับ เพราะเราใช้ npx prisma db seed ไปแล้ว 56 คน!)
/* router.post('/setup', async (req, res) => {
  // ... โค้ดเดิม ...
});
*/

// 🔑 API Login (อัปเดตใหม่ให้ใช้ รหัสพนักงาน และแยกเงื่อนไขตามสิทธิ์)
router.post('/login', async (req, res) => {
  // 1. รับค่าที่เพื่อน Frontend จะส่งมาให้ (เปลี่ยนจาก email, pin เป็น employeeId, password)
  const { employeeId, password } = req.body; 

  try {
    if (!employeeId) return res.status(400).json({ error: "กรุณากรอกรหัสพนักงาน" });

    // 2. ค้นหาพนักงานจาก "รหัสพนักงาน"
    const user = await prisma.user.findUnique({ 
      where: { employeeId: employeeId }, 
      include: { role: true } 
    });

    if (!user) return res.status(404).json({ error: "ไม่พบรหัสพนักงานนี้ในระบบ" });

    // 3. 🚦 เช็กเงื่อนไข: แอดมินกับ รปภ. ต้องใส่รหัสผ่าน (ส่วนพนักงานทั่วไป ปล่อยผ่านไปข้อ 4 เลย)
    if (user.role.name === 'ADMIN' || user.role.name === 'GUARD') {
      if (!password) return res.status(400).json({ error: "สิทธิ์ระดับนี้ จำเป็นต้องใส่รหัสผ่าน" });
      
      // เช็กรหัสผ่าน (อิงจากตาราง User ที่เรา Seed ไว้)
      if (user.password !== password) {
        return res.status(401).json({ error: "รหัสผ่านไม่ถูกต้อง" });
      }
    }

    // 4. 🎟️ สร้าง Token (บัตรคิว)
    const token = jwt.sign(
      { userId: user.id, role: user.role.name, employeeId: user.employeeId }, 
      JWT_SECRET, 
      { expiresIn: '1d' }
    );
    
    // 5. ส่งกลับไปบอกเพื่อนหน้าบ้านว่าสำเร็จแล้ว!
    res.json({ 
      message: "เข้าสู่ระบบสำเร็จ", 
      token: token,
      role: user.role.name 
    });

  } catch (error) {
    console.error('Login Error:', error);
    res.status(500).json({ error: "ระบบขัดข้อง" });
  }
});

// 👤 API เช็กโปรไฟล์ของคนที่ถือ Token ปัจจุบัน (อัปเดตให้ส่งข้อมูลชุดใหม่)
router.get('/me', authenticateToken, async (req, res) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.userId },
      include: { role: true } 
    });
    
    if (!user) return res.status(404).json({ error: "ไม่พบข้อมูลผู้ใช้งานนี้" });
    
    // อัปเดตช่องข้อมูลให้ตรงกับ Schema ปัจจุบันของเรา (firstName, lastName)
    res.json({
      id: user.id,
      employeeId: user.employeeId,
      firstName: user.firstName,
      lastName: user.lastName,
      position: user.position,
      role: user.role.name
    });

  } catch (error) {
    console.error('Me Error:', error);
    res.status(500).json({ error: "ระบบไม่สามารถตรวจสอบ Token ได้" });
  }
});

module.exports = router;