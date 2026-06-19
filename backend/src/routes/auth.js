const express = require('express');
const { PrismaClient } = require('@prisma/client');
const jwt = require('jsonwebtoken');
const { JWT_SECRET, authenticateToken } = require('../middlewares/auth');

const router = express.Router();
const prisma = new PrismaClient();

// 🔑 API Login (ปรับปรุงให้รองรับโครงสร้างตารางใหม่และการเชื่อมข้อมูลพนักงาน)
router.post('/login', async (req, res) => {
  // 1. เปลี่ยนมารับค่า employeeCode ตามที่ระบุไว้ในแบบแปลนและหน้าปก Swagger
  const { employeeCode } = req.body; 

  try {
    if (!employeeCode) {
      return res.status(400).json({ error: "กรุณากรอกรหัสพนักงาน" });
    }

    // 2. ค้นหาพนักงานจาก "รหัสพนักงาน (employeeCode)" ก่อนเพื่อเอา id ไปหา User
    const employee = await prisma.employee.findUnique({
      where: { employeeCode: employeeCode },
      include: {
        // ดึงข้อมูลบัญชีผู้ใช้ (user) และตำแหน่งพนักงานพ่วงมาด้วย
        user: true,
        position: true
      }
    });

    // ถ้าไม่เจอรหัสพนักงานในระบบ
    if (!employee) {
      return res.status(404).json({ error: "ไม่พบรหัสพนักงานนี้ในระบบ" });
    }

    // ถ้าเจอพนักงาน แต่พนักงานคนนี้ไม่มีสิทธิ์เข้าใช้ระบบ (ไม่มีข้อมูลในตาราง user)
    if (!employee.user) {
      return res.status(403).json({ error: "พนักงานท่านนี้ยังไม่ได้เปิดสิทธิ์การใช้งานระบบ" });
    }

    const userAccount = employee.user;

    // เช็กสถานะว่าบัญชีผู้ใช้ถูกระงับหรือไม่
    if (!userAccount.active) {
      return res.status(403).json({ error: "บัญชีผู้ใช้งานนี้ถูกระงับการใช้งาน" });
    }

    // 3. 🚦 (หมายเหตุระบบล็อกอินเวอร์ชันอัปเดต) 
    // เนื่องจากฐานข้อมูลตามเอกสาร PDF ชุดปัจจุบันไม่ได้ระบุฟิลด์สำหรับการเก็บ Password 
    // ระบบจะอนุญาตให้ตรวจสอบผ่านรหัสพนักงาน (employeeCode) เป็นหลักเพื่อเข้าสู่ระบบ
    // สิทธิ์การทำงาน (ADMIN / USER / GUARD) จะถูกแยกจากฟิลด์ roles ในตาราง User ทันที

    // 4. 🎟️ สร้าง Token (ฝังข้อมูลที่จำเป็นให้ Frontend เอาไปเช็กต่อได้ง่ายขึ้น)
    const token = jwt.sign(
      { 
        userId: userAccount.id, 
        role: userAccount.roles, 
        employeeCode: employee.employeeCode,
        fullName: employee.fullName
      }, 
      JWT_SECRET, 
      { expiresIn: '1d' }
    );
    
    // 5. ส่งกลับไปบอกเพื่อนหน้าบ้าน
    res.json({ 
      message: "เข้าสู่ระบบสำเร็จ", 
      token: token,
      role: userAccount.roles 
    });

  } catch (error) {
    console.error('Login Error:', error);
    res.status(500).json({ error: "ระบบขัดข้อง" });
  }
});

// 👤 API เช็กโปรไฟล์ของคนที่ถือ Token ปัจจุบัน (ปรับปรุงให้ดึงข้ามตารางเพื่อเอาชื่อ-ตำแหน่งมาโชว์)
router.get('/me', authenticateToken, async (req, res) => {
  try {
    // ดึงข้อมูลบัญชีผู้ใช้ พร้อมดึงข้อมูลจากตารางพนักงาน (employee) แผนก และตำแหน่งพ่วงมาเป็นทอดๆ
    const user = await prisma.user.findUnique({
      where: { id: req.user.userId },
      include: {
        employee: {
          include: {
            position: {
              include: {
                department: true
              }
            }
          }
        }
      }
    });
    
    if (!user || !user.employee) {
      return res.status(404).json({ error: "ไม่พบข้อมูลผู้ใช้งานนี้" });
    }
    
    const emp = user.employee;
    const pos = emp.position;
    const dept = pos ? pos.department : null;

    // ส่งโครงสร้างข้อมูลชุดใหม่กลับไปให้หน้าบ้านเอาไปแปะบนแถบเมนูหรือหน้าโปรไฟล์
    res.json({
      id: user.id,
      employeeCode: emp.employeeCode,
      fullName: emp.fullName,
      positionName: pos ? pos.positionName : "ไม่ระบุตำแหน่ง",
      departmentName: dept ? dept.departmentName : "ไม่ระบุแผนก",
      role: user.roles,
      active: user.active
    });

  } catch (error) {
    console.error('Me Error:', error);
    res.status(500).json({ error: "ระบบไม่สามารถตรวจสอบ Token ได้" });
  }
});

module.exports = router;