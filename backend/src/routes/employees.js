const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// 1. API ดึงรายชื่อแผนกทั้งหมด (GET /api/departments)
router.get('/departments', async (req, res, next) => {
    try {
        const departments = await prisma.department.findMany({
            select: {
                id: true,
                departmentName: true // ใช้ departmentName ตาม Schema ของคุณเดฟ
            },
            orderBy: { departmentName: 'asc' }
        });

        return res.status(200).json({ success: true, data: departments });
    } catch (error) {
        next(error);
    }
});

// 2. API ดึงพนักงานตามแผนก (GET /api/employees?departmentId=1)
router.get('/employees', async (req, res, next) => {
    try {
        const { departmentId } = req.query;

        // ถ้าส่ง departmentId มา ก็กรองจาก Position -> Department
        const whereClause = departmentId ? {
            position: {
                departmentId: parseInt(departmentId)
            }
        } : {};

        const employees = await prisma.employee.findMany({
            where: whereClause,
            select: {
                id: true,
                employeeCode: true,
                fullName: true,
                position: { // ดึงชื่อตำแหน่งและแผนกพ่วงมาด้วยเลย
                    select: {
                        positionName: true
                    }
                },
                department: {
                    select: {
                        departmentName: true
                    }
                }
            },
            orderBy: { fullName: 'asc' }
        });

        return res.status(200).json({ success: true, data: employees });
    } catch (error) {
        next(error);
    }
});

module.exports = router;