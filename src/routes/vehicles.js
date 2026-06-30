const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// ดึง Middleware สำหรับตรวจสอบสิทธิ์
const { verifyToken, requireRole } = require('../middlewares/auth');

// ==========================================
// 🛠️ ตั้งค่า Multer สำหรับอัปโหลดรูปภาพรถยนต์
// ==========================================
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        const dir = 'uploads/vehicles/';
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }
        cb(null, dir);
    },
    filename: function (req, file, cb) {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, 'vehicle_' + uniqueSuffix + path.extname(file.originalname).toLowerCase());
    }
});

const fileFilter = (req, file, cb) => {
    const allowedTypes = /jpeg|jpg|png/;
    const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = allowedTypes.test(file.mimetype);
    
    if (extname && mimetype) {
        return cb(null, true);
    } else {
        return cb(new Error('รองรับเฉพาะไฟล์รูปภาพ (png, jpg, jpeg) เท่านั้น'));
    }
};

const upload = multer({ 
    storage: storage,
    fileFilter: fileFilter,
    limits: { fileSize: 5 * 1024 * 1024 } 
});

// ==========================================
// 🚗 API Routes สำหรับรถยนต์
// ==========================================

// 1. GET /api/vehicles - ดึงข้อมูลรถยนต์ทั้งหมด (เฉพาะที่ยังไม่ถูก Soft Delete)
router.get('/', verifyToken, async (req, res, next) => {
    try {
        const vehicles = await prisma.vehicle.findMany({
            where: { isDeleted: false },
            orderBy: { createdAt: 'desc' }
        });
        return res.status(200).json({ success: true, data: vehicles });
    } catch (error) {
        console.error("Get Vehicles Error:", error);
        return res.status(500).json({ success: false, error: "ระบบขัดข้องในการดึงข้อมูลรถ" });
    }
});

// 2. POST /api/vehicles - เพิ่มข้อมูลรถยนต์ใหม่ (เฉพาะ ADMIN)
router.post('/', verifyToken, requireRole(['ADMIN']), upload.single('image'), async (req, res, next) => {
    try {
        const { plateNumber, brand, model, seats, status } = req.body;
        
        if (!plateNumber || !brand || !model) {
            if (req.file) fs.unlinkSync(req.file.path);
            return res.status(400).json({ success: false, error: "กรุณากรอกข้อมูลให้ครบถ้วน (ทะเบียน, ยี่ห้อ, รุ่น)" });
        }

        const seatNumber = parseInt(seats) || 4;
        if (seatNumber <= 0) {
            if (req.file) fs.unlinkSync(req.file.path);
            return res.status(400).json({ success: false, error: "จำนวนที่นั่งต้องมากกว่า 0" });
        }

        const existingVehicle = await prisma.vehicle.findUnique({
            where: { plateNumber: plateNumber }
        });

        if (existingVehicle) {
            if (req.file) fs.unlinkSync(req.file.path);
            return res.status(400).json({ success: false, error: `ป้ายทะเบียน ${plateNumber} มีในระบบแล้ว` });
        }
        
        const uploadUrl = req.file ? `/uploads/vehicles/${req.file.filename}` : null;

        const newVehicle = await prisma.vehicle.create({
            data: {
                plateNumber,
                brand,
                model,
                seats: seatNumber,
                status: status || 'AVAILABLE',
                uploadUrl: uploadUrl
            }
        });

        return res.status(201).json({ success: true, data: newVehicle, message: 'เพิ่มรถยนต์สำเร็จ' });
    } catch (error) {
        if (req.file) fs.unlinkSync(req.file.path);
        console.error("Create Vehicle Error:", error);
        return res.status(500).json({ success: false, error: error.message || "ไม่สามารถเพิ่มข้อมูลรถได้" });
    }
});

// 3. GET /api/vehicles/:id - ดึงข้อมูลรถยนต์ 1 คัน
router.get('/:id', verifyToken, async (req, res, next) => {
    try {
        const vehicleId = parseInt(req.params.id);
        const vehicle = await prisma.vehicle.findUnique({
            where: { id: vehicleId }
        });

        // 🛑 ถ้าไม่พบรถ หรือรถถูก Soft Delete ไปแล้ว
        if (!vehicle || vehicle.isDeleted) {
            return res.status(404).json({ success: false, error: "ไม่พบข้อมูลรถยนต์ในระบบ" });
        }

        return res.status(200).json({ success: true, data: vehicle });
    } catch (error) {
        console.error("Get Vehicle By ID Error:", error);
        return res.status(500).json({ success: false, error: "ระบบขัดข้องในการดึงข้อมูลรถ" });
    }
});

