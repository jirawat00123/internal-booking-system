const express = require('express');
const { PrismaClient } = require('@prisma/client');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { JWT_SECRET, authenticateToken } = require('../middlewares/auth');

const { verifyPin } = require('../services/pinService');
const authController = require('../controllers/authController');

const router = express.Router();
const prisma = new PrismaClient();

// ⚙️ ตั้งค่าระบบ Security
const MAX_LOGIN_ATTEMPTS = 5;
const LOCK_TIME_MINUTES = 15;

// ==========================================
// 🔑 API 1: Login (Dropdown & Normal Login)
// ==========================================
router.post('/login', async (req, res) => {
  // 🚨 [STEP 3 EVIDENCE] Log Data ก่อนการตรวจ Validation
  console.log("[LOGIN] req.headers =", req.headers);
  console.log("[LOGIN] req.body =", req.body);

  const { employeeCode, pin } = req.body; 

  try {
    // 1. ตรวจสอบรหัสพนักงาน
    if (!employeeCode) {
      console.log("[LOGIN] Validation Error: Missing employeeCode in req.body");
      return res.status(400).json({ success: false, error: "กรุณาระบุรหัสพนักงาน" });
    }

    const employee = await prisma.employee.findUnique({
      where: { employeeCode: String(employeeCode).trim() },
      include: {
        users: { include: { role: true } },
        position: true
      }
    });

    if (!employee || !employee.users || employee.users.length === 0) {
      return res.status(404).json({ success: false, error: "ไม่พบรหัสพนักงานนี้หรือยังไม่เปิดสิทธิ์การใช้งาน" });
    }

    const userAccount = employee.users[0];

    if (!userAccount.active) {
      return res.status(403).json({ success: false, error: "บัญชีผู้ใช้งานนี้ถูกระงับการใช้งาน" });
    }

    if (userAccount.lockedUntil && userAccount.lockedUntil > new Date()) {
      const remainingTime = Math.ceil((userAccount.lockedUntil - new Date()) / 60000);
      return res.status(403).json({ 
        success: false, 
        error: `บัญชีถูกระงับชั่วคราวเนื่องจากใส่รหัสผิดเกินกำหนด กรุณาลองใหม่ในอีก ${remainingTime} นาที` 
      });
    }

    const role = userAccount.role ? userAccount.role.name : 'USER';

    // 2. 🛡️ เช็ก PIN: บังคับตรวจเฉพาะ Role ระดับสูง หรือเมื่อมีการส่ง PIN มาใน Request Body
    const isSecurityRole = ['ADMIN', 'SECURITY', 'GUARD'].includes(role);
    const hasPinInput = pin !== undefined && pin !== null && String(pin).trim() !== '';

    if (isSecurityRole || hasPinInput) {
      if (!pin) {
        console.log("[LOGIN] Validation Error: Missing required PIN field for role:", role);
        return res.status(400).json({ success: false, error: `กรุณากรอกรหัส PIN เพื่อยืนยันตัวตน` });
      }

      console.log("[PIN-LOGIN] Input PIN:", String(pin).trim());
      console.log("[PIN-LOGIN] Has Hash in DB:", !!userAccount.pin);

      const isPinValid = await verifyPin(userAccount.pin, String(pin).trim());
      
      console.log("[PIN-LOGIN] Verify Result:", isPinValid);

      if (!isPinValid) {
        console.log("[PIN-LOGIN] Login Failed: 401 Unauthorized");

        const attempts = (userAccount.failedLoginAttempts || 0) + 1;
        let updateData = { failedLoginAttempts: attempts };

        if (attempts >= MAX_LOGIN_ATTEMPTS) {
          updateData.lockedUntil = new Date(Date.now() + LOCK_TIME_MINUTES * 60000);
        }

        await prisma.user.update({
          where: { id: userAccount.id },
          data: updateData
        });

        if (attempts >= MAX_LOGIN_ATTEMPTS) {
          return res.status(401).json({ success: false, error: `คุณใส่ PIN ผิดเกิน ${MAX_LOGIN_ATTEMPTS} ครั้ง บัญชีถูกระงับ ${LOCK_TIME_MINUTES} นาที` });
        }
        return res.status(401).json({ success: false, error: `รหัส PIN ไม่ถูกต้อง (ผิดครั้งที่ ${attempts}/${MAX_LOGIN_ATTEMPTS})` });
      }

      console.log("[PIN-LOGIN] Login Success");
    }

    // 3. 🎟️ ออก Session และ JWT Token เมื่อผ่านการตรวจสอบ
    const newSessionId = crypto.randomUUID();

    await prisma.user.update({
      where: { id: userAccount.id },
      data: { 
        currentSessionId: newSessionId,
        failedLoginAttempts: 0, 
        lockedUntil: null,      
        lastLoginAt: new Date() 
      }
    });

    const secretKey = JWT_SECRET || process.env.JWT_SECRET || 'default_secret_key';
    const token = jwt.sign(
      { 
        userId: userAccount.id, 
        role: role, 
        employeeCode: employee.employeeCode,
        fullName: employee.fullName,
        sessionId: newSessionId 
      }, 
      secretKey, 
      { expiresIn: '1d' }
    );
    
    return res.status(200).json({ success: true, message: "เข้าสู่ระบบสำเร็จ", token: token, role: role });

  } catch (error) {
    console.error('Login Error:', error);
    return res.status(500).json({ success: false, error: "ระบบขัดข้อง" });
  }
});

