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

// 1. ดึงข้อมูลรถยนต์ทั้งหมด
exports.getVehicles = async (req, res) => {
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
};

// 2. เพิ่มข้อมูลรถยนต์ใหม่
exports.createVehicle = async (req, res) => {
    try {
        // 💡 รับค่า vehicleName มาจากหน้าบ้านด้วย
        const { vehicleName, plateNumber, brand, model, seats, status } = req.body;
        
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
  where: { plateNumber: plateNumber } // ใช้ชื่อฟิลด์ "plateNumber" ตามที่เขียนใน Prisma Model
});

        if (existingVehicle) {
            if (req.file) await safeDeleteFile(req.file.path);
            return res.status(400).json({ success: false, error: `ป้ายทะเบียน ${plateNumber} มีในระบบแล้ว` });
        }
        
        // 💡 รองรับทั้งกรณีอัปโหลดไฟล์ผ่าน multer (req.file) และส่งเป็น Base64/URL ผ่าน req.body
        const uploadUrl = req.file ? `/uploads/vehicles/${req.file.filename}` : req.body.uploadUrl || null;

        const newVehicle = await prisma.vehicle.create({
            data: {
                // 💡 ถ้ามี vehicleName ส่งมาให้ใช้เลย ถ้าไม่มีให้เอา brand + model ต่อกัน
                vehicleName: vehicleName || `${brand} ${model}`,
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
        // 💡 เพิ่ม vehicleName ให้สามารถแก้ไขชื่อรถได้ด้วย
        const { vehicleName, plateNumber, brand, model, seats, status } = req.body;

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
        } else if (req.body.uploadUrl) {
            newUploadUrl = req.body.uploadUrl; // รองรับกรณีส่ง path มาตรงๆ
        }

        const updatedVehicle = await prisma.vehicle.update({
            where: { id: vehicleId },
            data: {
                vehicleName: vehicleName || existingVehicle.vehicleName, // 💡 อัปเดตชื่อรถ
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
        where: {id: parseInt(req.params.id)},
        data: {isDeleted: true}
    });

        return res.status(200).json({ success: true, message: "ลบข้อมูลรถออกจากระบบสำเร็จ (Soft Delete)" });
    } catch (error) {
        console.error("Delete Vehicle Error:", error);
        return res.status(500).json({ success: false, error: "ไม่สามารถลบข้อมูลรถได้" });
    }
};