// src/controllers/vehicleController.js
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const fs = require('fs');
const path = require('path');

// Helper Function: สำหรับลบไฟล์รูปภาพอย่างปลอดภัย
const safeDeleteFile = async (filePath) => {
    if (filePath && fs.existsSync(filePath)) {
        try {
            await fs.promises.unlink(filePath);
        } catch (err) {
            console.error("Error deleting file:", err);
        }
    }
};

// 1. ดึงข้อมูลรถยนต์ทั้งหมด (ปรับปรุงข้อ 9: เพิ่มระบบแบ่งหน้า Pagination และดึงข้อมูลแบบรวดเร็วด้วย $transaction)
exports.getVehicles = async (req, res) => {
    try {
        const page = parseInt(req.query.page, 10) || 1;
        const limit = parseInt(req.query.limit, 10) || 10;
        const skip = (page - 1) * limit;

        const whereCondition = { isDeleted: false };

        // ใช้ $transaction เพื่อรัน count และ findMany ควบคู่กัน เพิ่มความเร็วในการทำงานของ Database
        const [totalItems, vehicles] = await prisma.$transaction([
            prisma.vehicle.count({ where: whereCondition }),
            prisma.vehicle.findMany({
                where: whereCondition,
                skip: skip,
                take: limit,
                orderBy: { createdAt: 'desc' }
            })
        ]);

        const totalPages = Math.ceil(totalItems / limit);

        return res.status(200).json({ 
            success: true, 
            message: "ดึงข้อมูลรายการรถยนต์ส่วนกลางสำเร็จ",
            pagination: {
                totalItems,
                totalPages,
                currentPage: page,
                limit,
                hasNextPage: page < totalPages,
                hasPreviousPage: page > 1
            },
            data: vehicles 
        });
    } catch (error) {
        console.error("Get Vehicles Error:", error);
        return res.status(500).json({ success: false, error: "ระบบขัดข้องในการดึงข้อมูลรถ" });
    }
};

