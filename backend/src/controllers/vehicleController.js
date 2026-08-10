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
        // 1. รับ Query Parameters
        const { search, status, page, limit } = req.query;
        
        const pageNum = parseInt(page) || 1;
        const limitNum = parseInt(limit) || 50; // ใส่ default ไว้กันแอปพังถ้าไม่ได้ส่งค่ามา
        const skip = (pageNum - 1) * limitNum;

        // 2. สร้าง เงื่อนไขการกรอง (Filter)
        const whereClause = { isDeleted: false };

        if (status) {
            whereClause.status = status;
        }

        // 3. เงื่อนไขการค้นหา (Search) 
        if (search) {
            whereClause.OR = [
                { vehicleName: { contains: search, mode: 'insensitive' } },
                { plateNumber: { contains: search, mode: 'insensitive' } },
                { brand: { contains: search, mode: 'insensitive' } },
                { model: { contains: search, mode: 'insensitive' } }
            ];
        }

        // 4. Query Database (ดึงข้อมูลรถพร้อมเช็กคิวจองที่ยังไม่เสร็จสิ้น)
        const [totalItems, vehiclesList] = await Promise.all([
            prisma.vehicle.count({ where: whereClause }),
            prisma.vehicle.findMany({
                where: whereClause,
                include: {
                    bookings: {
                        where: {
                            status: { in: ['APPROVED', 'RESERVED', 'IN_USE'] }
                        }
                    }
                },
                orderBy: { createdAt: 'desc' },
                skip: skip,
                take: limitNum,
            })
        ]);

        // คำนวณสถานะรถแบบ Real-time (ถ้ามีคิวจองค้างอยู่ให้ถือว่าเป็น RESERVED)
        const vehicles = vehiclesList.map(vehicle => {
            const hasActiveBooking = vehicle.bookings && vehicle.bookings.length > 0;
            return {
                ...vehicle,
                status: (vehicle.status === 'AVAILABLE' && hasActiveBooking) ? 'RESERVED' : vehicle.status
            };
        });

        // 5. ส่ง Response กลับพร้อมโครงสร้าง Pagination
        return res.status(200).json({ 
            success: true, 
            data: vehicles,
            pagination: {
                page: pageNum,
                limit: limitNum,
                total: totalItems,
                totalPages: Math.ceil(totalItems / limitNum)
            }
        });
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
            where: { plateNumber: plateNumber }
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

        // 🟢 บันทึก AuditLog เมื่อเพิ่มรถยนต์สำเร็จ (รองรับทั้ง req.user.id และ req.user.userId)
        const rawUserId = req.user?.id || req.user?.userId;
        const actionUserId = rawUserId ? parseInt(rawUserId, 10) : null;
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

        // 🟢 ตรวจสอบ Enum สถานะที่อนุญาต (ถ้ามีการส่ง status มาเพื่ออัปเดต)
        if (status) {
            const allowedStatuses = ['AVAILABLE', 'IN_USE', 'RESERVED', 'MAINTENANCE', 'INACTIVE'];
            if (!allowedStatuses.includes(status)) {
                if (req.file) await safeDeleteFile(req.file.path);
                return res.status(400).json({ success: false, error: "สถานะรถยนต์ไม่ถูกต้อง" });
            }
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

        // 🟢 บันทึก AuditLog เมื่อแก้ไขข้อมูลรถยนต์สำเร็จ (รองรับทั้ง req.user.id และ req.user.userId)
        const rawUserId = req.user?.id || req.user?.userId;
        const actionUserId = rawUserId ? parseInt(rawUserId, 10) : null;
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
                status: { notIn: ['CANCELLED', 'REJECTED'] }
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
            data: { isDeleted: true }
        });

        // 🟢 บันทึก AuditLog เมื่อลบข้อมูลรถยนต์สำเร็จ (รองรับทั้ง req.user.id และ req.user.userId)
        const rawUserId = req.user?.id || req.user?.userId;
        const actionUserId = rawUserId ? parseInt(rawUserId, 10) : null;
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

// 6. อัปเดตเฉพาะสถานะรถยนต์ (PATCH /vehicles/:id/status)
exports.updateVehicleStatus = async (req, res) => {
    try {
        const vehicleId = parseInt(req.params.id, 10);
        const { status } = req.body;

        if (isNaN(vehicleId)) {
            return res.status(400).json({ success: false, error: "ID ของรถยนต์ไม่ถูกต้อง" });
        }

        // 🟢 1. ตรวจสอบ Enum สถานะที่อนุญาต
        const allowedStatuses = ['AVAILABLE', 'IN_USE', 'RESERVED', 'MAINTENANCE', 'INACTIVE'];
        if (!status || !allowedStatuses.includes(status)) {
            return res.status(400).json({ success: false, error: "สถานะรถยนต์ไม่ถูกต้อง" });
        }

        const existingVehicle = await prisma.vehicle.findUnique({ where: { id: vehicleId } });
        if (!existingVehicle || existingVehicle.isDeleted) {
            return res.status(404).json({ success: false, error: "ไม่พบข้อมูลรถยนต์ที่ต้องการเปลี่ยนสถานะ" });
        }

        // 🟢 2. Business Logic: ถ้าเปลี่ยนเป็น MAINTENANCE หรือ INACTIVE ต้องเช็กคิวจองในอนาคตก่อน
        if (status === 'MAINTENANCE' || status === 'INACTIVE') {
            const futureBookings = await prisma.vehicleBooking.findMany({
                where: {
                    vehicleId: vehicleId,
                    endDatetime: { gt: new Date() },
                    status: { notIn: ['CANCELLED', 'REJECTED'] }
                }
            });

            if (futureBookings.length > 0) {
                return res.status(400).json({ 
                    success: false, 
                    error: `ไม่สามารถเปลี่ยนสถานะเป็น ${status} ได้ เนื่องจากมีรายการจองในอนาคตค้างอยู่ ${futureBookings.length} รายการ`
                });
            }
        }

        const updatedVehicle = await prisma.vehicle.update({
            where: { id: vehicleId },
            data: { status }
        });

        // 🟢 บันทึก AuditLog เมื่ออัปเดตสถานะรถยนต์สำเร็จ (รองรับทั้ง req.user.id และ req.user.userId)
        const rawUserId = req.user?.id || req.user?.userId;
        const actionUserId = rawUserId ? parseInt(rawUserId, 10) : null;
        if (actionUserId) {
            await prisma.auditLog.create({
                data: {
                    action: 'UPDATE_VEHICLE_STATUS',
                    module: 'VEHICLE',
                    userId: actionUserId,
                    entityId: vehicleId,
                    entityType: 'VEHICLE',
                    details: `User ${actionUserId} updated status of vehicle ID ${vehicleId} from ${existingVehicle.status} to ${status}`
                }
            }).catch(err => console.error("AuditLog Error [updateVehicleStatus]:", err.message));
        }

        return res.status(200).json({ 
            success: true, 
            data: updatedVehicle, 
            message: "อัปเดตสถานะรถยนต์สำเร็จ" 
        });
    } catch (error) {
        console.error("Update Vehicle Status Error:", error);
        return res.status(500).json({ success: false, error: "ไม่สามารถอัปเดตสถานะรถได้" });
    }
};