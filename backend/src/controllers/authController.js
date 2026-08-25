const { PrismaClient } = require('@prisma/client');
const { randomUUID: uuidv4 } = require('crypto');
const { hashPin, verifyPin } = require('../services/pinService');
const jwt = require('jsonwebtoken');

const prisma = new PrismaClient();

// ==========================================
// API 1: ตั้งค่า PIN ครั้งแรก (Setup PIN)
// ==========================================
const setupPin = async (req, res) => {
  try {
    const { employeeCode } = req.body;
    
    const rawPin = req.body.pin ?? req.body.newPin;
    const pinStr = rawPin !== undefined && rawPin !== null ? String(rawPin).trim() : '';

    if (!employeeCode) {
      return res.status(400).json({ success: false, error: "ไม่พบข้อมูลรหัสพนักงาน" });
    }

    if (!pinStr || !/^\d{6}$/.test(pinStr)) {
      return res.status(400).json({ success: false, error: "PIN ต้องเป็นตัวเลข 6 หลักเท่านั้น" });
    }
    
    const pin = pinStr;

    // 🟢 ใช้ users: true สำหรับ Include Relation
    const employee = await prisma.employee.findUnique({
      where: { employeeCode: employeeCode },
      include: { users: true }
    });
    
    // 🟢 ตรวจสอบความถูกต้องจาก Array users
    if (!employee || !employee.users || employee.users.length === 0) {
      return res.status(404).json({ success: false, error: "ไม่พบผู้ใช้งานในระบบ" });
    }

    // 🟢 ดึงข้อมูลผู้ใช้จาก Index [0]
    const user = employee.users[0];
    
    if (user.pinInitialized && !user.pinResetRequired) {
      return res.status(400).json({ success: false, error: "คุณได้ตั้งค่า PIN ไปแล้ว" });
    }

    const hashedPin = await hashPin(pin);

    await prisma.user.update({
      where: { id: user.id },
      data: {
        pin: hashedPin,
        pinInitialized: true,
        pinResetRequired: false,
        pinChangedAt: new Date(),
        failedLoginAttempts: 0, 
        lockedUntil: null       
      }
    });

    // 🟢 เพิ่ม AuditLog เมื่อตั้งค่า PIN ครั้งแรกสำเร็จ
    await prisma.auditLog.create({
      data: {
        action: "SETUP_PIN",
        module: "AUTH",
        entityId: parseInt(user.id, 10),
        entityType: "USER",
        userId: parseInt(user.id, 10),
        details: `User ${user.id} initialized their PIN`
      }
    }).catch(err => console.error("AuditLog Error [SETUP_PIN]:", err.message));

    return res.status(200).json({ success: true, message: "ตั้งค่า PIN สำเร็จ" });

  } catch (error) {
    console.error("[setupPin Error]:", error);
    return res.status(500).json({ success: false, error: "เกิดข้อผิดพลาดในการตั้งค่า PIN" });
  }
};

// ==========================================
// API 2: เปลี่ยน PIN (Change PIN)
// ==========================================
const changePin = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { oldPin, newPin } = req.body;

    // 1. Validation Input
    if (!oldPin || !/^\d{6}$/.test(oldPin) || !newPin || !/^\d{6}$/.test(newPin)) {
      return res.status(400).json({ success: false, error: "PIN ต้องเป็นตัวเลข 6 หลักเท่านั้น" });
    }

    const user = await prisma.user.findUnique({ where: { id: userId } });

    if (!user || !user.pin) {
      return res.status(400).json({ success: false, error: "ยังไม่ได้ตั้งค่า PIN กรุณาตั้งค่า PIN ก่อน" });
    }

    // 2. ตรวจสอบ PIN เดิม
    const isOldPinValid = await verifyPin(user.pin, oldPin);
    if (!isOldPinValid) {
      return res.status(401).json({ success: false, error: "รหัส PIN เดิมไม่ถูกต้อง" });
    }

    if (oldPin === newPin) {
      return res.status(400).json({ success: false, error: "รหัส PIN ใหม่ต้องไม่ซ้ำกับของเดิม" });
    }

    // 3. Hash PIN ใหม่
    const hashedNewPin = await hashPin(newPin);
    const newSessionId = uuidv4();

    // 4. บันทึกข้อมูลและ Force Logout
    await prisma.user.update({
      where: { id: userId },
      data: {
        pin: hashedNewPin,
        pinChangedAt: new Date(),
        currentSessionId: newSessionId,
        pinResetRequired: false,
        failedLoginAttempts: 0, // 🟢 เพิ่มการเคลียร์จำนวนครั้งที่เข้าสู่ระบบผิด
        lockedUntil: null       // 🟢 เพิ่มการปลดล็อคบัญชี
      }
    });

    // 🟢 เพิ่ม AuditLog เมื่อเปลี่ยน PIN สำเร็จ
    await prisma.auditLog.create({
      data: {
        action: 'CHANGE_PIN',
        module: 'AUTH',
        userId: parseInt(userId, 10),
        entityId: parseInt(userId, 10),
        entityType: 'USER',
        details: `User ${userId} changed their PIN`
      }
    }).catch(err => console.error("AuditLog Error [changePin]:", err.message));

    return res.status(200).json({ 
      success: true, 
      message: "เปลี่ยน PIN สำเร็จ ระบบจะบังคับให้ออกจากระบบ กรุณาเข้าสู่ระบบใหม่" 
    });

  } catch (error) {
    console.error("[changePin Error]:", error);
    return res.status(500).json({ success: false, error: "เกิดข้อผิดพลาดในการเปลี่ยน PIN" });
  }
};

