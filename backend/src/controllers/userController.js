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
    // 🟢 ดึงเฉพาะรายการที่ยังไม่ถูกลบ (isDeleted: false) ดึงทั้ง active: true และ active: false
    let whereCondition = {
      isDeleted: false
    };

    if (search) {
      whereCondition.employee = {
        OR: [
          { employeeCode: { contains: search, mode: 'insensitive' } },
          { fullName: { contains: search, mode: 'insensitive' } }
        ]
      };
    }
    
    if (role) {
      whereCondition.role = { name: role };
    }

    if (active !== undefined) {
      whereCondition.active = active === 'true';
    }

    // 🟢 เพิ่ม Filter กรองตามแผนก (Department)
    const { department } = req.query;
    if (department) {
      whereCondition.employee = {
        ...whereCondition.employee,
        position: {
          department: {
            name: { contains: department, mode: 'insensitive' } 
          }
        }
      };
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

    const safeUsers = users.map(u => sanitizeUser(u));

    return res.status(200).json({ success: true, data: safeUsers });
  } catch (error) {
    console.error('Get Users Error:', error);
    return res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลผู้ใช้งานได้" });
  }
};

// ==========================================
// 🔍 1.5 ดึงข้อมูลผู้ใช้งานตาม ID (GET By ID)
// ==========================================
exports.getUserById = async (req, res) => {
  try {
    const { id } = req.params;
    const user = await prisma.user.findUnique({
      where: { id: parseInt(id, 10) },
      include: {
        role: true,
        employee: {
          include: {
            position: { include: { department: true } }
          }
        }
      }
    });

    if (!user) {
      return res.status(404).json({ success: false, error: "ไม่พบข้อมูลบัญชีผู้ใช้งาน" });
    }

    return res.status(200).json({ success: true, data: sanitizeUser(user) });
  } catch (error) {
    console.error('Get User By ID Error:', error);
    return res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลผู้ใช้งานได้" });
  }
};

