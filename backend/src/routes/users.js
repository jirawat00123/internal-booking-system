const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { authenticateToken, requireRole } = require('../middlewares/auth');
const userController = require('../controllers/userController');

const router = express.Router();
const prisma = new PrismaClient();

// ==========================================
// 🏢 Public / General APIs
// ==========================================

// GET /api/users/Department (รักษา Route เดิมไว้)
router.get('/Department', async (req, res, next) => {
    try {
        const departments = await prisma.user.findMany({
            where: { Department: { not: null } },
            distinct: ['Department'],
            select: { Department: true },
            orderBy: { Department: 'asc' }
        });

        const deptList = departments.map(d => d.Department);   
        return res.status(200).json({ success: true, data: deptList });
    } catch (error) {
        next(error);
    }
});

// ==========================================
// 🛡️ Admin User Management APIs (เฉพาะ ADMIN)
// ==========================================

// ดักจับทุก Route หลังจากบรรทัดนี้ ต้องผ่าน Auth และเป็น Role 'ADMIN' เท่านั้น
router.use(authenticateToken, requireRole(['ADMIN']));

// 📋 CRUD User Management (เรียกผ่าน Controller ตามหลัก MVC)
router.get('/', userController.getAllUsers);           // ค้นหา/แสดงรายชื่อ
router.get('/:id', userController.getUserById);        // 🟢 เพิ่ม: ดึงข้อมูลผู้ใช้งานตาม ID (ตาม Checklist)
router.post('/', userController.createUser);           // สร้างบัญชีใหม่
router.put('/:id', userController.updateUser);         // แก้ไข Role / เปิด-ปิดบัญชี
router.delete('/:id', userController.deleteUser);      // ลบบัญชี

// ==========================================
// 🔑 Reset PIN Management
// ==========================================

// Helper Function สำหรับ Reset PIN (หากย้ายไป Controller แล้ว สามารถลบส่วนนี้ได้)
const sanitizeUser = (user) => {
  if (!user) return null;
  const { pin, ...userWithoutPin } = user;
  return userWithoutPin;
};

const handleResetPin = async (req, res) => {
  try {
    const userId = parseInt(req.params.id, 10);

    const updatedUser = await prisma.user.update({
      where: { id: userId },
      data: {
        pin: null,
        pinInitialized: false,
        pinResetRequired: true,
        currentSessionId: null,
        failedLoginAttempts: 0, // 🟢 เพิ่มการเคลียร์จำนวนครั้งที่เข้าสู่ระบบผิด
        lockedUntil: null       // 🟢 เพิ่มการปลดล็อคบัญชี
      },
      include: { role: true, employee: true }
    });

    // 🟢 เพิ่ม: บันทึก AuditLog เมื่อ Admin ทำการ Reset PIN
    const adminId = req.user?.userId ? parseInt(req.user.userId, 10) : null;
    if (adminId) {
      await prisma.auditLog.create({
        data: {
          action: 'UPDATE_USER',
          module: 'USER_MANAGEMENT',
          userId: adminId,
          entityId: userId,
          entityType: 'USER',
          details: `Admin ID ${adminId} reset PIN for user ID ${userId}`
        }
      }).catch(err => console.error("AuditLog Error [Reset PIN]:", err.message));
    }

    return res.status(200).json({
      success: true,
      message: "รีเซ็ตรหัส PIN สำเร็จ ผู้ใช้จะต้องทำการตั้งรหัส PIN ใหม่ในการใช้งานครั้งถัดไป",
      data: sanitizeUser(updatedUser)
    });
  } catch (error) {
    console.error('Reset PIN Error:', error);
    return res.status(500).json({ success: false, error: "ไม่สามารถรีเซ็ตรหัส PIN ได้" });
  }
};

// Route สำหรับ Reset PIN (รองรับทั้ง PUT และ POST)
router.put('/:id/reset-pin', handleResetPin);
router.post('/:id/reset-pin', handleResetPin);
router.post('/admin/users/:id/reset-pin', handleResetPin);

module.exports = router;