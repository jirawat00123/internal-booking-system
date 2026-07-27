const express = require('express');
const { PrismaClient } = require('@prisma/client');
const router = express.Router();
const prisma = new PrismaClient();

// 🏢 1. GET /api/departments - ดึงแผนกทั้งหมด
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

// 📋 2. GET /api/employees - ดึงพนักงาน (รองรับ Filter ตาม departmentId)
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

    // ... (โค้ด GET /employees ก่อนหน้า)
    return res.status(200).json({ success: true, data: result });
  } catch (error) {
    console.error("GET /api/employees Error:", error);
    return res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลพนักงานได้" });
  }
});

// ✏️ 3. PUT /api/employees/:id - อัปเดตข้อมูลพนักงาน
router.put('/employees/:id', async (req, res) => {
  try {
    const employeeId = parseInt(req.params.id, 10);
    if (isNaN(employeeId)) {
      return res.status(400).json({ success: false, error: "รหัสพนักงานไม่ถูกต้อง" });
    }

    // รับค่าจาก Frontend (ดึงเฉพาะฟิลด์ที่มีใน Schema)
    const { 
      employeeCode, 
      fullName, 
      positionId, 
      departmentId, 
      isActive, 
      roleId, 
      active // สำหรับสถานะของ User Account
    } = req.body;

    // 1. ตรวจสอบว่าพนักงานคนนี้มีอยู่ในฐานข้อมูลจริง
    const existingEmployee = await prisma.employee.findUnique({
      where: { id: employeeId },
      include: { users: true }
    });

    if (!existingEmployee) {
      return res.status(404).json({ success: false, error: "ไม่พบข้อมูลพนักงานที่ต้องการอัปเดต" });
    }

    // 2. อัปเดตข้อมูลโดยใช้ Transaction เพื่อป้องกันข้อมูลพังกรณีเกิด Error กลางทาง
    const updatedData = await prisma.$transaction(async (tx) => {
      // 2.1 อัปเดตตาราง Employee
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

      // 2.2 ถ้ามีการส่งข้อมูลอัปเดต User Account (roleId หรือ active) และพนักงานนี้มี Account
      if ((roleId || active !== undefined) && existingEmployee.users.length > 0) {
        const userId = existingEmployee.users[0].id;
        await tx.user.update({
          where: { id: userId },
          data: {
            ...(roleId && { roleId: parseInt(roleId, 10) }),
            ...(active !== undefined && { active })
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
    
    // ดักจับ Error กรณีแก้ไข employeeCode ซ้ำกับคนอื่นในระบบ (Unique Constraint)
    if (error.code === 'P2002') {
      return res.status(409).json({ success: false, error: "รหัสพนักงานนี้ถูกใช้งานในระบบแล้ว" });
    }
    
    return res.status(500).json({ success: false, error: "ระบบหลังบ้านขัดข้อง ไม่สามารถอัปเดตข้อมูลได้" });
  }
});

module.exports = router;