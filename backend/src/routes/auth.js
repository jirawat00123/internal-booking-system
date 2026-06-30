console.log("✅ auth.js loaded");
const express = require('express');
const { PrismaClient } = require('@prisma/client');
const jwt = require('jsonwebtoken');
const { JWT_SECRET, authenticateToken } = require('../middlewares/auth');


const router = express.Router();
const prisma = new PrismaClient();

// 🔑 API 1: Login พนักงาน (Employee)
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
    console.error("🔴 Login Error:", error);
    res.status(500).json({ error: "ระบบขัดข้อง" });
  }
});

// 🔑 API 2: Login PIN (🟢 เวอร์ชันแก้บั๊กตารางเพื่อนล่ม: รองรับทั้ง ADMIN และ SECURITY)
router.post('/login-pin', async (req, res) => {
  try {
    const { pin, expectedRole } = req.body; 
    let assignedRole = null;
    let assignedDept = null;

    console.log(`📥 [Request] มีการยิง PIN: ${pin} และ expectedRole: ${expectedRole} เข้ามา`);

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

    // 🛑 ด่านตรวจสิทธิ์: ป้องกันการเข้าผิดประตู
    if (expectedRole && assignedRole !== expectedRole) {
      return res.status(403).json({ success: false, message: `เข้าไม่ได้! รหัสนี้เป็นของ ${assignedRole}` });
    }

    // 🚀 เซฟตี้บล็อก: คลุมระบบบันทึกประวัติ (Log) ของเพื่อนเอาไว้
    try {
      // ตรวจสอบก่อนว่าโมเดล auditLog มีอยู่ใน Prisma ของเครื่องเราจริงไหม
      if (prisma.auditLog) {
        await prisma.auditLog.create({
          data: {
            action: `เข้าสู่ระบบด้วยรหัส PIN (สิทธิ์: ${assignedRole}, แผนก: ${assignedDept})`,
            module: 'LOGIN_SYSTEM' 
          }
        });
        console.log(`[Log] บันทึกประวัติการเข้าใช้งานของ ${assignedRole} เรียบร้อยแล้ว`);
      } else {
        console.log(`[Log-Skip] ข้ามการบันทึกประวัติเนื่องจากเครื่องนี้ไม่มีตาราง auditLog`);
      }
    } catch (logError) {
      // 💡 หากเครื่องคุณไม่มีตารางแบบเครื่องเพื่อน โค้ดจะตกมาตรงนี้ แต่จะ "ยอมให้ผ่าน" ไม่พาแอปดับแล้วครับ
      console.error("⚠️ ไม่สามารถบันทึก Log ลงฐานข้อมูลได้ (แต่ระบบอนุญาตให้ผ่าน):", logError.message);
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
    // พิมพ์สาเหตุจริงๆ ออกมาดูที่หน้าต่าง Terminal หลังบ้าน
    console.error("🔴 Centralized login-pin Error:", error); 
    return res.status(500).json({ success: false, message: 'เกิดข้อผิดพลาดที่เซิร์ฟเวอร์', error: error.message });
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