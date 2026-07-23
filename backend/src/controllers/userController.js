const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// 🔒 Helper Function: เซ็นเซอร์ PIN
const sanitizeUser = (user) => {
  if (!user) return null;
  const { pin, ...userWithoutPin } = user;
  return userWithoutPin;
};

// ==========================================
// 📋 1. ดึงข้อมูลผู้ใช้งานทั้งหมด พร้อมระบบค้นหาและฟิลเตอร์ (GET)
// ==========================================
exports.getAllUsers = async (req, res) => {
  try {
    const { search, role, active } = req.query;
    let whereCondition = {};

    if (search) {
      whereCondition.employee = {
        OR: [
          { employeeCode: { contains: search, mode: 'insensitive' } },
          { fullName: { contains: search, mode: 'insensitive' } }
        ]
      };
    }
    
    if (role) {
      whereCondition.OR = [
        { roles: role },
        { role: { name: role } }
      ];
    }

    if (active !== undefined) {
      whereCondition.active = active === 'true';
    }

    const users = await prisma.user.findMany({
      where: whereCondition,
      include: {
        role: true,
        employee: {
          include: {
            position: { include: { department: true } }
          }
        }
      },
      orderBy: { id: 'desc' } 
    });

    // 🟢 แก้ไข: ใช้ sanitizeUser แทนการทำ Flatten ป้องกัน Flutter หาฟิลด์ไม่เจอ
    const safeUsers = users.map(u => sanitizeUser(u));

    return res.status(200).json({ success: true, data: safeUsers });
  } catch (error) {
    console.error('Get Users Error:', error);
    return res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลผู้ใช้งานได้" });
  }
};

// ==========================================
// ➕ 2. เพิ่มบัญชีผู้ใช้งานใหม่ (POST)
// ==========================================
exports.createUser = async (req, res) => {
  try {
    // 🟢 แก้ไข: รองรับทั้ง employeeId (จาก Flutter) และ employeeCode 
    const { employeeId, employeeCode, roleId, roles, active } = req.body; 

    if (!employeeId && !employeeCode) {
      return res.status(400).json({ success: false, error: "กรุณาระบุ employeeId หรือ employeeCode" });
    }

    // 🟢 ค้นหาพนักงานตามข้อมูลที่ส่งมา
    let employee;
    if (employeeId) {
      employee = await prisma.employee.findUnique({
        where: { id: parseInt(employeeId, 10) },
        include: { users: true }
      });
    } else {
      employee = await prisma.employee.findUnique({
        where: { employeeCode: String(employeeCode).trim() },
        include: { users: true }
      });
    }

    if (!employee) {
      return res.status(404).json({ success: false, error: "ไม่พบข้อมูลพนักงานในระบบ" });
    }

    if (employee.users && employee.users.length > 0) {
      return res.status(400).json({ success: false, error: "พนักงานท่านนี้มีบัญชีผู้ใช้งานในระบบอยู่แล้ว" });
    }

    const newUser = await prisma.user.create({
      data: {
        employeeId: employee.id,
        roleId: roleId ? parseInt(roleId, 10) : null,
        roles: roles || 'USER', 
        active: active !== undefined ? Boolean(active) : true,
        pin: null, // เผื่อไว้ป้องกันกรณี DB บังคับ
        pinInitialized: false, 
        pinResetRequired: false
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
    return res.status(500).json({ success: false, error: "ไม่สามารถสร้างบัญชีผู้ใช้งานได้" });
  }
};

// ==========================================
// ✏️ 3. แก้ไขข้อมูลและเปิด/ปิดการใช้งาน User (PUT)
// ==========================================
exports.updateUser = async (req, res) => {
  try {
    const { id } = req.params;
    const { roleId, roles, active } = req.body;

    const user = await prisma.user.findUnique({ where: { id: parseInt(id) } });
    if (!user) {
      return res.status(404).json({ success: false, error: "ไม่พบข้อมูลบัญชีผู้ใช้งาน" });
    }

    const dataToUpdate = {};
    if (roleId !== undefined) dataToUpdate.roleId = parseInt(roleId, 10);
    if (roles !== undefined) dataToUpdate.roles = roles;
    if (active !== undefined) dataToUpdate.active = Boolean(active);

    if (active === false) {
      dataToUpdate.currentSessionId = null; 
    }

    const updatedUser = await prisma.user.update({
      where: { id: parseInt(id) },
      data: dataToUpdate,
      include: { role: true, employee: true }
    });

    return res.status(200).json({ 
      success: true, 
      message: "อัปเดตข้อมูลบัญชีผู้ใช้งานสำเร็จ",
      data: sanitizeUser(updatedUser)
    });
  } catch (error) {
    console.error('Update User Error:', error);
    return res.status(500).json({ success: false, error: "ไม่สามารถอัปเดตข้อมูลได้" });
  }
};

// ==========================================
// ❌ 4. ลบบัญชีผู้ใช้งาน (DELETE)
// ==========================================
exports.deleteUser = async (req, res) => {
  try {
    const { id } = req.params;

    const user = await prisma.user.findUnique({ where: { id: parseInt(id) } });
    if (!user) {
      return res.status(404).json({ success: false, error: "ไม่พบข้อมูลบัญชีผู้ใช้งาน" });
    }

    await prisma.user.delete({
      where: { id: parseInt(id) }
    });

    return res.status(200).json({ success: true, message: "ลบบัญชีผู้ใช้งานสำเร็จ" });
  } catch (error) {
    console.error('Delete User Error:', error);
    return res.status(500).json({ success: false, error: "ไม่สามารถลบบัญชีได้ (อาจมีข้อมูลอ้างอิงอยู่)" });
  }
};