// 4. PUT /api/vehicles/:id - แก้ไขข้อมูลรถยนต์ (เฉพาะ ADMIN)
router.put('/:id', verifyToken, requireRole(['ADMIN']), upload.single('image'), async (req, res, next) => {
    try {
        const vehicleId = parseInt(req.params.id);
        const { plateNumber, brand, model, seats, status } = req.body;

        // 🛑 1. เช็กว่ารถมีอยู่จริงหรือไม่
        const existingVehicle = await prisma.vehicle.findUnique({ where: { id: vehicleId } });
        if (!existingVehicle || existingVehicle.isDeleted) {
            if (req.file) fs.unlinkSync(req.file.path);
            return res.status(404).json({ success: false, error: "ไม่พบข้อมูลรถยนต์ที่ต้องการแก้ไข" });
        }

        // 🛑 2. เช็กทะเบียนซ้ำ (กรณีที่แก้ไขเปลี่ยนป้ายทะเบียน และป้ายนั้นดันไปตรงกับคันอื่น)
        if (plateNumber && plateNumber !== existingVehicle.plateNumber) {
            const duplicatePlate = await prisma.vehicle.findUnique({ where: { plateNumber: plateNumber } });
            if (duplicatePlate) {
                if (req.file) fs.unlinkSync(req.file.path);
                return res.status(400).json({ success: false, error: `ป้ายทะเบียน ${plateNumber} มีในระบบแล้ว` });
            }
        }

        // 🛑 3. จัดการรูปภาพ (ถ้าอัปโหลดรูปใหม่ ต้องลบรูปเก่าทิ้ง)
        let newUploadUrl = existingVehicle.uploadUrl;
        if (req.file) {
            newUploadUrl = `/uploads/vehicles/${req.file.filename}`;
            // ลบไฟล์เก่าออกจากเครื่องเซิร์ฟเวอร์
            if (existingVehicle.uploadUrl) {
                const oldFilePath = path.join(__dirname, '../../', existingVehicle.uploadUrl);
                if (fs.existsSync(oldFilePath)) {
                    fs.unlinkSync(oldFilePath);
                }
            }
        }

        // ✅ 4. อัปเดตข้อมูล
        const updatedVehicle = await prisma.vehicle.update({
            where: { id: vehicleId },
            data: {
                plateNumber: plateNumber || existingVehicle.plateNumber,
                brand: brand || existingVehicle.brand,
                model: model || existingVehicle.model,
                seats: seats ? parseInt(seats) : existingVehicle.seats,
                status: status || existingVehicle.status,
                uploadUrl: newUploadUrl
            }
        });

        return res.status(200).json({ success: true, data: updatedVehicle, message: "แก้ไขข้อมูลรถสำเร็จ" });
    } catch (error) {
        if (req.file) fs.unlinkSync(req.file.path);
        console.error("Update Vehicle Error:", error);
        return res.status(500).json({ success: false, error: "ไม่สามารถแก้ไขข้อมูลรถได้" });
    }
});

// 5. DELETE /api/vehicles/:id - ลบรถแบบ Soft Delete (เฉพาะ ADMIN)
router.delete('/:id', verifyToken, requireRole(['ADMIN']), async (req, res, next) => {
    try {
        const vehicleId = parseInt(req.params.id);

        const vehicle = await prisma.vehicle.findUnique({ where: { id: vehicleId } });
        if (!vehicle || vehicle.isDeleted) {
            return res.status(404).json({ success: false, error: "ไม่พบข้อมูลรถ หรือรถถูกลบไปแล้ว" });
        }

        // 🛑 ลอจิกสำคัญ: ตรวจสอบว่ามีคิวจองในอนาคตหรือไม่
        // หาการจองที่สิ้นสุดในอนาคต และสถานะไม่ใช่ Cancelled หรือ Rejected
        const futureBookings = await prisma.vehicleBooking.findMany({
            where: {
                vehicleId: vehicleId,
                endDatetime: { gt: new Date() }, // เวลาสิ้นสุดการจอง > เวลาปัจจุบัน
                status: { notIn: ['Cancelled', 'Rejected'] }
            }
        });

        if (futureBookings.length > 0) {
            return res.status(400).json({ 
                success: false, 
                error: "ไม่สามารถลบรถคันนี้ได้ เนื่องจากมีคิวจองใช้งานในอนาคต",
                futureBookingsCount: futureBookings.length
            });
        }

        // ✅ อัปเดตสถานะเป็น Soft Delete แทนการลบทิ้งจริง (รักษาประวัติการจองในอดีต)
        await prisma.vehicle.update({
            where: { id: vehicleId },
            data: { isDeleted: true, status: 'INACTIVE' } // ปรับสถานะเป็น INACTIVE คู่กัน
        });

        return res.status(200).json({ success: true, message: "ลบข้อมูลรถออกจากระบบสำเร็จ (Soft Delete)" });
    } catch (error) {
        console.error("Delete Vehicle Error:", error);
        return res.status(500).json({ success: false, error: "ไม่สามารถลบข้อมูลรถได้" });
    }
});

module.exports = router;