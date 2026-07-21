const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// ==========================================
// 📋 1. ดึงข้อมูลผู้ใช้งานทั้งหมด พร้อมระบบค้นหาและฟิลเตอร์ (GET)
// ==========================================
exports.getAllUsers = async (req, res) => {
  try {
    const { search, role, active } = req.query;

    // สร้างเงื่อนไขการค้นหา (Dynamic Where Clause)
    let whereCondition = {};

    if (search) {
      whereCondition.employee = {
        OR: [
          { employeeCode: { contains: search } },
          { fullName: { contains: search } }
        ]
      };
    }
    
    // ถ้าหน้าบ้านส่ง filter role มา
    if (role) {
      // รองรับทั้งกรณีที่คุณใช้เป็น String (roles) หรือ Relation (role.name)
      whereCondition.OR = [
        { roles: role },
        { role: { name: role } }
      ];
    }

    // ถ้าหน้าบ้านส่ง filter active (true/false) มา
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
      orderBy: { id: 'desc' } // เรียงลำดับจากใหม่ไปเก่า
    });

    // Format ข้อมูลก่อนส่งกลับให้หน้าบ้าน (เพื่อไม่ให้ส่ง Hash PIN หลุดไปเด็ดขาด)
    const formattedUsers = users.map(user => ({
      id: user.id,
      employeeCode: user.employee?.employeeCode,
      fullName: user.employee?.fullName,
      department: user.employee?.position?.department?.departmentName || '-',
      role: user.role ? user.role.name : (user.roles || 'USER'),
      active: user.active,
      pinInitialized: user.pinInitialized,
      pinResetRequired: user.pinResetRequired,
      createdAt: user.createdAt
    }));

    return res.status(200).json({ success: true, data: formattedUsers });
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
    const { employeeCode, roleId, roles, active } = req.body; // รับ roleId (ตาราง relation) หรือ roles (string enum)

    if (!employeeCode) {
      return res.status(400).json({ success: false, error: "กรุณาระบุรหัสพนักงาน" });
    }

    // ตรวจสอบว่าพนักงานมีอยู่จริงไหม
    const employee = await prisma.employee.findUnique({
      where: { employeeCode: String(employeeCode).trim() },
      include: { users: true }
    });

    if (!employee) {
      return res.status(404).json({ success: false, error: "ไม่พบข้อมูลพนักงานรหัสนี้ในระบบ" });
    }

    // ตรวจสอบว่าพนักงานคนนี้มีบัญชีอยู่แล้วหรือยัง
    if (employee.users && employee.users.length > 0) {
      return res.status(400).json({ success: false, error: "พนักงานท่านนี้มีบัญชีผู้ใช้งานในระบบอยู่แล้ว" });
    }

    // สร้างบัญชีใหม่
    const newUser = await prisma.user.create({
      data: {
        employeeId: employee.id,
        roleId: roleId || null,
        roles: roles || 'USER', // กำหนดค่าเริ่มต้นเป็น USER
        active: active !== undefined ? active : true,
        pinInitialized: false, // บังคับให้เป็น false เสมอเพื่อบังคับตั้ง PIN ครั้งแรก
        pinResetRequired: false
      }
    });

    return res.status(201).json({ success: true, message: "สร้างบัญชีผู้ใช้งานสำเร็จ", data: { id: newUser.id } });
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

    // กรณีที่ Admin สั่งระงับบัญชี (active = false) เราควรเตะ Session ออกด้วย
    const dataToUpdate = {
      roleId: roleId !== undefined ? roleId : user.roleId,
      roles: roles !== undefined ? roles : user.roles,
      active: active !== undefined ? active : user.active
    };

    if (active === false) {
      dataToUpdate.currentSessionId = null; // บังคับ Logout ทันทีเมื่อถูกระงับ
    }

    await prisma.user.update({
      where: { id: parseInt(id) },
      data: dataToUpdate
    });

    return res.status(200).json({ success: true, message: "อัปเดตข้อมูลบัญชีผู้ใช้งานสำเร็จ" });
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

    // ลบข้อมูล (Hard Delete)
    await prisma.user.delete({
      where: { id: parseInt(id) }
    });

    return res.status(200).json({ success: true, message: "ลบบัญชีผู้ใช้งานสำเร็จ" });
  } catch (error) {
    console.error('Delete User Error:', error);
    // หากติด Constraint อาจจะต้องแจ้งให้ Soft Delete (เปลี่ยน active = false) แทน
    return res.status(500).json({ success: false, error: "ไม่สามารถลบบัญชีได้ (อาจมีข้อมูลอ้างอิงถึงบัญชีนี้อยู่)" });
  }
};