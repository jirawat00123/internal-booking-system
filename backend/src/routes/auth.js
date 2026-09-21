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

  const { employeeCode, pin, force } = req.body; 

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
        position: { include: { department: true } } // ✅ ดึงข้อมูลแผนกมาด้วย
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

    // 2. 🛡️ เช็กสถานะ PIN และตรวจสอบความถูกต้อง
    const hasPinInput = pin !== undefined && pin !== null && String(pin).trim() !== '';
    const isPinSetupDone = userAccount.pinInitialized || !!userAccount.pin;

    // 🟢 ถ้าผู้ใช้ต้องตั้งค่า PIN ใหม่ หรือยังไม่ได้ตั้งค่า PIN ให้แจ้งเตือนโดยไม่สร้าง Session
    if (userAccount.pinResetRequired || !isPinSetupDone) {
      return res.status(200).json({
        success: true,
        message: "กรุณาตั้งค่ารหัส PIN ใหม่",
        pinInitialized: false,
        pinResetRequired: true
      });
    }

    // 🟢 ถ้ายังไม่ได้ส่ง PIN มาใน Request (การเรียกเช็กสถานะก่อนกรอก PIN) ให้ตอบกลับโดยไม่สร้าง Session
    if (!hasPinInput) {
      return res.status(200).json({
        success: true,
        message: "กรุณากรอกรหัส PIN เพื่อยืนยันตัวตน",
        pinInitialized: true,
        pinResetRequired: false
      });
    }

    // 🟢 ตรวจสอบความถูกต้องของ PIN
    const isPinValid = await verifyPin(userAccount.pin, String(pin).trim());
    if (!isPinValid) {
      console.log("[PIN-LOGIN] Login Failed: 401 Unauthorized");

      const isLockExpired = userAccount.lockedUntil && userAccount.lockedUntil <= new Date();
      const attempts = (isLockExpired ? 0 : (userAccount.failedLoginAttempts || 0)) + 1;
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
      return res.status(401).json({ success: false, error: "รหัส PIN ไม่ถูกต้อง" });
    }

    console.log("[PIN-LOGIN] Login Success");

    // 🟢 ตรวจสอบเซสชันที่ค้างอยู่ (ถ้ามีเซสชันเดิม และไม่มีการส่ง force=true ให้ตอบ 409 Conflict กลับไป)
    const isForceLogin = force === true || force === 'true';
    if (userAccount.currentSessionId && !isForceLogin) {
      return res.status(409).json({
        success: false,
        error: "SESSION_ALREADY_ACTIVE",
        message: "บัญชีนี้กำลังใช้งานอยู่ กรุณาออกจากระบบจากอุปกรณ์เดิมก่อน"
      });
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
      { expiresIn: '30m' }
    );
    
