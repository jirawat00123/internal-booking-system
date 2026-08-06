// src/controllers/vehicleController.js
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const fs = require('fs');
const path = require('path');

// 🎯 Helper Function: สำหรับลบไฟล์หลายไฟล์อย่างปลอดภัย (รองรับ req.files)
const safeDeleteFiles = async (files) => {
    if (!files) return;
    const fileArray = [];
    if (files['image']) fileArray.push(files['image'][0].path);
    if (files['document']) fileArray.push(files['document'][0].path);
    
    for (const filePath of fileArray) {
        if (filePath && fs.existsSync(filePath)) {
            try {
                await fs.promises.unlink(filePath);
            } catch (err) {
                console.error("Error deleting file:", err);
            }
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
        const { vehicleName, plateNumber, brand, model, seats, status } = req.body;
        
        if (!plateNumber || !brand || !model) {
            await safeDeleteFiles(req.files);
            return res.status(400).json({ success: false, error: "กรุณากรอกข้อมูลให้ครบถ้วน (ทะเบียน, ยี่ห้อ, รุ่น)" });
        }

        const seatNumber = parseInt(seats, 10);
        if (isNaN(seatNumber) || seatNumber <= 0) {
            await safeDeleteFiles(req.files);
            return res.status(400).json({ success: false, error: "จำนวนที่นั่งต้องเป็นตัวเลขและมากกว่า 0 ขึ้นไป" });
        }

        const existingVehicle = await prisma.vehicle.findUnique({
            where: { plateNumber: plateNumber }
        });

        if (existingVehicle) {
            await safeDeleteFiles(req.files);
            return res.status(400).json({ success: false, error: `ป้ายทะเบียน ${plateNumber} มีในระบบแล้ว` });
        }
        
        // 🎯 จัดการไฟล์รูปภาพและเอกสารจาก req.files
        let uploadUrl = req.body.uploadUrl || null;
        let uploadPororborUrl = req.body.uploadPororborUrl || null;

        if (req.files) {
            if (req.files['image'] && req.files['image'][0]) {
                uploadUrl = `/uploads/vehicles/${req.files['image'][0].filename}`;
            }
            if (req.files['document'] && req.files['document'][0]) {
                uploadPororborUrl = `/uploads/vehicles/${req.files['document'][0].filename}`;
            }
        }

        const newVehicle = await prisma.vehicle.create({
            data: {
                vehicleName: vehicleName || `${brand} ${model}`,
                plateNumber,
                brand,
                model,
                seats: seatNumber,
                status: status || 'AVAILABLE',
                uploadUrl: uploadUrl,
                uploadPororborUrl: uploadPororborUrl // 🎯 บันทึก URL เอกสารลงฐานข้อมูล
            }
        });

        // 🟢 บันทึก AuditLog เมื่อเพิ่มรถยนต์สำเร็จ
        const actionUserId = req.user?.userId ? parseInt(req.user.userId, 10) : null;
        if (actionUserId) {
            await prisma.auditLog.create({
                data: {
                    action: "CREATE_VEHICLE",
                    module: "VEHICLE",
                    entityId: newVehicle.id,
                    entityType: "VEHICLE",
                    userId: actionUserId,
                    details: `User ${actionUserId} created vehicle ID ${newVehicle.id} (${newVehicle.plateNumber})`
                }
            }).catch(err => console.error("AuditLog Error [CREATE_VEHICLE]:", err.message));
        }

        return res.status(201).json({ success: true, data: newVehicle, message: 'เพิ่มรถยนต์สำเร็จ' });
    } catch (error) {
        await safeDeleteFiles(req.files);
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
        const { vehicleName, plateNumber, brand, model, seats, status } = req.body;

        if (isNaN(vehicleId)) {
            await safeDeleteFiles(req.files);
            return res.status(400).json({ success: false, error: "ID ของรถยนต์ไม่ถูกต้อง" });
        }

        const existingVehicle = await prisma.vehicle.findUnique({ where: { id: vehicleId } });
        if (!existingVehicle || existingVehicle.isDeleted) {
            await safeDeleteFiles(req.files);
            return res.status(404).json({ success: false, error: "ไม่พบข้อมูลรถยนต์ที่ต้องการแก้ไข" });
        }

        if (plateNumber && plateNumber !== existingVehicle.plateNumber) {
            const duplicatePlate = await prisma.vehicle.findUnique({ where: { plateNumber: plateNumber } });
            if (duplicatePlate) {
                await safeDeleteFiles(req.files);
                return res.status(400).json({ success: false, error: `ป้ายทะเบียน ${plateNumber} มีในระบบแล้ว` });
            }
        }

        // 🎯 จัดการไฟล์รูปภาพและเอกสาร
        let newUploadUrl = existingVehicle.uploadUrl;
        let newPororborUrl = existingVehicle.uploadPororborUrl;

        if (req.files) {
            // ถ้ารูปถูกส่งมาใหม่
            if (req.files['image'] && req.files['image'][0]) {
                newUploadUrl = `/uploads/vehicles/${req.files['image'][0].filename}`;
                // ลบรูปเก่าทิ้ง (ถ้ามี)
                if (existingVehicle.uploadUrl) {
                    const oldFilePath = path.join(process.cwd(), existingVehicle.uploadUrl);
                    if (fs.existsSync(oldFilePath)) fs.unlinkSync(oldFilePath);
                }
            }
            // ถ้าเอกสาร พรบ. ถูกส่งมาใหม่
            if (req.files['document'] && req.files['document'][0]) {
                newPororborUrl = `/uploads/vehicles/${req.files['document'][0].filename}`;
                // ลบเอกสารเก่าทิ้ง (ถ้ามี)
                if (existingVehicle.uploadPororborUrl) {
                    const oldDocPath = path.join(process.cwd(), existingVehicle.uploadPororborUrl);
                    if (fs.existsSync(oldDocPath)) fs.unlinkSync(oldDocPath);
                }
            }
        } 
        
        // รองรับกรณีส่ง path มาตรงๆ ผ่าน body
        if (req.body.uploadUrl) newUploadUrl = req.body.uploadUrl;
        if (req.body.uploadPororborUrl) newPororborUrl = req.body.uploadPororborUrl;

        const updatedVehicle = await prisma.vehicle.update({
            where: { id: vehicleId },
            data: {
                vehicleName: vehicleName || existingVehicle.vehicleName,
                plateNumber: plateNumber || existingVehicle.plateNumber,
                brand: brand || existingVehicle.brand,
                model: model || existingVehicle.model,
                seats: seats ? parseInt(seats, 10) : existingVehicle.seats,
                status: status || existingVehicle.status,
                uploadUrl: newUploadUrl,
                uploadPororborUrl: newPororborUrl // 🎯 อัปเดต URL เอกสารลงฐานข้อมูล
            }
        });

        // 🟢 บันทึก AuditLog เมื่อแก้ไขข้อมูลรถยนต์สำเร็จ
        const actionUserId = req.user?.userId ? parseInt(req.user.userId, 10) : null;
        if (actionUserId) {
            await prisma.auditLog.create({
                data: {
                    action: 'UPDATE_VEHICLE',
                    module: 'VEHICLE',
                    userId: actionUserId,
                    entityId: vehicleId,
                    entityType: 'VEHICLE',
                    details: `User ${actionUserId} updated details for vehicle ID ${vehicleId}`
                }
            }).catch(err => console.error("AuditLog Error [updateVehicle]:", err.message));
        }

        return res.status(200).json({ success: true, data: updatedVehicle, message: "แก้ไขข้อมูลรถสำเร็จ" });
    } catch (error) {
        await safeDeleteFiles(req.files);
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

        // 🟢 บันทึก AuditLog เมื่อลบข้อมูลรถยนต์สำเร็จ
        const actionUserId = req.user?.userId ? parseInt(req.user.userId, 10) : null;
        if (actionUserId) {
            await prisma.auditLog.create({
                data: {
                    action: 'DELETE_VEHICLE',
                    module: 'VEHICLE',
                    userId: actionUserId,
                    entityId: vehicleId,
                    entityType: 'VEHICLE',
                    details: `User ${actionUserId} soft deleted vehicle ID ${vehicleId}`
                }
            }).catch(err => console.error("AuditLog Error [deleteVehicle]:", err.message));
        }

        return res.status(200).json({ success: true, message: "ลบข้อมูลรถออกจากระบบสำเร็จ (Soft Delete)" });
    } catch (error) {
        console.error("Delete Vehicle Error:", error);
        return res.status(500).json({ success: false, error: "ไม่สามารถลบข้อมูลรถได้" });
    }
};