const express = require('express');
const { PrismaClient } = require('@prisma/client');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
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
    // 1. ค้นหาพนักงานและข้อมูลบัญชีผู้ใช้ (แก้ไขการ Include ตารางสิทธิ์)
    const employee = await prisma.employee.findUnique({
      where: { employeeCode: employeeCode },
      include: {
        users: { include: { role: true } }, // ✅ สั่ง Include ตาราง role เพื่อให้นำไปใช้ .role.name ได้
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

    // ✅ แก้ไข: เปลี่ยนจากการเรียกใช้ตัวแปรที่ไม่มีจริง (.roles) เป็นการดึงค่าจาก Relation Object (.role.name) 
    // หากไม่พบข้อมูลให้ Default เป็นสิทธิ์พนักงานทั่วไป ('USER') เพื่อป้องกัน Breaking Change
    const role = userAccount.role ? userAccount.role.name : 'USER';

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

    // 🚀 เพิ่มระบบบันทึกประวัติ (Log) สำหรับ API 1
    try {
      await prisma.auditLog.create({
        data: {
          userId: userAccount.id, // บันทึก ID ผู้ใช้
          action: `เข้าสู่ระบบผ่าน Dropdown (สิทธิ์: ${role}, ชื่อ: ${employee.fullName})`,
          module: 'LOGIN_SYSTEM'
        }
      });
    } catch (logError) {
      console.error("⚠️ ไม่สามารถบันทึก Log ลง Database ได้:", logError.message);
    }

    // 3. 🎟️ สร้าง Token
    const newSessionId = crypto.randomUUID(); // 👈 สร้าง Session ID ใหม่

    // 👈 บันทึก Session ID ล่าสุดลง Database
    await prisma.user.update({
      where: { id: userAccount.id },
      data: { currentSessionId: newSessionId }
    });

    const secretKey = JWT_SECRET || process.env.JWT_SECRET || 'default_secret_key';
    const token = jwt.sign(
      { 
        userId: userAccount.id, 
        role: role, 
        employeeCode: employee.employeeCode,
        fullName: employee.fullName,
        sessionId: newSessionId // 👈 ฝัง Session ID ลงใน Token Payload
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
// 🔑 API 2: Login PIN (แก้ไขให้รองรับ Session ID ป้องกัน 401 ค้าง)
// ==========================================
router.post('/login-pin', async (req, res) => {
  try {
    // 💡 1. รับ employeeCode เพิ่มมาจาก Frontend เพื่อเชื่อมโยงว่าใครกำลังล็อกอิน
    const { pin, expectedRole, employeeCode } = req.body; 

    if (!pin) {
      return res.status(400).json({ success: false, message: 'กรุณาส่งข้อมูล PIN' });
    }

    const inputPin = String(pin).trim();
    
    let actualUserId = null;
    let actualUserName = "ไม่ทราบชื่อ";
    let actualEmployeeCode = "";
    let assignedRole = "USER";
    let assignedDept = "ไม่ระบุแผนก";

    // 💡 2. เปลี่ยนมาตรวจ PIN จาก Database จริงตามรหัสพนักงาน
    if (employeeCode) {
        const employee = await prisma.employee.findUnique({
            where: { employeeCode: String(employeeCode).trim() },
            include: {
                users: { include: { role: true } },
                position: { include: { department: true } }
            }
        });

        if (!employee || !employee.users || employee.users.length === 0) {
            return res.status(404).json({ success: false, message: 'ไม่พบผู้ใช้งานนี้ในระบบ' });
        }

        const userAccount = employee.users[0];
        
        if (!userAccount.active) {
            return res.status(403).json({ success: false, message: 'บัญชีผู้ใช้งานถูกระงับ' });
        }

        // 💡 ตรวจสอบ PIN กับ Database จริง
        if (userAccount.pin !== inputPin) {
            return res.status(401).json({ success: false, message: 'รหัส PIN ไม่ถูกต้อง' });
        }

        actualUserId = userAccount.id;
        actualUserName = employee.fullName;
        actualEmployeeCode = employee.employeeCode;
        assignedRole = userAccount.role ? userAccount.role.name : 'USER';
        assignedDept = employee.position?.department?.departmentName || "ไม่ระบุแผนก";

        // ตรวจสอบสิทธิ์หาก Frontend มีการกำหนด expectedRole
        if (expectedRole && assignedRole !== expectedRole) {
            return res.status(403).json({ success: false, message: `เข้าไม่ได้! คุณไม่มีสิทธิ์เป็น ${expectedRole}` });
        }

    } else {
        // 💡 3. Fallback: เผื่อหน้าบ้านยังไม่ส่ง employeeCode มา (ลอจิกเดิม)
        
        // 💡 เพิ่ม Console Log ชั่วคราวเพื่อพิสูจน์ Root Cause ตามที่คุณต้องการ
        console.log("=== Debug PIN Login ===");
        console.log({
          employeeCode,
          pin,
          expectedRole,
          assignedRole, // ก่อนนี้จะเป็น 'USER'
          actualUserId,
          actualEmployeeCode
        });

        // 💡 1. ค้นหา User จาก PIN ใน Database ทันที (ลบตัวแปร pinRoles ทิ้งทั้งหมด)
        const matchedUser = await prisma.user.findFirst({
          where: {
            pin: inputPin,
            active: true
          },
          include: {
            role: true, 
            employee: {
              include: {
                position: {
                  include: { department: true }
                }
              }
            }
          }
        });

        if (!matchedUser) {
          return res.status(401).json({ success: false, message: 'รหัส PIN ไม่ถูกต้อง หรือบัญชีถูกระงับ' });
        }

        // 💡 2. อ่าน Role จากฐานข้อมูลจริงๆ (ให้ผลลัพธ์เป็น 'ADMIN' ตามที่คุณแก้ DB ไว้)
        // 💡 เพิ่ม Debug ตามที่กำหนดเพื่อพิสูจน์ค่า (ลบออกได้เมื่อแก้ปัญหาเสร็จ)
        console.log("matchedUser =", matchedUser);
        console.log("matchedUser.role =", matchedUser.role);
        console.log("matchedUser.roles =", matchedUser.roles);
        console.log("assignedRole Before =", assignedRole);

        // 💡 2. ปรับการดึง Role ให้รองรับทั้งแบบ Relation (.role.name) และแบบ Field (.roles)
        assignedRole = matchedUser.role ? matchedUser.role.name : (matchedUser.roles || 'USER');
        assignedDept = matchedUser.employee?.position?.department?.departmentName || "ไม่ระบุแผนก";

        console.log("assignedRole After =", assignedRole);

        // 💡 3. ตรวจสอบสิทธิ์แบบยืดหยุ่น (จัดกลุ่ม SECURITY และ GUARD ให้เข้าถึงกันได้เหมือน Middleware)
        const isSecurityGroup = (expectedRole === 'GUARD' || expectedRole === 'SECURITY') && 
                                (assignedRole === 'GUARD' || assignedRole === 'SECURITY');

        if (expectedRole && assignedRole !== expectedRole && !isSecurityGroup) {
          return res.status(403).json({ success: false, message: `เข้าไม่ได้! รหัสนี้เป็นของ ${assignedRole}` });
        }

        // 💡 4. เก็บตัวแปรเตรียมส่งทำ Session และ Audit Log
        actualUserId = matchedUser.id;
        actualUserName = matchedUser.employee?.fullName || "ไม่ระบุชื่อ";
        actualEmployeeCode = matchedUser.employee?.employeeCode || "";
    }

    // 🚀 สร้าง Session ID และฝัง JWT (โค้ดเดิมทั้งหมด ไม่ลบ)
    const newSessionId = crypto.randomUUID();

    await prisma.user.update({
      where: { id: actualUserId },
      data: { currentSessionId: newSessionId }
    });

    try {
      await prisma.auditLog.create({
        data: {
          userId: actualUserId, 
          action: `เข้าสู่ระบบด้วยรหัส PIN (สิทธิ์: ${assignedRole}, แผนก: ${assignedDept}, ชื่อ: ${actualUserName})`,
          module: "LOGIN_SYSTEM",
        }
      });
    } catch (logError) {
      console.error("⚠️ ไม่สามารถบันทึก Log ลง Database ได้:", logError.message);
    }

    const secretKey = JWT_SECRET || process.env.JWT_SECRET || 'default_secret_key';
    const token = jwt.sign(
      { 
        userId: actualUserId,   
        role: assignedRole, 
        employeeCode: actualEmployeeCode, // 👈 เพิ่มให้ Token Payload เหมือน API 1
        fullName: actualUserName,         // 👈 เพิ่มให้ Token Payload เหมือน API 1
        department: assignedDept,
        sessionId: newSessionId 
      }, 
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
        return res.status(400).json({ success: false, error: "ข้อมูลผู้ใช้งานใน Token ไม่สมบูรณ์ (อาจเป็น Token จากประตู PIN ที่ค้นหาผู้ใช้ไม่พบ)" });
    }

    const user = await prisma.user.findUnique({
      where: { id: req.user.userId },
      include: {
        role: true, // ✅ เพิ่มการ Include ข้อมูล role ของ User
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

// ==========================================
// 🚪 API 5: Logout (ล้างค่า Session)
// ==========================================
router.post('/logout', authenticateToken, async (req, res) => {
  try {
    // ล้างค่า Session ในฐานข้อมูลให้เป็น null
    await prisma.user.update({
      where: { id: req.user.userId },
      data: { currentSessionId: null }
    });
    
    return res.status(200).json({ success: true, message: "ออกจากระบบสำเร็จ" });
  } catch (error) {
    console.error('Logout Error:', error);
    return res.status(500).json({ success: false, error: "ระบบไม่สามารถออกจากระบบได้" });
  }
});

router.isAdmin = isAdmin;
router.isGuard = isGuard;
module.exports = router;