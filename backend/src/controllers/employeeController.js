const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const fs = require('fs');
const path = require('path');

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
  const { employeeCode, fullName, departmentId, positionId, roleId, active, isDriver, driverLicenseIssueDate, driver_license_issue_date, driverLicenseExpiryDate, driverLicenseExpiry, driver_license_expiry_date } = req.body;
  const issueDate = driverLicenseIssueDate || driver_license_issue_date;
  const expiryDate = driverLicenseExpiryDate || driverLicenseExpiry || driver_license_expiry_date;

  // --- 1. Validation เบื้องต้น ---
  if (!fullName || !departmentId || !roleId || !employeeCode) {
    if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
    return res.status(400).json({ success: false, error: 'กรุณาส่งข้อมูลให้ครบถ้วน' });
  }

  try {
    // --- 2. ตรวจสอบความถูกต้องของข้อมูล (Foreign Keys) ---
    const dept = await prisma.department.findUnique({ where: { id: parseInt(departmentId, 10) } });
    if (!dept) {
      if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
      return res.status(400).json({ success: false, error: 'ไม่พบข้อมูลแผนกนี้ในระบบ' });
    }

    const isValidPosition = positionId && positionId !== 'null' && positionId !== 'undefined' && positionId !== '';

    if (isValidPosition) {
      const pos = await prisma.position.findUnique({ where: { id: parseInt(positionId, 10) } });
      if (!pos) {
        if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
        return res.status(400).json({ success: false, error: 'ไม่พบตำแหน่งนี้ในระบบ' });
      }
      
      if (pos.departmentId !== parseInt(departmentId, 10)) {
        if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
        return res.status(400).json({ success: false, error: 'ตำแหน่งนี้ไม่ได้อยู่ในแผนกที่เลือก' });
      }
    }

    const role = await prisma.role.findUnique({ where: { id: parseInt(roleId, 10) } });
    if (!role) {
      if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
      return res.status(400).json({ success: false, error: 'ไม่พบสิทธิ์การใช้งานนี้' });
    }

    // จัดการย้ายไฟล์ใบขับขี่ลง NAS หากมีการอัปโหลด
    let driverLicensePath = null;
    if (req.file) {
      const nasDir = path.join(__dirname, '../../attachments/users/licensedriver');
      if (!fs.existsSync(nasDir)) {
        fs.mkdirSync(nasDir, { recursive: true });
      }
      const ext = path.extname(req.file.originalname);
      const sanitizedFullName = fullName.trim().replace(/[^\w\u0E00-\u0E7F]/g, '_');
      const fileName = `license_${sanitizedFullName}_${Date.now()}${ext}`;
      const destinationPath = path.join(nasDir, fileName);

      fs.renameSync(req.file.path, destinationPath);
      driverLicensePath = `/attachments/users/licensedriver/${fileName}`;
    }

    // แปลงค่า Boolean จาก Multipart Form Data
    const parseBool = (val, defaultVal = false) => {
      if (val === undefined || val === null || val === '') return defaultVal;
      return val === true || val === 'true';
    };

    const parseDate = (val) => {
      if (!val || val === 'null' || val === 'undefined' || val === '') return null;
      const d = new Date(val);
      if (isNaN(d.getTime())) return null;
      const thaiTime = new Date(d.getTime() + (7 * 60 * 60 * 1000));
      const yyyy = thaiTime.getUTCFullYear();
      const mm = String(thaiTime.getUTCMonth() + 1).padStart(2, '0');
      const dd = String(thaiTime.getUTCDate()).padStart(2, '0');
      return new Date(`${yyyy}-${mm}-${dd}T00:00:00.000Z`);
    };

    const isActiveStatus = parseBool(active, true);
    const isDriverStatus = parseBool(isDriver, false);

    const parsedIssueDate = parseDate(issueDate);
    const parsedExpiryDate = parseDate(expiryDate);

    // --- 3. Database Transaction (บันทึก Employee และ User พร้อมกัน) ---
    const result = await prisma.$transaction(async (prismaClient) => {
      // สร้าง Employee
      const newEmployee = await prismaClient.employee.create({
        data: {
          employeeCode: employeeCode.trim(),
          fullName: fullName.trim(),
          departmentId: parseInt(departmentId, 10),
          positionId: isValidPosition ? parseInt(positionId, 10) : null,
          isActive: isActiveStatus,
          isDriver: isDriverStatus,
          driverLicenseIssueDate: parsedIssueDate,
          driverLicenseExpiryDate: parsedExpiryDate,
          driverLicenseUrl: driverLicensePath,
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
    if (req.file && fs.existsSync(req.file.path)) {
      fs.unlinkSync(req.file.path);
    }
    console.error('Create Employee Error:', error);
    if (error.code === 'P2002') {
      return res.status(400).json({ success: false, error: 'รหัสพนักงานนี้มีในระบบแล้ว' });
    }
    res.status(500).json({ success: false, error: 'เกิดข้อผิดพลาดในการบันทึกข้อมูล' });
  }
};

// 6. PUT /api/employees/:id (อัปเดตข้อมูลพนักงานและ User ใน Transaction เดียว)
exports.updateEmployee = async (req, res) => {
  try {
    const employeeId = parseInt(req.params.id, 10);
    if (isNaN(employeeId)) {
      if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
      return res.status(400).json({ success: false, error: 'รหัสพนักงานไม่ถูกต้อง' });
    }

    const { employeeCode, fullName, positionId, departmentId, isActive, roleId, active, isDriver, driverLicenseIssueDate, driver_license_issue_date, driverLicenseExpiryDate, driverLicenseExpiry, driver_license_expiry_date } = req.body;
    const issueDate = driverLicenseIssueDate || driver_license_issue_date;
    const expiryDate = driverLicenseExpiryDate || driverLicenseExpiry || driver_license_expiry_date;

    const existingEmployee = await prisma.employee.findUnique({
      where: { id: employeeId },
      include: { users: true }
    });

    if (!existingEmployee) {
      if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
      return res.status(404).json({ success: false, error: 'ไม่พบข้อมูลพนักงานที่ต้องการอัปเดต' });
    }

    // จัดการย้ายไฟล์ใบขับขี่ใหม่ลง NAS และลบไฟล์เก่า (หากมีการอัปโหลดไฟล์ใหม่)
    let newDriverLicensePath = undefined;
    if (req.file) {
      const nasDir = path.join(__dirname, '../../attachments/users/licensedriver');
      if (!fs.existsSync(nasDir)) {
        fs.mkdirSync(nasDir, { recursive: true });
      }
      const ext = path.extname(req.file.originalname);
      const targetName = (fullName ? fullName.trim() : existingEmployee.fullName).replace(/[^\w\u0E00-\u0E7F]/g, '_');
      const fileName = `license_${targetName}_${Date.now()}${ext}`;
      const destinationPath = path.join(nasDir, fileName);

      fs.renameSync(req.file.path, destinationPath);
      newDriverLicensePath = `/attachments/users/licensedriver/${fileName}`;

      // ลบไฟล์ใบขับขี่เดิมออกจาก NAS (ถ้ามี)
      if (existingEmployee.driverLicenseUrl) {
        const oldFilePath = path.join(__dirname, '../../', existingEmployee.driverLicenseUrl);
        if (fs.existsSync(oldFilePath)) {
          fs.unlinkSync(oldFilePath);
        }
      }
    }

    const parseBool = (val) => {
      if (val === undefined || val === null || val === '') return undefined;
      return val === true || val === 'true';
    };

    const parseDate = (val) => {
      if (!val || val === 'null' || val === 'undefined' || val === '') return null;
      const d = new Date(val);
      if (isNaN(d.getTime())) return null;
      const thaiTime = new Date(d.getTime() + (7 * 60 * 60 * 1000));
      const yyyy = thaiTime.getUTCFullYear();
      const mm = String(thaiTime.getUTCMonth() + 1).padStart(2, '0');
      const dd = String(thaiTime.getUTCDate()).padStart(2, '0');
      return new Date(`${yyyy}-${mm}-${dd}T00:00:00.000Z`);
    };

    const parsedIsActive = parseBool(isActive);
    const parsedIsDriver = parseBool(isDriver);
    const parsedUserActive = parseBool(active);

    const updatedData = await prisma.$transaction(async (prismaClient) => {
      const parsedDeptId = departmentId ? parseInt(departmentId, 10) : undefined;
      const isValidPosition = positionId && positionId !== 'null' && positionId !== 'undefined' && positionId !== '';
      const parsedPosId = positionId !== undefined ? (isValidPosition ? parseInt(positionId, 10) : null) : undefined;

      const empUpdate = await prismaClient.employee.update({
        where: { id: employeeId },
        data: {
          ...(employeeCode && { employeeCode: employeeCode.trim() }),
          ...(fullName && { fullName: fullName.trim() }),
          ...(parsedDeptId && { departmentId: parsedDeptId }),
          ...(parsedPosId !== undefined && { positionId: parsedPosId }),
          ...(parsedIsActive !== undefined && { isActive: parsedIsActive }),
          ...(parsedIsDriver !== undefined && { isDriver: parsedIsDriver }),
          ...(issueDate !== undefined && { driverLicenseIssueDate: parseDate(issueDate) }),
          ...(expiryDate !== undefined && { driverLicenseExpiryDate: parseDate(expiryDate) }),
          ...(newDriverLicensePath !== undefined && { driverLicenseUrl: newDriverLicensePath }),
        }
      });

      const parsedRoleId = roleId ? parseInt(roleId, 10) : undefined;
      const userActiveStatus = parsedUserActive !== undefined ? parsedUserActive : parsedIsActive;

      if (existingEmployee.users.length > 0) {
        await prismaClient.user.updateMany({
          where: { employeeId: employeeId },
          data: {
            ...(parsedRoleId && { roleId: parsedRoleId }),
            ...(userActiveStatus !== undefined && { 
              active: userActiveStatus,
              ...(userActiveStatus ? { failedLoginAttempts: 0, lockedUntil: null } : { currentSessionId: null })
            })
          }
        });
      } else if (parsedRoleId) {
        await prismaClient.user.create({
          data: {
            employeeId: employeeId,
            roleId: parsedRoleId,
            active: userActiveStatus ?? true
          }
        });
      }

      return empUpdate;
    });

    return res.status(200).json({ 
      success: true, 
      message: 'อัปเดตข้อมูลพนักงานสำเร็จ', 
      data: updatedData 
    });

  } catch (error) {
    if (req.file && fs.existsSync(req.file.path)) {
      fs.unlinkSync(req.file.path);
    }
    console.error('Update Employee Error:', error);
    if (error.code === 'P2002') {
      return res.status(409).json({ success: false, error: 'รหัสพนักงานนี้ถูกใช้งานในระบบแล้ว' });
    }
    return res.status(500).json({ success: false, error: 'ระบบหลังบ้านขัดข้อง ไม่สามารถอัปเดตข้อมูลได้' });
  }
};

// 7. GET /api/employees (ดึงข้อมูลพนักงานทั้งหมด พร้อมตัวกรองแผนก คำค้นหา และผู้ขับขี่)
exports.getEmployees = async (req, res) => {
  try {
    const { departmentId, search, isDriver } = req.query;

    const where = {
      users: {
        none: {
          isDeleted: true
        }
      }
    };

    if (departmentId && departmentId !== 'null' && departmentId !== 'undefined' && departmentId !== 'all') {
      where.departmentId = parseInt(departmentId, 10);
    }

    if (isDriver === 'true') {
      where.isDriver = true;
    }

    if (search) {
      where.OR = [
        { fullName: { contains: search, mode: 'insensitive' } },
        { employeeCode: { contains: search, mode: 'insensitive' } },
      ];
    }

    const employees = await prisma.employee.findMany({
      where,
      include: {
        department: true,
        position: true,
        users: {
          where: {
            isDeleted: false
          },
          include: {
            role: true,
          },
        },
      },
      orderBy: { id: 'asc' },
    });

    return res.status(200).json({ success: true, data: employees });
  } catch (error) {
    console.error('Error fetching employees:', error);
    return res.status(500).json({ success: false, error: 'ไม่สามารถดึงข้อมูลพนักงานได้' });
  }
};

// 8. GET /api/employees/:id (ดึงข้อมูลพนักงานรายคนด้วย employeeId รวมข้อมูลใบขับขี่)
exports.getEmployeeById = async (req, res) => {
  try {
    const employeeId = parseInt(req.params.id, 10);
    if (isNaN(employeeId)) {
      return res.status(400).json({ success: false, error: 'รหัสพนักงานไม่ถูกต้อง' });
    }

    const employee = await prisma.employee.findUnique({
      where: { id: employeeId },
      include: {
        department: true,
        position: true,
        users: {
          where: { isDeleted: false },
          include: { role: true },
        },
      },
    });

    if (!employee) {
      return res.status(404).json({ success: false, error: 'ไม่พบข้อมูลพนักงาน' });
    }

    return res.status(200).json({ success: true, data: employee });
  } catch (error) {
    console.error('Error fetching employee by ID:', error);
    return res.status(500).json({ success: false, error: 'ไม่สามารถดึงข้อมูลพนักงานได้' });
  }
};