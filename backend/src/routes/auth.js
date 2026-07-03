const express = require('express');
const { PrismaClient } = require('@prisma/client');
const jwt = require('jsonwebtoken');
const { JWT_SECRET, authenticateToken } = require('../middlewares/auth');

const router = express.Router();
const prisma = new PrismaClient();

// ==========================================
// 🔑 API 1: Login (USER ใช้ Dropdown ไม่ต้องมี PIN / ADMIN & SECURITY ต้องใช้ PIN)
// ==========================================
router.post('/login', async (req, res) => {
  const { employeeCode, pin } = req.body; 

  try {
    if (!employeeCode) {
      return res.status(400).json({ success: false, error: "กรุณาระบุรหัสพนักงาน" });
    }

    // 1. ค้นหาพนักงานและข้อมูลบัญชีผู้ใช้
    const employee = await prisma.employee.findUnique({
      where: { employeeCode: employeeCode },
      include: {
        users: true,
        position: true
      }
    });

    if (!employee) {
      return res.status(404).json({ success: false, error: "ไม่พบรหัสพนักงานนี้ในระบบ" });
    }
    if (!employee.users || employee.users.length === 0) {
      return res.status(403).json({ success: false, error: "พนักงานท่านนี้ยังไม่ได้เปิดสิทธิ์การใช้งานระบบ" });
    }

    const userAccount = employee.users[0];

    if (!userAccount.active) {
      return res.status(403).json({ success: false, error: "บัญชีผู้ใช้งานนี้ถูกระงับการใช้งาน" });
    }

    const role = userAccount.roles;

    // 2. 🛡️ เช็ก PIN ตาม Role ที่กำหนด
    // 💡 สิทธิ์ 'USER' จะข้ามบล็อก if นี้ไปเลย ทำให้ล็อกอินผ่านได้ทันทีแค่มี employeeCode
    if (role === 'ADMIN' || role === 'SECURITY' || role === 'GUARD') {
      if (!pin) {
        return res.status(400).json({ success: false, error: `คุณมีสิทธิ์เป็น ${role} กรุณากรอกรหัส PIN เพื่อยืนยันตัวตน` });
      }
      if (userAccount.pin !== pin) {
        return res.status(401).json({ success: false, error: "รหัส PIN ไม่ถูกต้อง" });
      }
    } 

    // 3. 🎟️ สร้าง Token
    const secretKey = JWT_SECRET || process.env.JWT_SECRET || 'default_secret_key';
    const token = jwt.sign(
      { 
        userId: userAccount.id, 
        role: role, 
        employeeCode: employee.employeeCode,
        fullName: employee.fullName
      }, 
      secretKey, 
      { expiresIn: '1d' }
    );
    
    // 4. ส่งผลลัพธ์
    return res.status(200).json({ 
      success: true,
      message: "เข้าสู่ระบบสำเร็จ", 
      token: token,
      role: role 
    });

  } catch (error) {
    console.error('Login Error:', error);
    return res.status(500).json({ success: false, error: "ระบบขัดข้อง" });
  }
});


// ==========================================
// 🔑 API 2: Login PIN (สำหรับประตูส่วนกลาง เข้าด้วย PIN อัตโนมัติ)
// ==========================================
router.post('/login-pin', async (req, res) => {
  try {
    const { pin, expectedRole } = req.body; 

    // 🛡️ ตรวจสอบรหัส PIN
    const pinRoles = {
      '001122': { assignedRole: 'SECURITY', assignedDept: 'SECURITY' },
      '741963': { assignedRole: 'ADMIN', assignedDept: 'HR' },
      '852000': { assignedRole: 'ADMIN', assignedDept: 'IT' }
    };

    const roleData = pinRoles[pin];

    if (!roleData) {
      return res.status(401).json({ success: false, message: 'รหัส PIN ไม่ถูกต้อง' }); 
    }

    const { assignedRole, assignedDept } = roleData;

    // 🛑 ด่านตรวจสิทธิ์: ป้องกันการเข้าผิดประตู
    if (expectedRole && assignedRole !== expectedRole) {
      return res.status(403).json({ success: false, message: `เข้าไม่ได้! รหัสนี้เป็นของ ${assignedRole}` });
    }

    // 🚀 ระบบบันทึกประวัติ (Log)
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

    // 🎟️ สร้าง Token
    const secretKey = JWT_SECRET || process.env.JWT_SECRET || 'default_secret_key';
    const token = jwt.sign(
      { role: assignedRole, department: assignedDept }, 
      secretKey, 
      { expiresIn: '12h' }
    );
    
    return res.status(200).json({ 
      success: true, 
      message: 'เข้าสู่ระบบด้วย PIN สำเร็จ', 
      token: token, 
      role: assignedRole 
    });

  } catch (error) {
    console.error('Login PIN Error:', error);
    return res.status(500).json({ success: false, message: 'เกิดข้อผิดพลาดที่เซิร์ฟเวอร์' });
  }
});


