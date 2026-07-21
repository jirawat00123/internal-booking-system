const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { authenticateToken, requireRole } = require('../middlewares/auth');
const authRoute = require('./auth');
const router = express.Router();
const prisma = new PrismaClient();
const { isAdmin } = authRoute;
const userController = require('../controllers/userController');
// 🔒 Helper Function: ตัดฟิลด์ pin ออกจาก Object เสมอ เพื่อป้องกัน Admin หรือ API รั่วไหลรหัสผ่าน
const sanitizeUser = (user) => {
  if (!user) return null;
  const { pin, ...userWithoutPin } = user;
  return userWithoutPin;
};

// GET /api/Department (รักษา Route เดิมไว้)
router.get('/Department', async (req, res, next) => {
    try {
        const departments = await prisma.user.findMany({
            where: { 
                Department: { not: null } // ไม่เอาช่องว่าง
            },
            distinct: ['Department'], // ดึงมาแค่ชื่อที่ไม่ซ้ำกัน
            select: {
                Department: true
            },
            orderBy: {
                Department: 'asc' // เรียงตัวอักษร ก-ฮ, A-Z
            }
        });

        const deptList = departments.map(d => d.Department);   

        return res.status(200).json({ success: true, data: deptList });
    } catch (error) {
        next(error);
    }
});

// ==========================================
// 👤 Admin User Management APIs (เฉพาะ ADMIN)
// ==========================================

// 1. GET /users - ดู User ทั้งหมด, ค้นหา (search), และ Filter (active, roleId)
router.get('/', authenticateToken, requireRole(['ADMIN']), async (req, res) => {
  try {
    const { search, active, roleId } = req.query;

    const whereCondition = {};

    // Filter สถานะ active
    if (active !== undefined) {
      whereCondition.active = active === 'true';
    }

    // Filter สิทธิ์ roleId
    if (roleId) {
      whereCondition.roleId = parseInt(roleId, 10);
    }

    // Search ชื่อ หรือ รหัสพนักงาน
    if (search) {
      whereCondition.employee = {
        OR: [
          { fullName: { contains: search, mode: 'insensitive' } },
          { employeeCode: { contains: search, mode: 'insensitive' } }
        ]
      };
    }

    const users = await prisma.user.findMany({
      where: whereCondition,
      include: {
        role: true,
        employee: {
          include: {
            position: {
              include: { department: true }
            }
          }
        }
      },
      orderBy: { id: 'desc' }
    });

    // เซ็นเซอร์ PIN ออกจากผู้ใช้ทุกคน
    const safeUsers = users.map(u => sanitizeUser(u));

    return res.status(200).json({ success: true, data: safeUsers });
  } catch (error) {
    console.error('Fetch Users Error:', error);
    return res.status(500).json({ success: false, error: "เกิดข้อผิดพลาดในการดึงข้อมูลผู้ใช้งาน" });
  }
});

// 2. POST /users - เพิ่ม User ใหม่
router.post('/', authenticateToken, requireRole(['ADMIN']), async (req, res) => {
  try {
    const { employeeId, roleId, active } = req.body;

    if (!employeeId || !roleId) {
      return res.status(400).json({ success: false, error: "กรุณาระบุ employeeId และ roleId" });
    }

    // ตรวจสอบว่า Employee นี้มี User อยู่แล้วหรือไม่
    const existingUser = await prisma.user.findFirst({
      where: { employeeId: parseInt(employeeId, 10) }
    });

    if (existingUser) {
      return res.status(400).json({ success: false, error: "พนักงานท่านนี้มี บัญชีผู้ใช้งาน ในระบบอยู่แล้ว" });
    }

    const newUser = await prisma.user.create({
      data: {
        employeeId: parseInt(employeeId, 10),
        roleId: parseInt(roleId, 10),
        active: active !== undefined ? Boolean(active) : true,
        pin: null,
        pinInitialized: false,
        pinResetRequired: true
      },
      include: { role: true, employee: true }
    });

    return res.status(201).json({ 
      success: true, 
      message: "สร้างบัญชีผู้ใช้งานสำเร็จ", 
      data: sanitizeUser(newUser) 
    });
  } catch (error) {
    console.error('Create User Error:', error);
    return res.status(500).json({ success: false, error: "ไม่สามารถเพิ่มผู้ใช้งานได้" });
  }
});

// 3. PUT /users/:id - แก้ไขข้อมูล User / Enable / Disable
router.put('/:id', authenticateToken, requireRole(['ADMIN']), async (req, res) => {
  try {
    const userId = parseInt(req.params.id, 10);
    const { roleId, active } = req.body;

    const updateData = {};
    if (roleId !== undefined) updateData.roleId = parseInt(roleId, 10);
    if (active !== undefined) updateData.active = Boolean(active);

    const updatedUser = await prisma.user.update({
      where: { id: userId },
      data: updateData,
      include: { role: true, employee: true }
    });

    return res.status(200).json({
      success: true,
      message: "อัปเดตข้อมูลผู้ใช้งานสำเร็จ",
      data: sanitizeUser(updatedUser)
    });
  } catch (error) {
    console.error('Update User Error:', error);
    return res.status(500).json({ success: false, error: "ไม่สามารถแก้ไขข้อมูลผู้ใช้งานได้" });
  }
});

// 4. DELETE /users/:id - ลบ User
router.delete('/:id', authenticateToken, requireRole(['ADMIN']), async (req, res) => {
  try {
    const userId = parseInt(req.params.id, 10);

    await prisma.user.delete({
      where: { id: userId }
    });

    return res.status(200).json({ success: true, message: "ลบผู้ใช้งานสำเร็จ" });
  } catch (error) {
    console.error('Delete User Error:', error);
    return res.status(500).json({ success: false, error: "ไม่สามารถลบผู้ใช้งานได้" });
  }
});

// 5. POST /users/:id/reset-pin หรือ /admin/users/:id/reset-pin - Reset PIN
const handleResetPin = async (req, res) => {
  try {
    const userId = parseInt(req.params.id, 10);

    // ล้างค่า PIN, ตั้ง pinInitialized เป็น false, บังคับ reset PIN, และล้าง Session เพื่อให้ Logout ทันที
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

router.post('/:id/reset-pin', authenticateToken, requireRole(['ADMIN']), handleResetPin);
router.post('/admin/users/:id/reset-pin', authenticateToken, requireRole(['ADMIN']), handleResetPin);

// ==========================================
// 🛡️ API ทั้งหมดต้องเป็นแอดมินเท่านั้นจึงจะเรียกใช้ได้
// ==========================================
router.use(authenticateToken, isAdmin);

// 📋 Phase 3: CRUD User Management
router.get('/', userController.getAllUsers);           // ค้นหา/แสดงรายชื่อ
router.post('/', userController.createUser);           // สร้างบัญชีใหม่
router.put('/:id', userController.updateUser);         // แก้ไข Role / เปิด-ปิดบัญชี
router.delete('/:id', userController.deleteUser);      // ลบบัญชี

module.exports = router;