// ==========================================
// 🛠️ API 3: แอดมินรีเซ็ตรหัส PIN (Admin Reset PIN)
// ==========================================
const resetUserPin = async (req, res) => {
  try {
    const { id } = req.params; 
    const adminId = req.user.userId; 

    const targetUser = await prisma.user.findUnique({
      where: { id: parseInt(id, 10) },
      include: { employee: true }
    });

    if (!targetUser) {
      return res.status(404).json({ success: false, error: "ไม่พบข้อมูลผู้ใช้งานในระบบ" });
    }

    await prisma.user.update({
      where: { id: parseInt(id, 10) },
      data: {
        pin: null, 
        pinInitialized: false, 
        pinResetRequired: true, 
        currentSessionId: null, 
        failedLoginAttempts: 0, 
        lockedUntil: null       
      }
    });

    // 🟢 ปรับเปลี่ยนให้ส่งครบทุก Field ตาม Schema ใหม่ (action, module, userId, entityId, entityType, details)
    await prisma.auditLog.create({
      data: {
        action: "RESET_PIN",
        module: "AUTH",
        entityId: parseInt(targetUser.id, 10),
        entityType: "USER",
        userId: parseInt(adminId, 10),
        details: `Admin ${adminId} reset PIN for User ${targetUser.id} (${targetUser.employee?.fullName || 'Unknown'})`
      }
    }).catch(err => console.error("AuditLog Error [RESET_PIN]:", err.message));

    return res.status(200).json({
      success: true,
      message: `รีเซ็ตรหัส PIN ให้คุณ ${targetUser.employee?.fullName || ''} สำเร็จ ระบบได้บังคับให้ออกจากระบบและปลดล็อกบัญชีแล้ว`
    });

  } catch (error) {
    console.error('Admin Reset PIN Error:', error);
    return res.status(500).json({ success: false, error: "ระบบขัดข้อง ไม่สามารถรีเซ็ตรหัส PIN ได้" });
  }
};

const getPermissionsByRole = (roleName) => {
  const role = (roleName || '').toUpperCase();
  if (role === 'ADMIN') {
    return {
      canExportReport: true,
      canManageSystem: true,
      canCreateRoomBooking: true,
      canCreateVehicleBooking: true,
      canCheckOut: true,
      canCheckIn: true,
    };
  }
  if (role === 'SECURITY' || role === 'GUARD') {
    return {
      canExportReport: false,
      canManageSystem: false,
      canCreateRoomBooking: false,
      canCreateVehicleBooking: false,
      canCheckOut: true,
      canCheckIn: true,
    };
  }
  return {
    canExportReport: false,
    canManageSystem: false,
    canCreateRoomBooking: true,
    canCreateVehicleBooking: true,
    canCheckOut: false,
    canCheckIn: false,
  };
};

