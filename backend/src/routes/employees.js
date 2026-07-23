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

    return res.status(200).json({ success: true, data: result });
  } catch (error) {
    console.error("GET /api/employees Error:", error);
    return res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลพนักงานได้" });
  }
});

module.exports = router;