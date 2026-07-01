const express = require('express');
const { PrismaClient } = require('@prisma/client');
const jwt = require('jsonwebtoken');
const { JWT_SECRET, authenticateToken } = require('../middlewares/auth');

const router = express.Router();
const prisma = new PrismaClient();

// 🔑 API 1: Login (รองรับระบบ PIN Verification ตาม Checklist สัปดาห์ที่ 6)
router.post('/login', async (req, res) => {
  // 1. รับค่า employeeCode และ pin จากหน้าบ้าน
  const { employeeCode, pin } = req.body; 

  try {
    if (!employeeCode) {
      return res.status(400).json({ error: "กรุณากรอกรหัสพนักงาน" });
    }

    // 2. ค้นหาพนักงาน พร้อมดึงข้อมูล users (ดึงมาเป็น Array) และ position
    const employee = await prisma.employee.findUnique({
      where: { employeeCode: employeeCode },
      include: {
        users: true, // Prisma ใช้ users (เติม s) เพราะเป็น One-to-Many
        position: true
      }
    });

    // 3. ตรวจสอบว่ามีพนักงานและมีสิทธิ์ไหม
    if (!employee) {
      return res.status(404).json({ error: "ไม่พบรหัสพนักงานนี้ในระบบ" });
    }
    if (!employee.users || employee.users.length === 0) {
      return res.status(403).json({ error: "พนักงานท่านนี้ยังไม่ได้เปิดสิทธิ์การใช้งานระบบ" });
    }

    // ดึงบัญชีผู้ใช้อันแรกมาใช้งาน (ปกติ 1 คนจะมีแค่ 1 บัญชี)
    const userAccount = employee.users[0];

    if (!userAccount.active) {
      return res.status(403).json({ error: "บัญชีผู้ใช้งานนี้ถูกระงับการใช้งาน" });
    }

    // 4. 🛡️ เช็ก PIN ตาม Role (Week 6 Checklist)
    // ถ้าเป็น ADMIN หรือ GUARD จะต้องบังคับเช็ก PIN 6 หลัก
    if (userAccount.roles === 'ADMIN' || userAccount.roles === 'GUARD') {
      if (!pin || pin.length !== 6) {
        return res.status(400).json({ error: "กรุณากรอกรหัส PIN ให้ครบ 6 หลัก" });
      }
      if (userAccount.pin !== pin) {
        return res.status(401).json({ error: "รหัส PIN ไม่ถูกต้อง" });
      }
    }
    // หมายเหตุ: ถ้า Role เป็น 'USER' ระบบจะข้ามการเช็ก PIN ไปเลย (เข้าได้ทันที)

    // 5. 🎟️ สร้าง Token
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
    
    // 6. ส่งผลลัพธ์กลับไปให้ Frontend
    res.status(200).json({ 
      success: true,
      message: "เข้าสู่ระบบสำเร็จ", 
      token: token,
      role: userAccount.roles 
    });

  } catch (error) {
    console.error('Login Error:', error);
    res.status(500).json({ error: "ระบบขัดข้อง" });
  }
});

// 🔑 API 2: Login PIN (🟢 เวอร์ชันรวมร่าง: รองรับทั้ง ADMIN และ SECURITY พร้อมแยกระบบประตู)
router.post('/login-pin', async (req, res) => {
  try {
    // รับค่า expectedRole มาจากแอปมือถือเพื่อเช็กว่าเป็นประตูของใคร
    const { pin, expectedRole } = req.body; 
    let assignedRole = null;
    let assignedDept = null;

    // 🛡️ ตรวจสอบรหัส PIN
    if (pin === '001122') { 
      assignedRole = 'SECURITY'; 
      assignedDept = 'SECURITY'; 
    } 
    else if (pin === '741963') { 
      assignedRole = 'ADMIN'; 
      assignedDept = 'HR'; 
    } 
    else if (pin === '852000') { 
      assignedRole = 'ADMIN'; 
      assignedDept = 'IT'; 
    } 
    else { 
      return res.status(401).json({ success: false, message: 'รหัส PIN ไม่ถูกต้อง' }); 
    }

    // 🛑 ด่านตรวจสิทธิ์: ป้องกันการเข้าผิดประตู (เช่น เอารหัส ADMIN ไปใส่หน้าแอป SECURITY)
    if (expectedRole && assignedRole !== expectedRole) {
      return res.status(403).json({ success: false, message: `เข้าไม่ได้! รหัสนี้เป็นของ ${assignedRole}` });
    }

    // 🚀 ระบบบันทึกประวัติ (Log) ลงฐานข้อมูล
    try {
      await prisma.auditLog.create({
        data: {
          action: `เข้าสู่ระบบด้วยรหัส PIN (สิทธิ์: ${assignedRole}, แผนก: ${assignedDept})`,
          module: 'LOGIN_SYSTEM' 
        }
      });
      console.log(`[Log] บันทึกประวัติการเข้าใช้งานของ ${assignedRole} เรียบร้อยแล้ว`);
    } catch (logError) {
      console.error("⚠️ ไม่สามารถบันทึก Log ลง Database ได้:", logError.message);
    }

    // 🎟️ สร้าง Token สำหรับยืนยันตัวตน
    const token = jwt.sign({ role: assignedRole, department: assignedDept }, JWT_SECRET, { expiresIn: '12h' });
    
    return res.status(200).json({ 
      success: true, 
      message: 'เข้าสู่ระบบด้วย PIN สำเร็จ', 
      token: token, 
      role: assignedRole 
    });

  } catch (error) {
    return res.status(500).json({ success: false, message: 'เกิดข้อผิดพลาดที่เซิร์ฟเวอร์' });
  }
});

// 👤 API 3: เช็ก Profile
router.get('/me', authenticateToken, async (req, res) => {
  try {
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

    res.json({
      success: true,
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

// 🚦 Middleware ตรวจสอบสิทธิ์เฉพาะ ADMIN เท่านั้น
const isAdmin = (req, res, next) => {
  if (req.user && req.user.role === 'ADMIN') {
    next(); // สิทธิ์ถูกต้อง ปล่อยผ่านไปทำหน้าที่ต่อ
  } else {
    return res.status(403).json({ error: "ปฏิเสธการเข้าถึง: สิทธิ์ของคุณไม่เพียงพอ (เฉพาะ ADMIN เท่านั้น)" });
  }
};

// 🚦 Middleware ตรวจสอบสิทธิ์เฉพาะ GUARD / SECURITY เท่านั้น
const isGuard = (req, res, next) => {
  if (req.user && req.user.role === 'GUARD') {
    next();
  } else {
    return res.status(403).json({ error: "ปฏิเสธการเข้าถึง: เฉพาะเจ้าหน้าที่รักษาความปลอดภัย (GUARD) เท่านั้น" });
  }
};

// แนบ Middleware ไปกับ router เผื่อมีการเรียกใช้จากภายนอก
router.isAdmin = isAdmin;
router.isGuard = isGuard;

// Export ตัว router อย่างถูกต้องเพื่อให้ไฟล์หลัก (index.js) นำไปใช้งานได้
module.exports = router;