// ==========================================
// ➕ 2. เพิ่มบัญชีผู้ใช้งานใหม่ (POST)
// ==========================================
exports.createUser = async (req, res) => {
  try {
    const { employeeCode, fullName, departmentId, positionId, roleId, active } = req.body;

    if (!employeeCode || !fullName || !departmentId || !positionId) {
      return res.status(400).json({ 
        success: false, 
        error: "กรุณากรอกข้อมูลพนักงาน (รหัสพนักงาน, ชื่อ-นามสกุล, แผนก, ตำแหน่ง) ให้ครบถ้วน" 
      });
    }

    const cleanEmpCode = String(employeeCode).trim();

    // 1. ตรวจสอบว่ารหัสพนักงานนี้มีบัญชีผู้ใช้งานอยู่แล้วหรือไม่
    const existingEmployee = await prisma.employee.findUnique({
      where: { employeeCode: cleanEmpCode },
      include: { users: true }
    });

    if (existingEmployee && existingEmployee.users && existingEmployee.users.length > 0) {
      return res.status(400).json({ success: false, error: "รหัสพนักงานนี้มีบัญชีผู้ใช้งานในระบบอยู่แล้ว" });
    }

    // 2. สร้างข้อมูล พนักงาน และ บัญชีผู้ใช้งาน ไปพร้อมกันใน Transaction
    const newUser = await prisma.$transaction(async (tx) => {
      let employee = existingEmployee;

      if (!employee) {
        employee = await tx.employee.create({
          data: {
            employeeCode: cleanEmpCode,
            fullName: String(fullName).trim(),
            departmentId: parseInt(departmentId, 10),
            positionId: parseInt(positionId, 10),
            isActive: active !== undefined ? Boolean(active) : true
          }
        });
      }

      return await tx.user.create({
        data: {
          employeeId: employee.id,
          roleId: roleId ? parseInt(roleId, 10) : 2, // 2 คือ USER
          active: active !== undefined ? Boolean(active) : true,
          pin: null,
          pinInitialized: false,
          pinResetRequired: false
        },
        include: {
          role: true,
          employee: {
            include: {
              position: { include: { department: true } }
            }
          }
        }
      });
    });

    // 🟢 บันทึก AuditLog เมื่อสร้างผู้ใช้งานสำเร็จ (รองรับทั้ง userId และ id จาก Token)
    const adminId = (req.user?.userId || req.user?.id) ? parseInt(req.user.userId || req.user.id, 10) : null;
    if (adminId) {
await prisma.auditLog.create({
        data: {
          action: "CREATE_USER",
          module: "USER_MANAGEMENT",
          entityId: newUser.id,
          entityType: "USER",
          userId: adminId,
          details: `Admin ID ${adminId} created user ID ${newUser.id} for employee ID ${newUser.employeeId}`
        }
      }).catch(err => console.error("AuditLog Error [CREATE_USER]:", err.message));
    }

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
    const { roleId, roles, active, employeeCode, fullName, departmentId, positionId } = req.body;

    const user = await prisma.user.findUnique({ where: { id: parseInt(id) } });
    if (!user) {
      return res.status(404).json({ success: false, error: "ไม่พบข้อมูลบัญชีผู้ใช้งาน" });
    }

    const dataToUpdate = {};
    
    // 🟢 แก้ไขเป็นการใช้ connect และตรวจสอบค่า null/undefined อย่างรัดกุม
    if (roleId !== undefined && !isNaN(parseInt(roleId, 10))) {
      dataToUpdate.role = { connect: { id: parseInt(roleId, 10) } };
    }
    
    // 🟢 (ลบ dataToUpdate.roles ออก เนื่องจากไม่มีฟิลด์นี้ในตาราง User)
    
    if (active !== undefined) {
      dataToUpdate.active = Boolean(active);
      if (active === true) {
        dataToUpdate.failedLoginAttempts = 0; // 🟢 ปลดล็อคและรีเซ็ตจำนวนครั้งที่เข้าสู่ระบบผิดเมื่อเปิดใช้งานบัญชี
        dataToUpdate.lockedUntil = null;
      } else {
        dataToUpdate.currentSessionId = null; 
      }
    }

    // 🟢 อัปเดตข้อมูลในตาราง Employee (รวมถึงสถานะ isActive) ลง Database
    const employeeData = {};
    if (active !== undefined) employeeData.isActive = Boolean(active);
    if (employeeCode) employeeData.employeeCode = String(employeeCode).trim();
    if (fullName) employeeData.fullName = String(fullName).trim();
    if (departmentId) employeeData.departmentId = parseInt(departmentId, 10);
    if (positionId) employeeData.positionId = parseInt(positionId, 10);

    if (Object.keys(employeeData).length > 0) {
      dataToUpdate.employee = {
        update: employeeData
      };
    }

    // 🟢 แปลงเป็น Int ตั้งแต่ตรงนี้ (รองรับทั้ง userId และ id จาก Token)
    const adminId = (req.user?.userId || req.user?.id) ? parseInt(req.user.userId || req.user.id, 10) : null;
    if (adminId === parseInt(id) && (roleId !== undefined || roles !== undefined)) {
      return res.status(403).json({ success: false, error: "ไม่สามารถแก้ไขสิทธิ์การใช้งาน (Role) ของตัวเองได้" });
    }

    const updatedUser = await prisma.user.update({
      where: { id: parseInt(id) },
      data: dataToUpdate,
      include: { role: true, employee: true }
    });

    // 🟢 บันทึก AuditLog แยกตามประเภท (Change Role, Activate, Deactivate, Update)
    // (ลบการประกาศ const adminId ซ้ำทิ้งไป ใช้ตัวแปรจากด้านบนแทน)
    if (adminId) {
      let actionType = 'UPDATE_USER';
      let actionDetails = `Admin ID ${adminId} updated settings for user ID ${updatedUser.id}`;

      if (active === true && user.active === false) {
        actionType = 'ACTIVATE_USER';
        actionDetails = `Admin ID ${adminId} activated user ID ${updatedUser.id}`;
      } else if (active === false && user.active === true) {
        actionType = 'DEACTIVATE_USER';
        actionDetails = `Admin ID ${adminId} deactivated user ID ${updatedUser.id}`;
      } else if (roleId !== undefined && roleId !== user.roleId) {
        actionType = 'CHANGE_ROLE';
        actionDetails = `Admin ID ${adminId} changed role for user ID ${updatedUser.id} to Role ID ${roleId}`;
      }

      await prisma.auditLog.create({
        data: {
          action: actionType,
          module: 'USER_MANAGEMENT',
          userId: adminId,
          entityId: updatedUser.id,
          entityType: 'USER',
          details: actionDetails
        }
      }).catch(err => console.error("AuditLog Error [updateUser]:", err.message));
    }

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

// 🟢 ทำ Soft Delete: ตั้งค่า isDeleted: true และอัปเดตสถานะทั้ง User และ Employee เป็น false
    await prisma.user.update({
      where: { id: parseInt(id) },
      data: { 
        isDeleted: true,
        active: false,
        currentSessionId: null,
        employee: {
          update: {
            isActive: false
          }
        }
      }
    });

    // 🟢 บันทึก AuditLog เมื่อลบผู้ใช้งานสำเร็จ (รองรับทั้ง userId และ id จาก Token)
    const adminId = (req.user?.userId || req.user?.id) ? parseInt(req.user.userId || req.user.id, 10) : null;
    if (adminId) {
      await prisma.auditLog.create({
        data: {
          action: 'DELETE_USER',
          module: 'USER_MANAGEMENT',
          userId: adminId,
          entityId: parseInt(id),
          entityType: 'USER',
          details: `Admin ID ${adminId} deleted user ID ${id}`
        }
      }).catch(err => console.error("AuditLog Error [deleteUser]:", err.message));
    }

    return res.status(200).json({ success: true, message: "ลบบัญชีผู้ใช้งานสำเร็จ" });
  } catch (error) {
    console.error('Delete User Error:', error);
    return res.status(500).json({ success: false, error: "ไม่สามารถลบบัญชีได้ (อาจมีข้อมูลอ้างอิงอยู่)" });
  }
};