// ==========================================
// API 4: เข้าสู่ระบบ (Login) - New Flow
// ==========================================
const login = async (req, res) => {
  try {
    const { employeeCode, pin, expectedRole } = req.body;

    if (!pin) {
      return res.status(400).json({ 
        success: false, 
        error: "กรุณาระบุรหัส PIN" 
      });
    }

    let user = null;
    let employee = null;
    let effectiveRole = 'USER';

    if (employeeCode) {
      // 🟢 กรณีระบุรหัสพนักงาน (User Login Flow: เลือกแผนก/เลือกชื่อ แล้วใส่ PIN)
      // กำหนดสิทธิ์การใช้งานเป็น USER เสมอ เพื่อให้ Admin ที่เข้าหน้านี้ได้เมนูและสิทธิ์ User
      employee = await prisma.employee.findUnique({
        where: { employeeCode: employeeCode },
        include: {
          users: {
            include: { role: true }
          }
        }
      });

      if (!employee || !employee.users || employee.users.length === 0) {
        return res.status(401).json({ success: false, error: "รหัสพนักงานหรือรหัส PIN ไม่ถูกต้อง" });
      }

      user = employee.users[0];

      const userRoleName = user.role?.name ? user.role.name.toUpperCase() : 'USER';
      const requestedRole = expectedRole ? expectedRole.toUpperCase() : 'USER';

      if (requestedRole === 'ADMIN') {
        if (userRoleName !== 'ADMIN') {
          return res.status(403).json({ success: false, error: "ไม่มีสิทธิ์เข้าใช้งานในส่วนแอดมิน" });
        }
        effectiveRole = 'ADMIN';
      } else if (requestedRole === 'SECURITY' || requestedRole === 'GUARD') {
        if (userRoleName !== 'SECURITY' && userRoleName !== 'GUARD' && userRoleName !== 'ADMIN') {
          return res.status(403).json({ success: false, error: "ไม่มีสิทธิ์เข้าใช้งานในส่วน รปภ." });
        }
        // ดึง Role จริงจากฐานข้อมูลมาใช้ เพื่อลดความขัดแย้งระหว่าง SECURITY กับ GUARD
        effectiveRole = userRoleName === 'ADMIN' ? 'ADMIN' : userRoleName;
      } else {
        if (userRoleName === 'SECURITY' || userRoleName === 'GUARD') {
          return res.status(403).json({ success: false, error: "เจ้าหน้าที่ รปภ. ไม่มีสิทธิ์เข้าใช้งานในส่วนผู้ใช้ทั่วไป" });
        }
        effectiveRole = 'USER';
      }
    } else {
      // 🟢 กรณีไม่ระบุรหัสพนักงาน (Admin PIN-Only Login Flow: กรอก PIN อย่างเดียว)
      const targetRole = expectedRole ? expectedRole.toUpperCase() : 'ADMIN';
      
      // รองรับให้ค้นหาเจอทั้งคู่ หากเป้าหมายคือ SECURITY หรือ GUARD
      let roleCondition = { name: targetRole };
      if (targetRole === 'SECURITY' || targetRole === 'GUARD') {
        roleCondition = { name: { in: ['SECURITY', 'GUARD'] } };
      }

      const users = await prisma.user.findMany({
        where: { 
          pin: { not: null },
          active: true,
          role: roleCondition
        },
        include: {
          role: true,
          employee: true
        }
      });

      let lockedCandidate = null;
      for (const candidate of users) {
        if (candidate.pin && await verifyPin(candidate.pin, pin.toString())) {
          if (candidate.lockedUntil && candidate.lockedUntil > new Date()) {
            lockedCandidate = candidate;
            continue; // หาแอดมินคนอื่นที่ใช้ PIN นี้และไม่ถูกล็อคก่อน
          }
          user = candidate;
          employee = candidate.employee;
          effectiveRole = candidate.role?.name ? candidate.role.name.toUpperCase() : targetRole;
          break;
        }
      }

      // ถ้าไม่มีแอดมินที่สถานะปกติ แต่เจอคนที่ถูกล็อค ให้ใช้คนนั้นเพื่อให้ระบบฟ้องว่าบัญชีถูกระงับ
      if (!user && lockedCandidate) {
        user = lockedCandidate;
        employee = lockedCandidate.employee;
        effectiveRole = lockedCandidate.role?.name ? lockedCandidate.role.name.toUpperCase() : targetRole;
      }

      if (!user) {
        return res.status(401).json({ success: false, error: "รหัส PIN ไม่ถูกต้อง หรือไม่มีสิทธิ์เข้าถึงระบบในส่วนนี้" });
      }
    }

    if ((employee && !employee.active) || !user.active) {
      return res.status(403).json({ success: false, error: "บัญชีนี้ถูกระงับการใช้งาน" });
    }

    if (user.lockedUntil && user.lockedUntil > new Date()) {
      const remainingTime = Math.ceil((user.lockedUntil - new Date()) / 60000);
      return res.status(403).json({ 
        success: false, 
        error: `บัญชีถูกระงับชั่วคราวเนื่องจากใส่รหัสผิดเกินกำหนด กรุณาลองใหม่ในอีก ${remainingTime} นาที` 
      });
    }

    if (!user.pin || !user.pinInitialized || user.pinResetRequired) {
      return res.status(403).json({ 
        success: false, 
        error: "บัญชีนี้ยังไม่ได้ตั้งรหัส PIN กรุณาตั้งค่ารหัส PIN ก่อนเข้าใช้งาน",
        requireSetupPin: true 
      });
    }

    if (employeeCode) {
      let currentAttempts = user.failedLoginAttempts || 0;
      if (user.lockedUntil && user.lockedUntil <= new Date()) {
        currentAttempts = 0; // เคลียร์จำนวนครั้งที่ผิดหากหมดเวลาล็อคแล้ว
      }

      const isPinValid = await verifyPin(user.pin, pin.toString());
      if (!isPinValid) {
        const attempts = currentAttempts + 1;
        let updateData = { 
          failedLoginAttempts: attempts,
          ...(user.lockedUntil && user.lockedUntil <= new Date() ? { lockedUntil: null } : {}) // 🟢 เพิ่มการล้างค่าเวลาอายัดเดิมหากหมดเวลาล็อคแล้ว
        };

        if (attempts >= 5) {
          updateData.lockedUntil = new Date(Date.now() + 15 * 60000);
          updateData.currentSessionId = null; // 🔴 เคลียร์ Session ID ทั้งหมดเพื่อยกเลิก Existing Session ของทุก Device ทันทีที่บัญชีถูก Lock
        }

        await prisma.user.update({
          where: { id: user.id },
          data: updateData
        });

        if (attempts >= 5) {
          return res.status(401).json({ success: false, error: `คุณใส่ PIN ผิดเกิน 5 ครั้ง บัญชีถูกระงับ 15 นาที` });
        }
        return res.status(401).json({ success: false, error: "รหัสพนักงานหรือรหัส PIN ไม่ถูกต้อง" });
      }
    }

    const newSessionId = uuidv4(); 
    const userPermissions = getPermissionsByRole(effectiveRole);

    const tokenPayload = {
      userId: user.id,
      employeeCode: employee?.employeeCode || user.employeeCode,
      role: effectiveRole,
      sessionId: newSessionId 
    };

    const token = jwt.sign(
      tokenPayload, 
      process.env.JWT_SECRET,
      { expiresIn: '1d' }
    );

    await prisma.user.update({
      where: { id: user.id },
      data: {
        currentSessionId: newSessionId,
        failedLoginAttempts: 0,
        lockedUntil: null
      }
    });

    // บันทึก AuditLog เมื่อเข้าสู่ระบบสำเร็จ
    await prisma.auditLog.create({
      data: {
        action: "LOGIN_SYSTEM", 
        module: "AUTH",
        entityId: parseInt(user.id, 10),
        entityType: "USER",
        userId: parseInt(user.id, 10),
        details: `เข้าสู่ระบบด้วยรหัส PIN (สิทธิ์: ${effectiveRole})`
      }
    }).catch(err => {
      console.error("❌ AuditLog Error [LOGIN_SYSTEM]:", err.message);
    });

    return res.status(200).json({
      success: true,
      message: "เข้าสู่ระบบสำเร็จ",
      token,
      permissions: userPermissions,
      role: effectiveRole, // ส่ง role ออกมาตรงนี้ด้วย เพื่อให้ Flutter อ่านค่าได้ง่ายขึ้น
      user: {
        id: user.id,
        employeeCode: employee?.employeeCode || user.employeeCode,
        fullName: employee?.fullName || user.fullName,
        role: effectiveRole,
        hasPin: !!(user.pin && user.pinInitialized && !user.pinResetRequired),
        pinInitialized: user.pinInitialized ?? false,
        pinResetRequired: user.pinResetRequired,
        permissions: userPermissions
      }
    });

  } catch (error) {
    console.error("[Login Error]:", error);
    return res.status(500).json({ success: false, error: "เกิดข้อผิดพลาดในการเข้าสู่ระบบ" });
  }
};
module.exports = {
  login,
  loginPin: login,
  setupPin,
  changePin,
  resetUserPin
};