// ==========================================
// 🔑 API 2: Login PIN
// ==========================================
router.post('/login-pin', async (req, res) => {
  try {
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

        // 🛡️ เช็กสถานะการล็อก
        if (userAccount.lockedUntil && userAccount.lockedUntil > new Date()) {
          const remainingTime = Math.ceil((userAccount.lockedUntil - new Date()) / 60000);
          return res.status(403).json({ success: false, message: `บัญชีถูกระงับชั่วคราว ลองใหม่ในอีก ${remainingTime} นาที` });
        }

        // 🚨 [EVIDENCE LOGS]
        console.log("[LOGIN-PIN] Input PIN:", inputPin);
        console.log("[LOGIN-PIN] Has Hash in DB:", !!userAccount.pin);

        // 🟢 ตรวจสอบ PIN (Hash จาก DB, Plain PIN จาก User)
        const isPinValid = await verifyPin(userAccount.pin, inputPin);
        
        console.log("[LOGIN-PIN] Verify Result:", isPinValid);

        if (!isPinValid) {
            console.log("[LOGIN-PIN] Login Failed: 401 Unauthorized");

            const attempts = (userAccount.failedLoginAttempts || 0) + 1;
            let updateData = { failedLoginAttempts: attempts };

            if (attempts >= MAX_LOGIN_ATTEMPTS) {
              updateData.lockedUntil = new Date(Date.now() + LOCK_TIME_MINUTES * 60000);
            }

            await prisma.user.update({
              where: { id: userAccount.id },
              data: updateData
            });

            if (attempts >= MAX_LOGIN_ATTEMPTS) {
              return res.status(401).json({ success: false, message: `ใส่ PIN ผิดเกินกำหนด บัญชีถูกระงับ ${LOCK_TIME_MINUTES} นาที` });
            }
            return res.status(401).json({ success: false, message: `รหัส PIN ไม่ถูกต้อง (ผิดครั้งที่ ${attempts}/${MAX_LOGIN_ATTEMPTS})` });
        }

        console.log("[LOGIN-PIN] Login Success");

        actualUserId = userAccount.id;
        actualUserName = employee.fullName;
        actualEmployeeCode = employee.employeeCode;
        assignedRole = userAccount.role ? userAccount.role.name : 'USER';
        assignedDept = employee.position?.department?.departmentName || "ไม่ระบุแผนก";

        if (expectedRole && assignedRole !== expectedRole) {
            return res.status(403).json({ success: false, message: `เข้าไม่ได้! คุณไม่มีสิทธิ์เป็น ${expectedRole}` });
        }

    } else {
        // Fallback: กรณีไม่ส่ง employeeCode มา
        const activeUsers = await prisma.user.findMany({
          where: { active: true, pin: { not: null } },
          include: { role: true, employee: { include: { position: { include: { department: true } } } } }
        });

        let matchedUser = null;
        for (const user of activeUsers) {
          if (user.pin && (await verifyPin(user.pin, inputPin))) {
            matchedUser = user;
            break;
          }
        }

        if (!matchedUser) {
          return res.status(401).json({ success: false, message: 'รหัส PIN ไม่ถูกต้อง หรือบัญชีถูกระงับ' });
        }

        if (matchedUser.lockedUntil && matchedUser.lockedUntil > new Date()) {
          return res.status(403).json({ success: false, message: 'บัญชีนี้อยู่ระหว่างถูกระงับชั่วคราว' });
        }

        assignedRole = matchedUser.role ? matchedUser.role.name : (matchedUser.roles || 'USER');
        assignedDept = matchedUser.employee?.position?.department?.departmentName || "ไม่ระบุแผนก";
        
        const isSecurityGroup = (expectedRole === 'GUARD' || expectedRole === 'SECURITY') && 
                                (assignedRole === 'GUARD' || assignedRole === 'SECURITY');

        if (expectedRole && assignedRole !== expectedRole && !isSecurityGroup) {
          return res.status(403).json({ success: false, message: `เข้าไม่ได้! รหัสนี้เป็นของ ${assignedRole}` });
        }

        actualUserId = matchedUser.id;
        actualUserName = matchedUser.employee?.fullName || "ไม่ระบุชื่อ";
        actualEmployeeCode = matchedUser.employee?.employeeCode || "";
    }

    const newSessionId = crypto.randomUUID();

    // ✅ อัปเดตข้อมูล Session และเคลียร์ค่าการล็อก
    await prisma.user.update({
      where: { id: actualUserId },
      data: { 
        currentSessionId: newSessionId,
        failedLoginAttempts: 0,
        lockedUntil: null,
        lastLoginAt: new Date()
      }
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
        employeeCode: actualEmployeeCode,
        fullName: actualUserName,
        department: assignedDept,
        sessionId: newSessionId 
      }, 
      secretKey, 
      { expiresIn: '12h' }
    );
    
    return res.status(200).json({ success: true, message: 'เข้าสู่ระบบด้วย PIN สำเร็จ', token: token, role: assignedRole });

  } catch (error) {
    console.error('Login PIN Error:', error);
    return res.status(500).json({ success: false, message: 'เกิดข้อผิดพลาดที่เซิร์ฟเวอร์' });
  }
});

