const { PrismaClient } = require('@prisma/client');
const { v4: uuidv4 } = require('uuid');
const { hashPin, verifyPin } = require('../services/pinService');

const prisma = new PrismaClient();

// ==========================================
// API: ตั้งค่า PIN ครั้งแรก (Setup PIN)
// ==========================================
const setupPin = async (req, res) => {
  try {
    // ดึง userId มาจาก Token ที่แนบมา (middleware auth.js ยัดไว้ใน req.user)
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

    // 3. นำ PIN ไป Hash ด้วย Argon2id + HMAC-Pepper
    const hashedPin = await hashPin(pin);

    // 4. บันทึกลงฐานข้อมูล
    await prisma.user.update({
      where: { id: userId },
      data: {
        pin: hashedPin,
        pinInitialized: true,
        pinResetRequired: false, // ปลดล็อกสถานะบังคับตั้ง PIN
        pinChangedAt: new Date()
      }
    });

    return res.status(200).json({ success: true, message: "ตั้งค่า PIN สำเร็จ" });

  } catch (error) {
    console.error("[setupPin Error]:", error);
    return res.status(500).json({ success: false, error: "เกิดข้อผิดพลาดในการตั้งค่า PIN" });
  }
};

// ==========================================
// API: เปลี่ยน PIN (Change PIN)
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

    // 2. ตรวจสอบ PIN เดิมว่าถูกต้องหรือไม่
    const isOldPinValid = await verifyPin(oldPin, user.pin);
    if (!isOldPinValid) {
      return res.status(401).json({ success: false, error: "รหัส PIN เดิมไม่ถูกต้อง" });
    }

    // (Option เสริม) ป้องกันการตั้ง PIN ใหม่ให้ซ้ำกับของเดิม
    if (oldPin === newPin) {
      return res.status(400).json({ success: false, error: "รหัส PIN ใหม่ต้องไม่ซ้ำกับของเดิม" });
    }

    // 3. นำ PIN ใหม่ไป Hash
    const hashedNewPin = await hashPin(newPin);

    // 4. สร้าง Session ID ใหม่ เพื่อทำลาย Session เก่าทั้งหมด (Force Logout ทุกอุปกรณ์)
    const newSessionId = uuidv4();

    // 5. บันทึกข้อมูลและ Invalidate Session
    await prisma.user.update({
      where: { id: userId },
      data: {
        pin: hashedNewPin,
        pinChangedAt: new Date(),
        currentSessionId: newSessionId, // 👈 เปลี่ยน Session ID ทำให้ Token เก่าที่ถืออยู่พังทันที
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
// 🛠️ 3. แอดมินรีเซ็ตรหัส PIN (Admin Reset PIN)
// ==========================================
exports.resetUserPin = async (req, res) => {
  try {
    const { id } = req.params; // รับ ID ของผู้ใช้เป้าหมายจาก URL
    const adminId = req.user.userId; // ID ของแอดมินที่เรียกใช้งาน API นี้

    // 1. ค้นหาผู้ใช้งานเป้าหมายในระบบ
    const targetUser = await prisma.user.findUnique({
      where: { id: parseInt(id) },
      include: { employee: true }
    });

    if (!targetUser) {
      return res.status(404).json({ success: false, error: "ไม่พบข้อมูลผู้ใช้งานในระบบ" });
    }

    // 2. 💾 อัปเดตข้อมูลผู้ใช้: ล้างรหัส PIN เดิมทิ้ง และเปลี่ยนสถานะเพื่อบังคับตั้งรหัสใหม่
    await prisma.user.update({
      where: { id: parseInt(id) },
      data: {
        pin: null, // ล้างค่า PIN
        pinInitialized: false, // เปลี่ยนสถานะว่ายังไม่ได้ตั้งค่า
        pinResetRequired: true, // บังคับให้ตั้งค่าใหม่เมื่อเข้าสู่ระบบครั้งหน้า
        currentSessionId: null // บังคับให้ผู้ใช้นั้นหลุดออกจากระบบทุกอุปกรณ์ทันที
      }
    });

    // 3. 📝 บันทึกประวัติการทำงาน (Audit Log) ของแอดมิน
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
      message: `รีเซ็ตรหัส PIN ให้คุณ ${targetUser.employee?.fullName || ''} สำเร็จ และระบบได้บังคับให้ผู้ใช้ออกจากระบบแล้ว`
    });

  } catch (error) {
    console.error('Admin Reset PIN Error:', error);
    return res.status(500).json({ success: false, error: "ระบบขัดข้อง ไม่สามารถรีเซ็ตรหัส PIN ได้" });
  }
};

module.exports = {
  setupPin,
  changePin
};