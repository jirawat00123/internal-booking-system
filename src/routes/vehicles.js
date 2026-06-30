const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { verifyToken, requireRole } = require('../middlewares/auth');

// ==========================================
// 🛠️ ตั้งค่า Multer สำหรับอัปโหลดรูปภาพรถยนต์
// ==========================================
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        const dir = 'uploads/vehicles/';
        // สร้างโฟลเดอร์อัตโนมัติถ้ายังไม่มี
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }
        cb(null, dir);
    },
    filename: function (req, file, cb) {
        // ตั้งชื่อไฟล์ใหม่: vehicle_timestamp.ext
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, 'vehicle_' + uniqueSuffix + path.extname(file.originalname));
    }
});
const upload = multer({ storage: storage });

// ==========================================
// 🚗 API Routes สำหรับรถยนต์
// ==========================================

// 1. ดึงข้อมูลรถยนต์ทั้งหมด (เฉพาะที่ยังไม่ถูก Soft Delete)
router.get('/', async (req, res, next) => {
    try {
        const vehicles = await prisma.vehicle.findMany({
            where: { isDeleted: false },
            orderBy: { createdAt: 'desc' }
        });
        return res.status(200).json({ success: true, data: vehicles });
    } catch (error) {
        next(error);
    }
});

// 2. เพิ่มข้อมูลรถยนต์ใหม่ (พร้อมอัปโหลดรูป)
router.post('/', verifyToken, requireRole(['ADMIN']), upload.single('image'), async (req, res, next) => {
    try {
        const { plateNumber, brand, model, seats, status } = req.body;
        
        // ถ้ามีการอัปโหลดไฟล์ ให้เก็บ Path ไว้
        const uploadUrl = req.file ? `/uploads/vehicles/${req.file.filename}` : null;

        const newVehicle = await prisma.vehicle.create({
            data: {
                plateNumber,
                brand,
                model,
                seats: parseInt(seats) || 4, // แปลงเป็นตัวเลข (Default 4)
                status: status || 'AVAILABLE',
                uploadUrl: uploadUrl
            }
        });

        return res.status(201).json({ success: true, data: newVehicle, message: 'เพิ่มรถยนต์สำเร็จ' });
    } catch (error) {
        next(error);
    }
});

module.exports = router;