// 🟢 [แก้ไขใหม่] บันทึก AuditLog ให้แสดงรูปแบบเหมือนเส้น /login-pin
    try {
      const deptName = employee.position?.department?.departmentName || "ไม่ระบุแผนก";
      
      await prisma.auditLog.create({
        data: {
          userId: parseInt(userAccount.id, 10),
          action: `เข้าสู่ระบบด้วยรหัส PIN (สิทธิ์: ${role}, แผนก: ${deptName}, ชื่อ: ${employee.fullName})`,
          module: "LOGIN_SYSTEM",
          entityId: parseInt(userAccount.id, 10),
          entityType: "USER",
          details: "เข้าสู่ระบบผ่านหน้าล็อกอินหลัก"
        }
      });
      console.log("✅ [LOGIN] AuditLog Saved Successfully");
    } catch (logError) {
      console.error("❌ [LOGIN] AuditLog Error:", logError.message);
    }

    // 🔥 FIX: เพิ่ม pinInitialized และ pinResetRequired ส่งกลับไปให้ Flutter
    return res.status(200).json({ 
      success: true, 
      message: "เข้าสู่ระบบสำเร็จ", 
      token: token, 
      role: role,
      // ถ้า false แต่มีรหัส PIN อยู่แล้ว ให้ปรับเป็น true อัตโนมัติ
      pinInitialized: userAccount.pinInitialized || (userAccount.pin ? true : false),
      pinResetRequired: userAccount.pinResetRequired
    });

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
    const { pin, expectedRole, employeeCode, force } = req.body;

    console.log("========== [LOGIN-PIN DEBUG] ==========");
    console.log("[LOGIN-PIN] employeeCode =", employeeCode);
    console.log("[LOGIN-PIN] expectedRole =", expectedRole);
    console.log("[LOGIN-PIN] hasPin =", !!pin);
    console.log("========================================");

    if (!pin) {
      return res.status(400).json({ success: false, message: 'กรุณาส่งข้อมูล PIN' });
    }

    const inputPin = String(pin).trim();
    let actualUserId = null;
    let actualUserName = "ไม่ทราบชื่อ";
    let actualEmployeeCode = "";
    let assignedRole = "USER";
    let assignedDept = "ไม่ระบุแผนก";
    let matchedUser = null;

        if (employeeCode) {
        // 🔐 กรณีส่ง employeeCode มาด้วย ให้ค้นหาจากรหัสพนักงานก่อน
        const employee = await prisma.employee.findUnique({
          where: { employeeCode: String(employeeCode).trim() },
          include: {
            users: { include: { role: true } },
            position: { include: { department: true } }
          }
        });

        if (!employee || !employee.users || employee.users.length === 0) {
              return res.status(404).json({ success: false, message: 'ไม่พบรหัสพนักงานนี้ในระบบ' });
            }

            matchedUser = employee.users[0];

        if (!matchedUser.active || (matchedUser.lockedUntil && matchedUser.lockedUntil > new Date())) {
          return res.status(403).json({ success: false, message: 'บัญชีถูกระงับการใช้งานชั่วคราว' });
        }

        if (!matchedUser.pin || !(await verifyPin(matchedUser.pin, inputPin))) {
          // 🟢 หากหมดเวลาอายัดบัญชีแล้ว ให้เริ่มนับจำนวนครั้งที่ใส่ผิดใหม่จาก 0
          const isLockExpired = matchedUser.lockedUntil && matchedUser.lockedUntil <= new Date();
          const attempts = (isLockExpired ? 0 : (matchedUser.failedLoginAttempts || 0)) + 1;
          let updateData = { failedLoginAttempts: attempts };

          if (attempts >= MAX_LOGIN_ATTEMPTS) {
            updateData.lockedUntil = new Date(Date.now() + LOCK_TIME_MINUTES * 60000);
          }

          await prisma.user.update({
            where: { id: matchedUser.id },
            data: updateData
          });

          if (attempts >= MAX_LOGIN_ATTEMPTS) {
            return res.status(401).json({ success: false, message: `คุณใส่ PIN ผิดเกิน ${MAX_LOGIN_ATTEMPTS} ครั้ง บัญชีถูกระงับ ${LOCK_TIME_MINUTES} นาที` });
          }
          return res.status(401).json({ success: false, message: "รหัส PIN ไม่ถูกต้อง" });
        }

        actualUserId = matchedUser.id;
        actualUserName = employee.fullName || "ไม่ระบุชื่อ";
        actualEmployeeCode = employee.employeeCode;
        assignedRole = matchedUser.role ? matchedUser.role.name : (matchedUser.roles || 'USER');
        assignedDept = employee.position?.department?.departmentName || "ไม่ระบุแผนก";

        if (expectedRole) {
          const expected = expectedRole.toUpperCase();
          const assigned = assignedRole.toUpperCase();
          if (expected === 'SECURITY' || expected === 'GUARD') {
            if (assigned !== 'SECURITY' && assigned !== 'GUARD' && assigned !== 'ADMIN') {
              return res.status(403).json({ success: false, message: 'คุณไม่มีสิทธิ์เข้าถึงผู้ดูแลระบบ' });
            }
          } else if (expected !== assigned) {
            return res.status(403).json({ success: false, message: 'คุณไม่มีสิทธิ์เข้าถึงผู้ดูแลระบบ' });
          }
        }
    } else {
            // 🔐 กรณีไม่ส่ง employeeCode มา ให้ค้นหา User จาก PIN โดยตรง
            const activeUsers = await prisma.user.findMany({
              where: {
                active: true,
                pin: { not: null }
              },
              include: {
                role: true,
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

            matchedUser = null;

        for (const user of activeUsers) {
          if (user.lockedUntil && user.lockedUntil > new Date()) {
            continue;
          }

          if (user.pin && (await verifyPin(user.pin, inputPin))) {
            const userRole = (user.role?.name || user.roles || 'USER').toUpperCase();
            if (expectedRole) {
              const expected = expectedRole.toUpperCase();
              if (expected === 'SECURITY' || expected === 'GUARD') {
                if (userRole !== 'SECURITY' && userRole !== 'GUARD') {
                  continue;
                }
              } else if (expected !== userRole) {
                continue;
              }
            }
            matchedUser = user;
            break;
          }
        }

        if (!matchedUser) {
          return res.status(401).json({
            success: false,
            message: 'รหัส PIN ไม่ถูกต้อง หรือบัญชีถูกระงับ'
          });
        }

        assignedRole = matchedUser.role
          ? matchedUser.role.name
          : (matchedUser.roles || 'USER');

        assignedDept =
          matchedUser.employee?.position?.department?.departmentName ||
          "ไม่ระบุแผนก";

        if (expectedRole) {
          const expected = expectedRole.toUpperCase();
          const assigned = assignedRole.toUpperCase();
          if (expected === 'SECURITY' || expected === 'GUARD') {
            if (assigned !== 'SECURITY' && assigned !== 'GUARD' && assigned !== 'ADMIN') {
              return res.status(403).json({
                success: false,
                message: 'คุณไม่มีสิทธิ์เข้าถึงผู้ดูแลระบบ'
              });
            }
          } else if (expected !== assigned) {
            return res.status(403).json({
              success: false,
              message: 'คุณไม่มีสิทธิ์เข้าถึงผู้ดูแลระบบ'
            });
          }
        }

        console.log("[LOGIN-PIN] Matched User ID:", matchedUser.id);
        console.log("[LOGIN-PIN] Matched Role:", assignedRole);
        console.log("[LOGIN-PIN] Input PIN:", inputPin);
        console.log("[LOGIN-PIN] Has Hash in DB:", !!matchedUser.pin);
        console.log("[LOGIN-PIN] Verify Result:", true);
        console.log("[LOGIN-PIN] Login Success");

        actualUserId = matchedUser.id;
        actualUserName =
          matchedUser.employee?.fullName || "ไม่ระบุชื่อ";
        actualEmployeeCode =
          matchedUser.employee?.employeeCode || "";
    }

    // 🟢 ตรวจสอบเซสชันที่ค้างอยู่ (ถ้ามีเซสชันเดิม และไม่มีการส่ง force=true ให้ตอบ 409 Conflict กลับไป)
    const isForceLogin = force === true || force === 'true';
    if (matchedUser?.currentSessionId && !isForceLogin) {
      return res.status(409).json({
        success: false,
        error: "SESSION_ALREADY_ACTIVE",
        message: "บัญชีนี้กำลังใช้งานอยู่ กรุณาออกจากระบบจากอุปกรณ์เดิมก่อน"
      });
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
          userId: parseInt(actualUserId, 10), 
          action: `เข้าสู่ระบบด้วยรหัส PIN (สิทธิ์: ${assignedRole}, แผนก: ${assignedDept}, ชื่อ: ${actualUserName})`,
          module: "LOGIN_SYSTEM",
          entityId: parseInt(actualUserId, 10),
          entityType: "USER",
          details: "เข้าสู่ระบบผ่านหน้าล็อกอิน PIN"
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
      { expiresIn: '30m' }
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
      // เหมือนกันครับ ถ้ามีรหัสแล้วให้มองว่า Initialize แล้ว
      pinInitialized: user.pinInitialized || (user.pin ? true : false),
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
// 🟢 ถอด authenticateToken ออก และชี้ไปที่ authController.logout เพื่อให้ล้าง Session ได้แม้ Token หมดอายุแล้ว
router.post(['/logout', '/auth/logout'], authController.logout);

// ==========================================
// 🔐 API 6 & 7: PIN Management
// ==========================================
router.post('/setup-pin', authController.setupPin);
router.post('/change-pin', authenticateToken, authController.changePin);
router.post('/admin/users/:id/reset-pin', authenticateToken, isAdmin, authController.resetUserPin);

// ==========================================
// 🔄 API 8: Refresh Token
// ==========================================
router.post(['/refresh', '/auth/refresh'], authenticateToken, authController.refreshToken);

router.isAdmin = isAdmin;
router.isGuard = isGuard;
module.exports = router;