// ==========================================
// 📋 API 3: ดึงข้อมูลพนักงานจัดกลุ่มตามแผนก
// ==========================================
router.get('/login-users-list', async (req, res) => {
  try {
    const employees = await prisma.employee.findMany({
      include: { users: true, position: { include: { department: true } } }
    });

    const activeUsers = employees.filter(emp => 
      emp.users && emp.users.length > 0 && emp.users[0].active && emp.users[0].roles === 'USER'
    );

    const groupedData = activeUsers.reduce((acc, emp) => {
      const deptName = emp.position?.department?.departmentName || "ไม่ระบุแผนก";
      if (!acc[deptName]) acc[deptName] = [];
      acc[deptName].push({ employeeCode: emp.employeeCode, fullName: emp.fullName });
      return acc;
    }, {});

    const formattedData = Object.keys(groupedData).map(dept => ({
      departmentName: dept, employees: groupedData[dept]
    }));

    return res.status(200).json({ success: true, data: formattedData });
  } catch (error) {
    return res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลรายชื่อได้" });
  }
});

// ==========================================
// 👤 API 4: เช็ก Profile
// ==========================================
router.get('/me', authenticateToken, async (req, res) => {
  try {
    if (!req.user || !req.user.userId) {
        return res.status(400).json({ success: false, error: "ข้อมูล Token ไม่สมบูรณ์" });
    }

    const user = await prisma.user.findUnique({
      where: { id: req.user.userId },
      include: { role: true, employee: { include: { position: { include: { department: true } } } } }
    });
    
    if (!user || !user.employee) return res.status(404).json({ success: false, error: "ไม่พบข้อมูลผู้ใช้งาน" });
    
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
      role: user.role ? user.role.name : (user.roles || 'USER'),
      active: user.active,
      pinInitialized: user.pinInitialized,
      pinResetRequired: user.pinResetRequired
    });

  } catch (error) {
    return res.status(500).json({ success: false, error: "ระบบไม่สามารถตรวจสอบ Token ได้" });
  }
});

// ==========================================
// 🚦 Middlewares ตรวจสอบสิทธิ์
// ==========================================
const isAdmin = (req, res, next) => {
  if (req.user && req.user.role === 'ADMIN') next(); 
  else return res.status(403).json({ success: false, error: "ปฏิเสธการเข้าถึง: สิทธิ์ของคุณไม่เพียงพอ" });
};

const isGuard = (req, res, next) => {
  if (req.user && (req.user.role === 'GUARD' || req.user.role === 'SECURITY')) next();
  else return res.status(403).json({ success: false, error: "ปฏิเสธการเข้าถึง: เฉพาะเจ้าหน้าที่รักษาความปลอดภัยเท่านั้น" });
};

// ==========================================
// 🚪 API 5: Logout
// ==========================================
router.post('/logout', authenticateToken, async (req, res) => {
  try {
    await prisma.user.update({
      where: { id: req.user.userId },
      data: { currentSessionId: null }
    });
    return res.status(200).json({ success: true, message: "ออกจากระบบสำเร็จ" });
  } catch (error) {
    return res.status(500).json({ success: false, error: "ระบบไม่สามารถออกจากระบบได้" });
  }
});

// ==========================================
// 🔐 API 6 & 7: PIN Management
// ==========================================
router.post('/setup-pin', authenticateToken, authController.setupPin);
router.post('/change-pin', authenticateToken, authController.changePin);
router.post('/admin/users/:id/reset-pin', authenticateToken, isAdmin, authController.resetUserPin);

router.isAdmin = isAdmin;
router.isGuard = isGuard;
module.exports = router;