const express = require('express');
const { PrismaClient } = require('@prisma/client');
const router = express.Router();
const prisma = new PrismaClient();
const fs = require('fs');
const path = require('path');
const upload = require('../middlewares/uploadMiddleware');

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

// GET /api/employees - ดึงพนักงานทั้งหมด (ส่งคืนข้อมูลใบขับขี่ด้วย)
router.get('/employees', async (req, res) => {
  try {
    const { departmentId, isDriver } = req.query;
    const whereClause = {};

    if (departmentId && departmentId !== 'undefined' && departmentId !== 'null' && departmentId !== 'all' && departmentId !== '') {
      const parsedId = parseInt(departmentId, 10);
      if (!isNaN(parsedId)) {
        whereClause.OR = [
          { departmentId: parsedId },
          { position: { departmentId: parsedId } }
        ];
      }
    }

    if (isDriver !== undefined && isDriver !== 'undefined' && isDriver !== 'null' && isDriver !== '') {
      whereClause.isDriver = isDriver === 'true';
    }

    const employees = await prisma.employee.findMany({
      where: whereClause,
      include: {
        department: true,
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
        departmentId: emp.departmentId || emp.position?.departmentId,
        departmentName: emp.department?.departmentName || emp.position?.department?.departmentName || "ไม่ระบุแผนก",
        positionName: emp.position?.positionName || "ไม่ระบุตำแหน่ง",
        role: userAcc?.role?.name || "USER",
        active: userAcc?.active ?? true,
        userId: userAcc?.id ?? null,
        isDriver: emp.isDriver ?? false,
        driverLicenseIssueDate: emp.driverLicenseIssueDate,
        driverLicenseExpiryDate: emp.driverLicenseExpiryDate,
        driverLicenseUrl: emp.driverLicenseUrl
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
router.post('/employees', upload.single('driverLicenseFile'), async (req, res) => {
  // 1. รับค่าจาก req.body ทั้งหมด (ห้าม Hardcode)
  const { employeeCode, fullName, departmentId, positionId, roleId, active, isDriver, driverLicenseIssueDate, driverLicenseExpiryDate, driverLicenseExpiry } = req.body;
  const expiryDate = driverLicenseExpiryDate || driverLicenseExpiry;

  // 2. Validation: ตรวจสอบข้อมูลเบื้องต้น (ไม่ต้องบังคับ positionId)
  if (!employeeCode || !fullName || !departmentId || !roleId) {
    if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
    return res.status(400).json({ success: false, error: 'กรุณาส่งข้อมูลให้ครบถ้วน (employeeCode, fullName, departmentId, roleId)' });
  }

  try {
    const parsedDeptId = parseInt(departmentId, 10);
    // ดักจับกรณี Flutter ส่งค่า String 'null', 'undefined' หรือค่าว่าง ('') มาแทนที่จะเป็น null จริงๆ
    const parsedPosId = (positionId && positionId !== 'null' && positionId !== 'undefined' && positionId !== '') 
      ? parseInt(positionId, 10) 
      : null;
    const parsedRoleId = parseInt(roleId, 10);
    
    // แปลงค่า Boolean จาก Multipart Form Data
    const parseBool = (val, defaultVal) => {
      if (val === undefined || val === null || val === '') return defaultVal;
      return val === true || val === 'true';
    };
    
    const isActiveStatus = parseBool(active, true);
    const isDriverStatus = parseBool(isDriver, false);

    // 3. API Validation: ตรวจสอบความถูกต้องของข้อมูลในฐานข้อมูลจริง (PostgreSQL)
    // 3.1 เช็กว่า Department มีอยู่จริง
    const deptExists = await prisma.department.findUnique({ where: { id: parsedDeptId } });
    if (!deptExists) {
      if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
      return res.status(400).json({ success: false, error: 'ไม่พบข้อมูลแผนก (Department) นี้ในระบบ' });
    }

    // 3.2 เช็กว่า Position มีอยู่จริง (หากส่ง positionId มา)
    if (parsedPosId) {
      const posExists = await prisma.position.findUnique({ where: { id: parsedPosId } });
      if (!posExists) {
        if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
        return res.status(400).json({ success: false, error: 'ไม่พบข้อมูลตำแหน่ง (Position) นี้ในระบบ' });
      }

      // 3.3 เช็กว่า Position อยู่ใน Department นั้นจริง
      if (posExists.departmentId !== parsedDeptId) {
        if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
        return res.status(400).json({ success: false, error: 'ตำแหน่งที่เลือกไม่ได้สังกัดอยู่ในแผนกที่ระบุ' });
      }
    }

    // 3.4 เช็กว่า Role มีอยู่จริง
    const roleExists = await prisma.role.findUnique({ where: { id: parsedRoleId } });
    if (!roleExists) {
      if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
      return res.status(400).json({ success: false, error: 'ไม่พบข้อมูลสิทธิ์การใช้งาน (Role) นี้ในระบบ' });
    }

    // ย้ายไฟล์ใบขับขี่จาก temp ไปยังโฟลเดอร์ NAS
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

    // 4. สร้างข้อมูลลง PostgreSQL ด้วย Prisma Transaction
    const result = await prisma.$transaction(async (tx) => {
      // 4.1 สร้าง Employee (ใช้ relation connect เพื่อแก้ปัญหา PrismaClientValidationError)
      const newEmployee = await tx.employee.create({
        data: {
          employeeCode: employeeCode.trim(),
          fullName: fullName.trim(),
          department: { connect: { id: parsedDeptId } },
          ...(parsedPosId ? { position: { connect: { id: parsedPosId } } } : {}),
          isActive: isActiveStatus,
          isDriver: isDriverStatus,
          driverLicenseIssueDate: driverLicenseIssueDate ? new Date(driverLicenseIssueDate) : null,
          driverLicenseExpiryDate: expiryDate ? new Date(expiryDate) : null,
          driverLicenseUrl: driverLicensePath,
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
    if (req.file && fs.existsSync(req.file.path)) {
      fs.unlinkSync(req.file.path);
    }
    console.error('POST /api/employees Error:', error);
    
    // ดักจับ Error กรณี employeeCode ซ้ำ (Unique Constraint)
    if (error.code === 'P2002') {
      return res.status(400).json({ success: false, error: 'รหัสพนักงานนี้มีอยู่ในระบบแล้ว' });
    }
    
    return res.status(500).json({ success: false, error: 'ระบบหลังบ้านขัดข้อง ไม่สามารถบันทึกข้อมูลได้' });
  }
});

// PUT /api/employees/:id - อัปเดตข้อมูลพนักงาน
router.put('/employees/:id', upload.single('driverLicenseFile'), async (req, res) => {
  try {
    const employeeId = parseInt(req.params.id, 10);
    if (isNaN(employeeId)) {
      return res.status(400).json({ success: false, error: "รหัสพนักงานไม่ถูกต้อง" });
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
      return res.status(404).json({ success: false, error: "ไม่พบข้อมูลพนักงานที่ต้องการอัปเดต" });
    }

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

      if (existingEmployee.driverLicenseUrl) {
        const oldFilePath = path.join(__dirname, '../../', existingEmployee.driverLicenseUrl);
        if (fs.existsSync(oldFilePath)) {
          fs.unlinkSync(oldFilePath);
        }
      }
    }

    const updatedData = await prisma.$transaction(async (tx) => {
      const empUpdate = await tx.employee.update({
        where: { id: employeeId },
        data: {
          ...(employeeCode && { employeeCode: employeeCode.trim() }),
          ...(fullName && { fullName: fullName.trim() }),
          // ดักจับค่าว่างหรือ string 'null' ป้องกัน Error จาก Prisma Connect
          ...(positionId !== undefined && (positionId && positionId !== 'null' && positionId !== 'undefined' && positionId !== '' ? { position: { connect: { id: parseInt(positionId, 10) } } } : { position: { disconnect: true } })),
          ...(departmentId !== undefined && (departmentId ? { department: { connect: { id: parseInt(departmentId, 10) } } } : {})),
          ...(isActive !== undefined && { isActive: isActive === 'true' || isActive === true }),
          ...(isDriver !== undefined && { isDriver: isDriver === 'true' || isDriver === true }),
          ...(driverLicenseIssueDate !== undefined && { driverLicenseIssueDate: driverLicenseIssueDate ? new Date(driverLicenseIssueDate) : null }),
          ...(expiryDate !== undefined && { driverLicenseExpiryDate: expiryDate ? new Date(expiryDate) : null }),
          ...(newDriverLicensePath !== undefined && { driverLicenseUrl: newDriverLicensePath })
        }
      });

      const parsedRoleId = roleId ? parseInt(roleId, 10) : undefined;
      const userActiveStatus = active !== undefined ? (active === 'true' || active === true) : (isActive !== undefined ? (isActive === 'true' || isActive === true) : undefined);

      if (existingEmployee.users.length > 0) {
        await tx.user.updateMany({
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
        await tx.user.create({
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
      message: "อัปเดตข้อมูลพนักงานสำเร็จ", 
      data: updatedData 
    });

  } catch (error) {
    if (req.file && fs.existsSync(req.file.path)) {
      fs.unlinkSync(req.file.path);
    }
    console.error("PUT /api/employees/:id Error:", error);
    if (error.code === 'P2002') {
      return res.status(409).json({ success: false, error: "รหัสพนักงานนี้ถูกใช้งานในระบบแล้ว" });
    }
    return res.status(500).json({ success: false, error: "ระบบหลังบ้านขัดข้อง ไม่สามารถอัปเดตข้อมูลได้" });
  }
});

// GET /api/employees/:id - ดึงข้อมูลพนักงานรายคนด้วย employeeId รวมข้อมูลใบขับขี่
router.get('/employees/:id', async (req, res) => {
  try {
    const employeeId = parseInt(req.params.id, 10);
    if (isNaN(employeeId)) {
      return res.status(400).json({ success: false, error: "รหัสพนักงานไม่ถูกต้อง" });
    }

    const employee = await prisma.employee.findUnique({
      where: { id: employeeId },
      include: {
        department: true,
        position: { include: { department: true } },
        users: { include: { role: true } }
      }
    });

    if (!employee) {
      return res.status(404).json({ success: false, error: "ไม่พบข้อมูลพนักงาน" });
    }

    const userAcc = employee.users && employee.users.length > 0 ? employee.users[0] : null;
    const result = {
      id: employee.id,
      employeeCode: employee.employeeCode,
      fullName: employee.fullName,
      departmentId: employee.departmentId || employee.position?.departmentId,
      departmentName: employee.department?.departmentName || employee.position?.department?.departmentName || "ไม่ระบุแผนก",
      positionName: employee.position?.positionName || "ไม่ระบุตำแหน่ง",
      role: userAcc?.role?.name || "USER",
      active: userAcc?.active ?? true,
      userId: userAcc?.id ?? null,
      isDriver: employee.isDriver ?? false,
      driverLicenseIssueDate: employee.driverLicenseIssueDate,
      driverLicenseExpiryDate: employee.driverLicenseExpiryDate,
      driverLicenseUrl: employee.driverLicenseUrl
    };

    return res.status(200).json({ success: true, data: result });
  } catch (error) {
    console.error("GET /api/employees/:id Error:", error);
    return res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลพนักงานได้" });
  }
});

module.exports = router;