// ==========================================
// 📋 API 3: ดึงข้อมูลพนักงานจัดกลุ่มตามแผนก (สำหรับทำ Cascading Dropdown)
// ==========================================
router.get('/login-users-list', async (req, res) => {
  try {
    const employees = await prisma.employee.findMany({
      include: {
        users: true,
        position: {
          include: { department: true }
        }
      }
    });

    // 1. กรองเอาเฉพาะคนที่เปิดบัญชีแล้ว (Active) และมีสิทธิ์เป็น 'USER' เท่านั้น
    const activeUsers = employees.filter(emp => 
      emp.users && emp.users.length > 0 && 
      emp.users[0].active && emp.users[0].roles === 'USER'
    );

    // 2. จัดกลุ่มข้อมูลพนักงานตามแผนก (Group by Department)
    const groupedData = activeUsers.reduce((acc, emp) => {
      const deptName = emp.position?.department?.departmentName || "ไม่ระบุแผนก";
      
      // ถ้ายังไม่มีแผนกนี้ใน Object ให้สร้าง Array ว่างรอไว้
      if (!acc[deptName]) {
        acc[deptName] = [];
      }
      
      // ดันข้อมูลพนักงานเข้าไปในแผนกนั้นๆ
      acc[deptName].push({
        employeeCode: emp.employeeCode,
        fullName: emp.fullName
      });
      
      return acc;
    }, {});

    // 3. แปลง Object ให้เป็น Array เพื่อให้ Frontend เอาไป Loop สร้าง Dropdown ได้ง่ายๆ
    const formattedData = Object.keys(groupedData).map(dept => ({
      departmentName: dept,
      employees: groupedData[dept]
    }));

    return res.status(200).json({ 
      success: true, 
      data: formattedData 
    });

  } catch (error) {
    console.error('Fetch Users List Error:', error);
    return res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลรายชื่อได้" });
  }
});


// ==========================================
// 👤 API 4: เช็ก Profile
// ==========================================
router.get('/me', authenticateToken, async (req, res) => {
  try {
    if (!req.user || !req.user.userId) {
        return res.status(400).json({ success: false, error: "ข้อมูลผู้ใช้งานใน Token ไม่สมบูรณ์ (อาจเป็น Token จากประตู PIN)" });
    }

    const user = await prisma.user.findUnique({
      where: { id: req.user.userId },
      include: {
        employee: {
          include: {
            position: {
              include: { department: true }
            }
          }
        }
      }
    });
    
    if (!user || !user.employee) {
      return res.status(404).json({ success: false, error: "ไม่พบข้อมูลผู้ใช้งานนี้ในระบบ" });
    }
    
    const emp = user.employee;
    const pos = emp.position;
    const dept = pos ? pos.department : null;

    return res.status(200).json({
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
    return res.status(500).json({ success: false, error: "ระบบไม่สามารถตรวจสอบ Token ได้" });
  }
});


// ==========================================
// 🚦 Middlewares ตรวจสอบสิทธิ์ (Export ให้ใช้งานภายนอก)
// ==========================================
const isAdmin = (req, res, next) => {
  if (req.user && req.user.role === 'ADMIN') {
    next(); 
  } else {
    return res.status(403).json({ success: false, error: "ปฏิเสธการเข้าถึง: สิทธิ์ของคุณไม่เพียงพอ (เฉพาะ ADMIN เท่านั้น)" });
  }
};

const isGuard = (req, res, next) => {
  if (req.user && (req.user.role === 'GUARD' || req.user.role === 'SECURITY')) {
    next();
  } else {
    return res.status(403).json({ success: false, error: "ปฏิเสธการเข้าถึง: เฉพาะเจ้าหน้าที่รักษาความปลอดภัยเท่านั้น" });
  }
};

router.isAdmin = isAdmin;
router.isGuard = isGuard;

module.exports = router;