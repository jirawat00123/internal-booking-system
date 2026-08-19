const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// 1. GET /api/departments (ดึงแผนกทั้งหมด)
exports.getDepartments = async (req, res) => {
  try {
    const departments = await prisma.department.findMany({
      orderBy: { id: 'asc' }
    });
    res.status(200).json({ success: true, data: departments });
  } catch (error) {
    console.error('Error fetching departments:', error);
    res.status(500).json({ success: false, error: 'ไม่สามารถดึงข้อมูลแผนกได้' });
  }
};

// 2. GET /api/positions?departmentId=... (ดึงตำแหน่งตามแผนก)
exports.getPositions = async (req, res) => {
  try {
    const { departmentId } = req.query;
    if (!departmentId || departmentId === 'null' || departmentId === 'undefined') {
      return res.status(400).json({ success: false, error: 'กรุณาระบุ departmentId' });
    }
    const positions = await prisma.position.findMany({
      where: { departmentId: parseInt(departmentId, 10) },
      orderBy: { id: 'asc' }
    });
    res.status(200).json({ success: true, data: positions });
  } catch (error) {
    console.error('Error fetching positions:', error);
    res.status(500).json({ success: false, error: 'ไม่สามารถดึงข้อมูลตำแหน่งได้' });
  }
};

// 3. GET /api/roles (ดึงสิทธิ์การใช้งานทั้งหมด)
exports.getRoles = async (req, res) => {
  try {
    const roles = await prisma.role.findMany({
      orderBy: { id: 'asc' }
    });
    res.status(200).json({ success: true, data: roles });
  } catch (error) {
    console.error('Error fetching roles:', error);
    res.status(500).json({ success: false, error: 'ไม่สามารถดึงข้อมูลสิทธิ์การใช้งานได้' });
  }
};

// 4. GET /api/employees/generate-code (สร้างรหัสพนักงานใหม่)
exports.generateEmployeeCode = async (req, res) => {
  try {
    // หาพนักงานคนล่าสุดเพื่อรันเลข Code ถัดไป (รูปแบบ: EMP-001)
    const lastEmployee = await prisma.employee.findFirst({
      orderBy: { id: 'desc' },
    });
    
    let nextNumber = 1;
    if (lastEmployee && lastEmployee.employeeCode && lastEmployee.employeeCode.startsWith('EMP-')) {
      const lastNumber = parseInt(lastEmployee.employeeCode.replace('EMP-', ''), 10);
      if (!isNaN(lastNumber)) nextNumber = lastNumber + 1;
    }
    
    const newCode = `EMP-${String(nextNumber).padStart(3, '0')}`;
    res.status(200).json({ success: true, code: newCode });
  } catch (error) {
    console.error('Error generating employee code:', error);
    res.status(500).json({ success: false, error: 'ไม่สามารถสร้างรหัสพนักงานได้' });
  }
};

// 5. POST /api/employees (สร้าง Employee พร้อม User ใน Transaction เดียว)
exports.createEmployeeWithUser = async (req, res) => {
  const { employeeCode, fullName, departmentId, positionId, roleId, active } = req.body;

  // --- 1. Validation เบื้องต้น ---
  if (!fullName || !departmentId || !positionId || !roleId || !employeeCode) {
    return res.status(400).json({ success: false, error: 'กรุณาส่งข้อมูลให้ครบถ้วน' });
  }

  try {
    // --- 2. ตรวจสอบความถูกต้องของข้อมูล (Foreign Keys) ---
    const dept = await prisma.department.findUnique({ where: { id: parseInt(departmentId, 10) } });
    if (!dept) return res.status(400).json({ success: false, error: 'ไม่พบข้อมูลแผนกนี้ในระบบ' });

    const pos = await prisma.position.findUnique({ where: { id: parseInt(positionId, 10) } });
    if (!pos) return res.status(400).json({ success: false, error: 'ไม่พบตำแหน่งนี้ในระบบ' });
    
    if (pos.departmentId !== parseInt(departmentId, 10)) {
      return res.status(400).json({ success: false, error: 'ตำแหน่งนี้ไม่ได้อยู่ในแผนกที่เลือก' });
    }

    const role = await prisma.role.findUnique({ where: { id: parseInt(roleId, 10) } });
    if (!role) return res.status(400).json({ success: false, error: 'ไม่พบสิทธิ์การใช้งานนี้' });

    // --- 3. Database Transaction (บันทึก Employee และ User พร้อมกัน) ---
    const isActiveStatus = active !== undefined ? Boolean(active) : true;

    const result = await prisma.$transaction(async (prismaClient) => {
      // สร้าง Employee
      const newEmployee = await prismaClient.employee.create({
        data: {
          employeeCode: employeeCode.trim(),
          fullName: fullName.trim(),
          departmentId: parseInt(departmentId, 10),
          positionId: parseInt(positionId, 10),
          isActive: isActiveStatus,
        }
      });

      // สร้าง User ผูกกับ Employee
      const newUser = await prismaClient.user.create({
        data: {
          employeeId: newEmployee.id,
          roleId: parseInt(roleId, 10),
          active: isActiveStatus,
          pin: null,
          pinInitialized: false,
          pinResetRequired: false,
          failedLoginAttempts: 0,
          lockedUntil: null,
          currentSessionId: null
        }
      });

      return { newEmployee, newUser };
    });

    res.status(201).json({ 
      success: true, 
      message: 'สร้างพนักงานและผู้ใช้งานสำเร็จ', 
      data: result.newEmployee 
    });

  } catch (error) {
    console.error('Create Employee Error:', error);
    // ตรวจสอบ Constraint Violation (เช่น รหัสพนักงานซ้ำ)
    if (error.code === 'P2002') {
      return res.status(400).json({ success: false, error: 'รหัสพนักงานนี้มีในระบบแล้ว' });
    }
    res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการบันทึกข้อมูล' });
  }
};