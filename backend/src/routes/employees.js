const express = require('express');
const { PrismaClient } = require('@prisma/client');
const router = express.Router();
const prisma = new PrismaClient();

// ==========================================
// 🏢 1. ข้อมูล Master Data (Departments, Positions, Roles)
// ==========================================

// GET /api/departments - ดึงแผนกทั้งหมด
router.get('/departments', async (req, res) => {
  try {
    const departments = await prisma.department.findMany({
      orderBy: { departmentName: 'asc' }
    });
    return res.status(200).json({ success: true, data: departments });
  } catch (error) {
    console.error("GET /api/departments Error:", error);
    return res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลแผนกได้" });
  }
});

// 🟢 [เพิ่มใหม่] GET /api/positions - ดึงตำแหน่งตามแผนก
router.get('/positions', async (req, res) => {
  try {
    const { departmentId } = req.query;
    if (!departmentId || departmentId === 'null' || departmentId === 'undefined') {
      return res.status(400).json({ success: false, error: 'กรุณาระบุ departmentId' });
    }
    const positions = await prisma.position.findMany({
      where: { departmentId: parseInt(departmentId, 10) },
      orderBy: { positionName: 'asc' }
    });
    return res.status(200).json({ success: true, data: positions });
  } catch (error) {
    console.error("GET /api/positions Error:", error);
    return res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลตำแหน่งได้" });
  }
});

// 🟢 [เพิ่มใหม่] GET /api/roles - ดึงสิทธิ์การใช้งานทั้งหมด
router.get('/roles', async (req, res) => {
  try {
    const roles = await prisma.role.findMany({
      orderBy: { id: 'asc' }
    });
    return res.status(200).json({ success: true, data: roles });
  } catch (error) {
    console.error("GET /api/roles Error:", error);
    return res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลสิทธิ์ได้" });
  }
});


// ==========================================
// 👥 2. ข้อมูล Employees (พนักงาน)
// ==========================================

// 🟢 [เพิ่มใหม่] GET /api/employees/generate-code - สร้างรหัสพนักงานใหม่
// ⚠️ ต้องวางไว้ก่อน /employees/:id เสมอ เพื่อไม่ให้ Express มองว่า 'generate-code' คือ id
router.get('/employees/generate-code', async (req, res) => {
  try {
    const lastEmployee = await prisma.employee.findFirst({
      orderBy: { id: 'desc' },
    });
    
    let nextNumber = 1;
    if (lastEmployee && lastEmployee.employeeCode && lastEmployee.employeeCode.startsWith('EMP-')) {
      const lastNumber = parseInt(lastEmployee.employeeCode.replace('EMP-', ''), 10);
      if (!isNaN(lastNumber)) nextNumber = lastNumber + 1;
    }
    
    const newCode = `EMP-${String(nextNumber).padStart(3, '0')}`;
    return res.status(200).json({ success: true, code: newCode });
  } catch (error) {
    console.error("GET /api/employees/generate-code Error:", error);
    return res.status(500).json({ success: false, error: "ไม่สามารถสร้างรหัสพนักงานได้" });
  }
});

// GET /api/employees - ดึงพนักงานทั้งหมด
router.get('/employees', async (req, res) => {
  try {
    const { departmentId } = req.query;
    const whereClause = {};

    if (departmentId && departmentId !== 'undefined' && departmentId !== 'null') {
      const parsedId = !isNaN(Number(departmentId)) ? Number(departmentId) : departmentId;
      whereClause.position = { departmentId: parsedId };
    }

    const employees = await prisma.employee.findMany({
      where: whereClause,
      include: {
        position: { include: { department: true } },
        users: { include: { role: true } }
      },
      orderBy: { employeeCode: 'asc' }
    });

    const result = employees.map(emp => {
      const userAcc = emp.users && emp.users.length > 0 ? emp.users[0] : null;
      return {
        id: emp.id,
        employeeCode: emp.employeeCode,
        fullName: emp.fullName,
        departmentId: emp.position?.departmentId,
        departmentName: emp.position?.department?.departmentName || "ไม่ระบุแผนก",
        positionName: emp.position?.positionName || "ไม่ระบุตำแหน่ง",
        role: userAcc?.role?.name || "USER",
        active: userAcc?.active ?? true,
        userId: userAcc?.id ?? null
      };
    });

    return res.status(200).json({ success: true, data: result });
  } catch (error) {
    console.error("GET /api/employees Error:", error);
    return res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลพนักงานได้" });
  }
});