// 2. เพิ่มข้อมูลรถยนต์ใหม่
exports.createVehicle = async (req, res) => {
    try {
        const { plateNumber, brand, model, seats, status } = req.body;
        
        if (!plateNumber || !brand || !model) {
            if (req.file) await safeDeleteFile(req.file.path);
            return res.status(400).json({ success: false, error: "กรุณากรอกข้อมูลให้ครบถ้วน (ทะเบียน, ยี่ห้อ, รุ่น)" });
        }

        const seatNumber = parseInt(seats, 10);
        if (isNaN(seatNumber) || seatNumber <= 0) {
            if (req.file) await safeDeleteFile(req.file.path);
            return res.status(400).json({ success: false, error: "จำนวนที่นั่งต้องเป็นตัวเลขและมากกว่า 0 ขึ้นไป" });
        }

        const existingVehicle = await prisma.vehicle.findUnique({
            where: { plateNumber: plateNumber }
        });

        if (existingVehicle) {
            if (req.file) await safeDeleteFile(req.file.path);
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
        if (req.file) await safeDeleteFile(req.file.path);
        console.error("Create Vehicle Error:", error);
        return res.status(500).json({ success: false, error: error.message || "ไม่สามารถเพิ่มข้อมูลรถได้" });
    }
};

// 3. ดึงข้อมูลรถยนต์ 1 คัน
exports.getVehicleById = async (req, res) => {
    try {
        const vehicleId = parseInt(req.params.id, 10);
        if (isNaN(vehicleId)) {
            return res.status(400).json({ success: false, error: "ID ของรถยนต์ไม่ถูกต้อง" });
        }

        const vehicle = await prisma.vehicle.findUnique({ where: { id: vehicleId } });

        if (!vehicle || vehicle.isDeleted) {
            return res.status(404).json({ success: false, error: "ไม่พบข้อมูลรถยนต์ในระบบ" });
        }

        return res.status(200).json({ success: true, data: vehicle });
    } catch (error) {
        console.error("Get Vehicle By ID Error:", error);
        return res.status(500).json({ success: false, error: "ระบบขัดข้องในการดึงข้อมูลรถ" });
    }
};

// 4. แก้ไขข้อมูลรถยนต์
exports.updateVehicle = async (req, res) => {
    try {
        const vehicleId = parseInt(req.params.id, 10);
        const { plateNumber, brand, model, seats, status } = req.body;

        if (isNaN(vehicleId)) {
            if (req.file) await safeDeleteFile(req.file.path);
            return res.status(400).json({ success: false, error: "ID ของรถยนต์ไม่ถูกต้อง" });
        }

        const existingVehicle = await prisma.vehicle.findUnique({ where: { id: vehicleId } });
        if (!existingVehicle || existingVehicle.isDeleted) {
            if (req.file) await safeDeleteFile(req.file.path);
            return res.status(404).json({ success: false, error: "ไม่พบข้อมูลรถยนต์ที่ต้องการแก้ไข" });
        }

        if (plateNumber && plateNumber !== existingVehicle.plateNumber) {
            const duplicatePlate = await prisma.vehicle.findUnique({ where: { plateNumber: plateNumber } });
            if (duplicatePlate) {
                if (req.file) await safeDeleteFile(req.file.path);
                return res.status(400).json({ success: false, error: `ป้ายทะเบียน ${plateNumber} มีในระบบแล้ว` });
            }
        }

        let newUploadUrl = existingVehicle.uploadUrl;
        if (req.file) {
            newUploadUrl = `/uploads/vehicles/${req.file.filename}`;
            if (existingVehicle.uploadUrl) {
                const oldFilePath = path.join(process.cwd(), existingVehicle.uploadUrl);
                await safeDeleteFile(oldFilePath);
            }
        }

        const updatedVehicle = await prisma.vehicle.update({
            where: { id: vehicleId },
            data: {
                plateNumber: plateNumber || existingVehicle.plateNumber,
                brand: brand || existingVehicle.brand,
                model: model || existingVehicle.model,
                seats: seats ? parseInt(seats, 10) : existingVehicle.seats,
                status: status || existingVehicle.status,
                uploadUrl: newUploadUrl
            }
        });

        return res.status(200).json({ success: true, data: updatedVehicle, message: "แก้ไขข้อมูลรถสำเร็จ" });
    } catch (error) {
        if (req.file) await safeDeleteFile(req.file.path);
        console.error("Update Vehicle Error:", error);
        return res.status(500).json({ success: false, error: "ไม่สามารถแก้ไขข้อมูลรถได้" });
    }
};

// 5. ลบรถแบบ Soft Delete
exports.deleteVehicle = async (req, res) => {
    try {
        const vehicleId = parseInt(req.params.id, 10);
        if (isNaN(vehicleId)) {
            return res.status(400).json({ success: false, error: "ID ของรถยนต์ไม่ถูกต้อง" });
        }

        const vehicle = await prisma.vehicle.findUnique({ where: { id: vehicleId } });
        if (!vehicle || vehicle.isDeleted) {
            return res.status(404).json({ success: false, error: "ไม่พบข้อมูลรถ หรือรถถูกลบไปแล้ว" });
        }

        const futureBookings = await prisma.vehicleBooking.findMany({
            where: {
                vehicleId: vehicleId,
                endDatetime: { gt: new Date() },
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

        await prisma.vehicle.update({
            where: { id: vehicleId },
            data: { isDeleted: true, status: 'INACTIVE' } 
        });

        return res.status(200).json({ success: true, message: "ลบข้อมูลรถออกจากระบบสำเร็จ (Soft Delete)" });
    } catch (error) {
        console.error("Delete Vehicle Error:", error);
        return res.status(500).json({ success: false, error: "ไม่สามารถลบข้อมูลรถได้" });
    }
};

// =========================================================================
// ⭐ เพิ่มฟังก์ชันข้อ 10: ตรวจสอบและดึงรายการรถยนต์ที่ว่างตามวันเวลา (Available Vehicles)
// =========================================================================
exports.getAvailableVehicles = async (req, res) => {
    try {
        const { start, end } = req.query;
        const page = parseInt(req.query.page, 10) || 1;
        const limit = parseInt(req.query.limit, 10) || 10;
        const skip = (page - 1) * limit;

        // 1. ตรวจสอบ Validation เบื้องต้น
        if (!start || !end) {
            return res.status(400).json({ success: false, error: "กรุณาระบุวันเวลาเริ่มต้น (start) และสิ้นสุด (end) เพื่อตรวจสอบรถว่าง" });
        }

        const startQueryDate = new Date(start);
        const endQueryDate = new Date(end);

        if (isNaN(startQueryDate.getTime()) || isNaN(endQueryDate.getTime())) {
            return res.status(400).json({ success: false, error: "รูปแบบวันเวลาไม่ถูกต้อง ตัวอย่างที่ถูก: 2026-07-03T14:00:00.000Z" });
        }

        if (startQueryDate >= endQueryDate) {
            return res.status(400).json({ success: false, error: "วันเวลาเริ่มต้นต้องน้อยกว่าวันเวลาสิ้นสุด" });
        }

        // 2. ค้นหา ID รถยนต์ทั้งหมดที่มีคิวจองทับซ้อน (Overlapping) กับวันเวลาที่ส่งมา
        const conflictingBookings = await prisma.vehicleBooking.findMany({
            where: {
                status: { notIn: ['Cancelled', 'Rejected'] }, // ไม่สนใจรายการที่ยกเลิกหรือถูกปฏิเสธไปแล้ว
                // ลอจิกการทับซ้อนของเวลา: (คิวเริ่มก่อนเวลาจองเสร็จ) และ (คิวเสร็จหลังเวลาจองเริ่ม)
                startDatetime: { lt: endQueryDate },
                endDatetime: { gt: startQueryDate }
            },
            select: { vehicleId: true }
        });

        // แปลง Array ของ Object ให้เหลือแค่ Array ของ ID ตัวเลขธรรมดา เช่น [1, 3, 5]
        const conflictingVehicleIds = conflictingBookings.map(booking => booking.vehicleId);

        // 3. ตั้งเงื่อนไข: ค้นหารถที่ 'ไม่ได้ถูกลบ' และ 'ID ต้องไม่อยู่ในกลุ่มที่ติดจองซ้อน'
        const whereCondition = {
            isDeleted: false,
            id: { notIn: conflictingVehicleIds }
        };

        // 4. ดึงข้อมูลแบบแบ่งหน้า (Pagination) ประสิทธิภาพสูงด้วย $transaction
        const [totalItems, availableVehicles] = await prisma.$transaction([
            prisma.vehicle.count({ where: whereCondition }),
            prisma.vehicle.findMany({
                where: whereCondition,
                skip: skip,
                take: limit,
                orderBy: { createdAt: 'desc' }
            })
        ]);

        const totalPages = Math.ceil(totalItems / limit);

        return res.status(200).json({
            success: true,
            message: "ตรวจสอบและดึงข้อมูลรายการรถยนต์ที่ว่างสำเร็จ",
            pagination: {
                totalItems,
                totalPages,
                currentPage: page,
                limit,
                hasNextPage: page < totalPages,
                hasPreviousPage: page > 1
            },
            data: availableVehicles
        });

    } catch (error) {
        console.error("Get Available Vehicles Error:", error);
        return res.status(500).json({ success: false, error: "ระบบขัดข้องในการตรวจสอบสถานะรถว่าง" });
    }
};