const express = require('express');
const { PrismaClient } = require('@prisma/client');
const jwt = require('jsonwebtoken');
const { JWT_SECRET, authenticateToken } = require('../middlewares/auth');

const router = express.Router();
const prisma = new PrismaClient();

// 🔑 API 1: Login พนักงาน
router.post('/login', async (req, res) => {
  const { employeeCode } = req.body; 
  try {
    if (!employeeCode) return res.status(400).json({ error: "กรุณากรอกรหัสพนักงาน" });

    const employee = await prisma.employee.findUnique({
      where: { employeeCode: employeeCode },
      include: { user: true, position: true }
    });

    if (!employee) return res.status(404).json({ error: "ไม่พบรหัสพนักงานนี้ในระบบ" });
    if (!employee.user) return res.status(403).json({ error: "พนักงานท่านนี้ยังไม่ได้เปิดสิทธิ์" });
    if (!employee.user.active) return res.status(403).json({ error: "บัญชีถูกระงับ" });

    const token = jwt.sign(
      { userId: employee.user.id, role: employee.user.roles, employeeCode: employee.employeeCode, fullName: employee.fullName }, 
      JWT_SECRET, { expiresIn: '1d' }
    );
    res.json({ message: "เข้าสู่ระบบสำเร็จ", token: token, role: employee.user.roles });
  } catch (error) {
    res.status(500).json({ error: "ระบบขัดข้อง" });
  }
});

// 🔑 API 2: Login PIN (สำหรับ ADMIN เท่านั้น - สาขา Admin Branch)
router.post('/login-pin', async (req, res) => {
  try {
    const { pin } = req.body; 
    let assignedRole = null;
    let assignedDept = null;

    // 🛑 ตัด Security ออก เหลือแค่ ADMIN ของ HR และ IT
    if (pin === '741963') { 
      assignedRole = 'ADMIN'; 
      assignedDept = 'HR'; 
    } 
    else if (pin === '852000') { 
      assignedRole = 'ADMIN'; 
      assignedDept = 'IT'; 
    } 
    else { 
      // ถ้ารหัสไม่ใช่ 2 ตัวบน (รวมถึงเอารหัส 001122 มาใส่) จะเด้งออกทันที!
      return res.status(401).json({ success: false, message: 'รหัส PIN ไม่ถูกต้อง' }); 
    }

    // 🚀 ระบบบันทึกประวัติ (Log) สำหรับ ADMIN
    try {
      await prisma.auditLog.create({
        data: {
          action: `เข้าสู่ระบบด้วยรหัส PIN (สิทธิ์: ${assignedRole}, แผนก: ${assignedDept})`,
          module: 'LOGIN_SYSTEM' 
        }
      });
      console.log(`[Log] บันทึกประวัติการเข้าใช้งานของ ADMIN (${assignedDept}) เรียบร้อยแล้ว`);
    } catch (logError) {
      console.error("⚠️ ไม่สามารถบันทึก Log ลง Database ได้:", logError.message);
    }

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
      include: { employee: { include: { position: { include: { department: true } } } } }
    });
    
    if (!user || !user.employee) return res.status(404).json({ error: "ไม่พบข้อมูลผู้ใช้งานนี้" });
    
    const emp = user.employee;
    const pos = emp.position;
    const dept = pos ? pos.department : null;

    res.json({
      id: user.id, employeeCode: emp.employeeCode, fullName: emp.fullName,
      positionName: pos ? pos.positionName : "ไม่ระบุตำแหน่ง",
      departmentName: dept ? dept.departmentName : "ไม่ระบุแผนก",
      role: user.roles, active: user.active
    });
  } catch (error) {
    res.status(500).json({ error: "ระบบไม่สามารถตรวจสอบ Token ได้" });
  }
});

module.exports = router;