// 🟢 [เพิ่มใหม่] POST /api/employees - สร้างพนักงานใหม่และ User (Transaction)
// POST /api/employees - สร้างพนักงานใหม่และ User (Transaction)
router.post('/employees', async (req, res) => {
  // 1. รับค่าจาก req.body ทั้งหมด (ห้าม Hardcode)
  const { employeeCode, fullName, departmentId, positionId, roleId, active } = req.body;

  // 2. Validation: ตรวจสอบข้อมูลเบื้องต้น
  if (!employeeCode || !fullName || !departmentId || !positionId || !roleId) {
    return res.status(400).json({ success: false, error: 'กรุณาส่งข้อมูลให้ครบถ้วน (employeeCode, fullName, departmentId, positionId, roleId)' });
  }

  try {
    const parsedDeptId = parseInt(departmentId, 10);
    const parsedPosId = parseInt(positionId, 10);
    const parsedRoleId = parseInt(roleId, 10);
    // แปลงค่า active ให้เป็น Boolean (ถ้าไม่ได้ส่งมาให้ default เป็น true)
    const isActiveStatus = active !== undefined ? Boolean(active) : true;

    // 3. API Validation: ตรวจสอบความถูกต้องของข้อมูลในฐานข้อมูลจริง (PostgreSQL)
    // 3.1 เช็กว่า Department มีอยู่จริง
    const deptExists = await prisma.department.findUnique({ where: { id: parsedDeptId } });
    if (!deptExists) {
      return res.status(400).json({ success: false, error: 'ไม่พบข้อมูลแผนก (Department) นี้ในระบบ' });
    }

    // 3.2 เช็กว่า Position มีอยู่จริง
    const posExists = await prisma.position.findUnique({ where: { id: parsedPosId } });
    if (!posExists) {
      return res.status(400).json({ success: false, error: 'ไม่พบข้อมูลตำแหน่ง (Position) นี้ในระบบ' });
    }

    // 3.3 เช็กว่า Position อยู่ใน Department นั้นจริง
    if (posExists.departmentId !== parsedDeptId) {
      return res.status(400).json({ success: false, error: 'ตำแหน่งที่เลือกไม่ได้สังกัดอยู่ในแผนกที่ระบุ' });
    }

    // 3.4 เช็กว่า Role มีอยู่จริง
    const roleExists = await prisma.role.findUnique({ where: { id: parsedRoleId } });
    if (!roleExists) {
      return res.status(400).json({ success: false, error: 'ไม่พบข้อมูลสิทธิ์การใช้งาน (Role) นี้ในระบบ' });
    }

    // 4. สร้างข้อมูลลง PostgreSQL ด้วย Prisma Transaction
    const result = await prisma.$transaction(async (tx) => {
      // 4.1 สร้าง Employee (ใส่ข้อมูลให้ครบตาม Schema)
      const newEmployee = await tx.employee.create({
        data: {
          employeeCode: employeeCode.trim(),
          fullName: fullName.trim(),
          departmentId: parsedDeptId, // ✅ ใส่ค่า departmentId ที่ขาดหายไปแล้ว
          positionId: parsedPosId,
          isActive: isActiveStatus,
        }
      });

      // 4.2 สร้าง User ผูกกับ Employee
      const newUser = await tx.user.create({
        data: {
          employeeId: newEmployee.id,
          roleId: parsedRoleId,
          active: isActiveStatus,
          // ฟิลด์อื่นๆ จะถูกใช้ Default value ตาม Prisma Schema
        }
      });

      return { newEmployee, newUser };
    });

    // 5. ส่ง Response กลับ
    return res.status(201).json({ 
      success: true, 
      message: 'สร้างข้อมูลพนักงานและบัญชีผู้ใช้สำเร็จ', 
      data: result.newEmployee 
    });

  } catch (error) {
    console.error('POST /api/employees Error:', error);
    
    // ดักจับ Error กรณี employeeCode ซ้ำ (Unique Constraint)
    if (error.code === 'P2002') {
      return res.status(400).json({ success: false, error: 'รหัสพนักงานนี้มีอยู่ในระบบแล้ว' });
    }
    
    return res.status(500).json({ success: false, error: 'ระบบหลังบ้านขัดข้อง ไม่สามารถบันทึกข้อมูลได้' });
  }
});

// PUT /api/employees/:id - อัปเดตข้อมูลพนักงาน
router.put('/employees/:id', async (req, res) => {
  try {
    const employeeId = parseInt(req.params.id, 10);
    if (isNaN(employeeId)) {
      return res.status(400).json({ success: false, error: "รหัสพนักงานไม่ถูกต้อง" });
    }

    const { employeeCode, fullName, positionId, departmentId, isActive, roleId, active } = req.body;

    const existingEmployee = await prisma.employee.findUnique({
      where: { id: employeeId },
      include: { users: true }
    });

    if (!existingEmployee) {
      return res.status(404).json({ success: false, error: "ไม่พบข้อมูลพนักงานที่ต้องการอัปเดต" });
    }

    const updatedData = await prisma.$transaction(async (tx) => {
      const empUpdate = await tx.employee.update({
        where: { id: employeeId },
        data: {
          ...(employeeCode && { employeeCode: employeeCode.trim() }),
          ...(fullName && { fullName: fullName.trim() }),
          ...(positionId && { positionId: parseInt(positionId, 10) }),
          ...(departmentId && { departmentId: parseInt(departmentId, 10) }),
          ...(isActive !== undefined && { isActive }),
        }
      });

      if ((roleId || active !== undefined) && existingEmployee.users.length > 0) {
        const userId = existingEmployee.users[0].id;
        await tx.user.update({
          where: { id: userId },
          data: {
            ...(roleId && { roleId: parseInt(roleId, 10) }),
            ...(active !== undefined && { 
              active: Boolean(active),
              ...(Boolean(active) ? { failedLoginAttempts: 0, lockedUntil: null } : { currentSessionId: null }) // 🟢 หากเปิดใช้งานบัญชี ให้ปลดล็อคและรีเซ็ตจำนวนครั้งที่ผิด
            })
          }
        });
      }

      return empUpdate;
    });

    return res.status(200).json({ 
      success: true, 
      message: "อัปเดตข้อมูลพนักงานสำเร็จ", 
      data: updatedData 
    });

  } catch (error) {
    console.error("PUT /api/employees/:id Error:", error);
    if (error.code === 'P2002') {
      return res.status(409).json({ success: false, error: "รหัสพนักงานนี้ถูกใช้งานในระบบแล้ว" });
    }
    return res.status(500).json({ success: false, error: "ระบบหลังบ้านขัดข้อง ไม่สามารถอัปเดตข้อมูลได้" });
  }
});

module.exports = router;