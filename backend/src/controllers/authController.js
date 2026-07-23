const { PrismaClient } = require('@prisma/client');
const { v4: uuidv4 } = require('uuid');
const { hashPin, verifyPin } = require('../services/pinService');

const prisma = new PrismaClient();

// ==========================================
// API 1: ตั้งค่า PIN ครั้งแรก (Setup PIN)
// ==========================================
const setupPin = async (req, res) => {
  try {
    const userId = req.user.userId; 
    const { pin } = req.body;

    // 1. Validation Input
    if (!pin || !/^\d{6}$/.test(pin)) {
      return res.status(400).json({ success: false, error: "PIN ต้องเป็นตัวเลข 6 หลักเท่านั้น" });
    }

    // 2. เช็คข้อมูลผู้ใช้และสถานะการตั้ง PIN
    const user = await prisma.user.findUnique({ where: { id: userId } });
    
    if (!user) {
      return res.status(404).json({ success: false, error: "ไม่พบผู้ใช้งาน" });
    }
    
    // ถ้าตั้ง PIN ไปแล้ว และไม่ได้ถูก Admin สั่งให้บังคับเปลี่ยนใหม่
    if (user.pinInitialized && !user.pinResetRequired) {
      return res.status(400).json({ success: false, error: "คุณได้ตั้งค่า PIN ไปแล้ว" });
    }

    // 3. นำ PIN ไป Hash
    const hashedPin = await hashPin(pin);

    // 4. บันทึกลงฐานข้อมูล
    await prisma.user.update({
      where: { id: userId },
      data: {
        pin: hashedPin,
        pinInitialized: true,
        pinResetRequired: false,
        pinChangedAt: new Date(),
        failedLoginAttempts: 0, // ✅ คืนค่าการล็อคบัญชี (ถ้ามี)
        lockedUntil: null       // ✅ ปลดล็อกบัญชี
      }
    });

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
    const isOldPinValid = await verifyPin(oldPin, user.pin);
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
        pinResetRequired: false
      }
    });

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
// 💡 แก้ไข: เปลี่ยนจาก exports.resetUserPin เป็น const เพื่อให้ Export พร้อมกันตอนท้ายไฟล์
const resetUserPin = async (req, res) => {
  try {
    const { id } = req.params; 
    const adminId = req.user.userId; 

    const targetUser = await prisma.user.findUnique({
      where: { id: parseInt(id) },
      include: { employee: true }
    });

    if (!targetUser) {
      return res.status(404).json({ success: false, error: "ไม่พบข้อมูลผู้ใช้งานในระบบ" });
    }

    // 💡 แก้ไข: เพิ่มฟิลด์ปลดล็อกบัญชี (failedLoginAttempts, lockedUntil)
    await prisma.user.update({
      where: { id: parseInt(id) },
      data: {
        pin: null, 
        pinInitialized: false, 
        pinResetRequired: true, 
        currentSessionId: null, 
        failedLoginAttempts: 0, // ✅ ปลดล็อกบัญชีให้พนักงาน
        lockedUntil: null       // ✅ ปลดล็อกบัญชีให้พนักงาน
      }
    });

    try {
      await prisma.auditLog.create({
        data: {
          userId: adminId,
          action: `รีเซ็ตรหัส PIN ให้กับผู้ใช้งาน: ${targetUser.employee?.fullName || 'ไม่ทราบชื่อ'} (User ID: ${targetUser.id})`,
          module: 'ADMIN_SYSTEM'
        }
      });
    } catch (logError) {
      console.error("⚠️ ไม่สามารถบันทึก Log การรีเซ็ต PIN ได้:", logError.message);
    }

    return res.status(200).json({
      success: true,
      message: `รีเซ็ตรหัส PIN ให้คุณ ${targetUser.employee?.fullName || ''} สำเร็จ ระบบได้บังคับให้ออกจากระบบและปลดล็อกบัญชีแล้ว`
    });

  } catch (error) {
    console.error('Admin Reset PIN Error:', error);
    return res.status(500).json({ success: false, error: "ระบบขัดข้อง ไม่สามารถรีเซ็ตรหัส PIN ได้" });
  }
};

// 💡 แก้ไข: รวบรวมฟังก์ชันทั้งหมดมา Export ที่จุดเดียว เพื่อป้องกัน Bug ฟังก์ชันหาย
module.exports = {
  setupPin,
  changePin,
  resetUserPin
};