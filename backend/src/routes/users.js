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
        currentSessionId: null 
      },
      include: { role: true, employee: true }
    });

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

// Route สำหรับ Reset PIN
router.post('/:id/reset-pin', handleResetPin);
router.post('/admin/users/:id/reset-pin', handleResetPin);

module.exports = router;