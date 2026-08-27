// src/controllers/vehicleController.js
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const fs = require('fs');
const path = require('path');

// Helper Function: สำหรับลบไฟล์รูปภาพอย่างปลอดภัย
const safeDeleteFile = async (filePath) => {
    if (!filePath || typeof filePath !== 'string') {
        return;
    }

    if (fs.existsSync(filePath)) {
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
        console.log('[TRACE] vehicleController.getVehicles START');
        // 1. รับ Query Parameters
        const { search, status, page, limit } = req.query;
        
        const pageNum = parseInt(page) || 1;
        const limitNum = parseInt(limit) || 50; // ใส่ default ไว้กันแอปพังถ้าไม่ได้ส่งค่ามา
        const skip = (pageNum - 1) * limitNum;

        // 2. สร้าง เงื่อนไขการกรอง (Filter)
        const whereClause = { isDeleted: false };

        const allowedStatuses = ['AVAILABLE', 'IN_USE', 'MAINTENANCE', 'INACTIVE', 'RESERVED'];
        if (status) {
            const normalizedStatus = status.trim().toUpperCase().replace(/\s+/g, '_');
            if (allowedStatuses.includes(normalizedStatus)) {
                whereClause.status = normalizedStatus;
            }
        }

        // 3. เงื่อนไขการค้นหา (Search) 
        if (search) {
            whereClause.OR = [
                { vehicleName: { contains: search, mode: 'insensitive' } },
                { plateNumber: { contains: search, mode: 'insensitive' } },
                { brand: { contains: search, mode: 'insensitive' } },
                { model: { contains: search, mode: 'insensitive' } },
                { province: { contains: search, mode: 'insensitive' } }
            ];
        }

        // 4. Query Database (ดึงข้อมูลรถพร้อมเช็กคิวจองที่ยังไม่เสร็จสิ้นและข้อมูลเอกสาร)
        console.log(`[TRACE] vehicleController.getVehicles BEFORE PRISMA (Local Path: ${__dirname})`);
        const [totalItems, vehiclesList] = await Promise.all([
            prisma.vehicle.count({ where: whereClause }),
            prisma.vehicle.findMany({
                where: whereClause,
                include: {
                    bookings: {
                        where: {
                            status: { in: ['APPROVED', 'IN_USE'] },
                            endDatetime: { gt: new Date() } // เพิ่มเงื่อนไขให้ดึงเฉพาะคิวจองที่ยังไม่หมดเวลา
                        }
                    },
                    documents: {
                        include: {
                            documentType: true
                        }
                    }
                },
                orderBy: { createdAt: 'desc' },
                skip: skip,
                take: limitNum,
            })
        ]);

        // คำนวณสถานะการมีคิวจองในอนาคต (hasFutureBooking) สำหรับ UI และปรับ status ให้ตรงกับหน้าจองของ User
        const vehicles = vehiclesList.map(vehicle => {
            const hasActiveBooking = vehicle.bookings && vehicle.bookings.length > 0;
            const actDocument = vehicle.documents && vehicle.documents.find(d => d.documentType && d.documentType.name === 'พ.ร.บ.');
            
            // ปรับ status ถ้ามี active booking และสถานะปัจจุบันคือ AVAILABLE
            let displayStatus = vehicle.status;
            if (hasActiveBooking && vehicle.status === 'AVAILABLE') {
                displayStatus = 'RESERVED';
            }

            return {
                ...vehicle,
                status: displayStatus, // อัปเดต status ให้ตรงกับความเป็นจริง
                hasFutureBooking: hasActiveBooking,
                actDocumentNumber: actDocument ? actDocument.documentNumber : null,
                actIssueDate: actDocument ? actDocument.issueDate : null,
                actExpiryDate: actDocument ? actDocument.expiryDate : null,
                actUploadUrl: actDocument ? actDocument.uploadUrl : null
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
        console.error('[GET /api/vehicles] ERROR:', error);
        console.error('[GET /api/vehicles] STACK:', error?.stack);
        return res.status(500).json({ success: false, error: error.message || "ระบบขัดข้องในการดึงข้อมูลรถ" });
    }
};

// 2. เพิ่มข้อมูลรถยนต์ใหม่
exports.createVehicle = async (req, res) => {
    try {
        const { vehicleName, plateNumber, brand, model, seats, status, province, documentNumber, issueDate, expiryDate, actDocumentNumber, actIssueDate, actExpiryDate } = req.body;

        // 🟢 รองรับทั้งกรณี Multer ส่งไฟล์รูป และไฟล์ พ.ร.บ.
        const uploadedFile = req.file || (req.files && req.files.image && req.files.image[0]);
        const actFile = req.files && (req.files.actDocument?.[0] || req.files.actFile?.[0] || req.files.act_file?.[0] || req.files.document?.[0]);

        if (!plateNumber || !brand || !model) {
            if (uploadedFile) await safeDeleteFile(uploadedFile.path);
            if (actFile) await safeDeleteFile(actFile.path);
            return res.status(400).json({ success: false, error: "กรุณากรอกข้อมูลให้ครบถ้วน (ทะเบียน, ยี่ห้อ, รุ่น)" });
        }

        const seatNumber = parseInt(seats, 10);
        if (isNaN(seatNumber) || seatNumber <= 0) {
            if (uploadedFile) await safeDeleteFile(uploadedFile.path);
            if (actFile) await safeDeleteFile(actFile.path);
            return res.status(400).json({ success: false, error: "จำนวนที่นั่งต้องเป็นตัวเลขและมากกว่า 0 ขึ้นไป" });
        }

        const existingVehicle = await prisma.vehicle.findUnique({
            where: { plateNumber: plateNumber }
        });

        if (existingVehicle) {
            if (uploadedFile) await safeDeleteFile(uploadedFile.path);
            if (actFile) await safeDeleteFile(actFile.path);
            return res.status(400).json({ success: false, error: `ป้ายทะเบียน ${plateNumber} มีในระบบแล้ว` });
        }

        // 🟢 ตรวจสอบและแปลง Enum สถานะให้ตรงกับ Prisma Schema
        let normalizedStatus = status ? status.trim().toUpperCase().replace(/\s+/g, '_') : 'AVAILABLE';
        const allowedStatuses = ['AVAILABLE', 'IN_USE', 'MAINTENANCE', 'INACTIVE', 'RESERVED'];
        if (!allowedStatuses.includes(normalizedStatus)) {
            if (uploadedFile) await safeDeleteFile(uploadedFile.path);
            if (actFile) await safeDeleteFile(actFile.path);
            return res.status(400).json({ success: false, error: "สถานะรถยนต์ไม่ถูกต้อง" });
        }

        let uploadUrl = uploadedFile
            ? '/attachments/vehicles/images/' + uploadedFile.filename
            : (req.body.uploadUrl || null);

        if (
            uploadUrl &&
            uploadUrl.startsWith('/attachments/') &&
            !uploadUrl.startsWith('/attachments/vehicles/images/')
        ) {
            uploadUrl = uploadUrl.replace('/attachments/', '/attachments/vehicles/images/');
        }

        const newVehicle = await prisma.vehicle.create({
            data: {
                vehicleName: vehicleName || `${brand} ${model}`,
                plateNumber,
                brand,
                model,
                province: province || null,
                seats: seatNumber,
                status: normalizedStatus,
                uploadUrl: uploadUrl
            }
        });

        // 🟢 บันทึกเอกสาร พ.ร.บ. เข้าตาราง VehicleDocument
        const docNum = actDocumentNumber || documentNumber || null;
        
        let docIssue = null;
        const rawIssue = actIssueDate || issueDate;
        if (rawIssue) {
            const parsedIssueDate = new Date(rawIssue);
            if (isNaN(parsedIssueDate.getTime())) {
                if (uploadedFile) await safeDeleteFile(uploadedFile.path);
                if (actFile) await safeDeleteFile(actFile.path);
                return res.status(400).json({ success: false, error: "รูปแบบวันคุ้มครอง พ.ร.บ. ไม่ถูกต้อง" });
            }
            docIssue = parsedIssueDate;
        }

        let docExpiry = null;
        const rawExpiry = actExpiryDate || expiryDate;
        if (rawExpiry) {
            const parsedDate = new Date(rawExpiry);
            if (isNaN(parsedDate.getTime())) {
                if (uploadedFile) await safeDeleteFile(uploadedFile.path);
                if (actFile) await safeDeleteFile(actFile.path);
                return res.status(400).json({ success: false, error: "รูปแบบวันที่หมดอายุ พ.ร.บ. ไม่ถูกต้อง" });
            }
            docExpiry = parsedDate;
        }

        const actUploadUrl = actFile ? '/attachments/vehicles/images/' + actFile.filename : null;

        if (actFile || docNum || docIssue || docExpiry) {
            const docType = await prisma.documentType.upsert({
                where: { name: 'พ.ร.บ.' },
                update: {},
                create: { name: 'พ.ร.บ.' }
            });

            await prisma.vehicleDocument.create({
                data: {
                    vehicleId: newVehicle.id,
                    documentTypeId: docType.id,
                    documentNumber: docNum,
                    issueDate: docIssue,
                    expiryDate: docExpiry,
                    uploadUrl: actUploadUrl
                }
            });
        }

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

        const vehicleResponse = {
            ...newVehicle,
            actDocumentNumber: docNum || null,
            actIssueDate: docIssue || null,
            actExpiryDate: docExpiry || null,
            actUploadUrl: actUploadUrl || null
        };

        return res.status(201).json({ success: true, data: vehicleResponse, message: 'เพิ่มรถยนต์สำเร็จ' });
    } catch (error) {
        const uploadedFile = req.file || (req.files && req.files.image && req.files.image[0]);
        const actFile = req.files && (req.files.actDocument?.[0] || req.files.actFile?.[0] || req.files.act_file?.[0] || req.files.document?.[0]);
        if (uploadedFile) await safeDeleteFile(uploadedFile.path);
        if (actFile) await safeDeleteFile(actFile.path);
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

        const vehicle = await prisma.vehicle.findUnique({
            where: { id: vehicleId },
            include: {
                documents: {
                    include: {
                        documentType: true
                    }
                }
            }
        });

        if (!vehicle || vehicle.isDeleted) {
            return res.status(404).json({ success: false, error: "ไม่พบข้อมูลรถยนต์ในระบบ" });
        }

        const actDocument = vehicle.documents && vehicle.documents.find(d => d.documentType && d.documentType.name === 'พ.ร.บ.');
        const vehicleData = {
            ...vehicle,
            actDocumentNumber: actDocument ? actDocument.documentNumber : null,
            actIssueDate: actDocument ? actDocument.issueDate : null,
            actExpiryDate: actDocument ? actDocument.expiryDate : null,
            actUploadUrl: actDocument ? actDocument.uploadUrl : null
        };

        return res.status(200).json({ success: true, data: vehicleData });
    } catch (error) {
        console.error("Get Vehicle By ID Error:", error);
        return res.status(500).json({ success: false, error: "ระบบขัดข้องในการดึงข้อมูลรถ" });
    }
};

// 4. แก้ไขข้อมูลรถยนต์
exports.updateVehicle = async (req, res) => {
    try {
        const vehicleId = parseInt(req.params.id, 10);
        const { vehicleName, plateNumber, brand, model, seats, status, province, documentNumber, issueDate, expiryDate, actDocumentNumber, actIssueDate, actExpiryDate } = req.body;

        // 🟢 รองรับทั้งกรณี Multer ส่งไฟล์รูป และไฟล์ พ.ร.บ.
        const uploadedFile = req.file || (req.files && req.files.image && req.files.image[0]);
        const actFile = req.files && (req.files.actDocument?.[0] || req.files.actFile?.[0] || req.files.act_file?.[0] || req.files.document?.[0]);

        if (isNaN(vehicleId)) {
            if (uploadedFile) await safeDeleteFile(uploadedFile.path);
            if (actFile) await safeDeleteFile(actFile.path);
            return res.status(400).json({ success: false, error: "ID ของรถยนต์ไม่ถูกต้อง" });
        }

        // 🟢 ตรวจสอบและแปลง Enum สถานะให้ตรงกับ Prisma Schema (รองรับ RESERVED และ IN_USE)
        let normalizedStatus = status ? status.trim().toUpperCase().replace(/\s+/g, '_') : undefined;
        if (normalizedStatus) {
            const allowedStatuses = ['AVAILABLE', 'IN_USE', 'MAINTENANCE', 'INACTIVE', 'RESERVED'];
            if (!allowedStatuses.includes(normalizedStatus)) {
                if (uploadedFile) await safeDeleteFile(uploadedFile.path);
                if (actFile) await safeDeleteFile(actFile.path);
                return res.status(400).json({ success: false, error: "สถานะรถยนต์ไม่ถูกต้อง" });
            }
        }

        const existingVehicle = await prisma.vehicle.findUnique({ where: { id: vehicleId } });
        if (!existingVehicle || existingVehicle.isDeleted) {
            if (uploadedFile) await safeDeleteFile(uploadedFile.path);
            if (actFile) await safeDeleteFile(actFile.path);
            return res.status(404).json({ success: false, error: "ไม่พบข้อมูลรถยนต์ที่ต้องการแก้ไข" });
        }

        if (plateNumber && plateNumber !== existingVehicle.plateNumber) {
            const duplicatePlate = await prisma.vehicle.findUnique({ where: { plateNumber: plateNumber } });
            if (duplicatePlate) {
                if (uploadedFile) await safeDeleteFile(uploadedFile.path);
                if (actFile) await safeDeleteFile(actFile.path);
                return res.status(400).json({ success: false, error: `ป้ายทะเบียน ${plateNumber} มีในระบบแล้ว` });
            }
        }

        if (seats !== undefined && seats !== '') {
            const seatNumber = parseInt(seats, 10);
            if (isNaN(seatNumber) || seatNumber <= 0) {
                if (uploadedFile) await safeDeleteFile(uploadedFile.path);
                if (actFile) await safeDeleteFile(actFile.path);
                return res.status(400).json({ success: false, error: "จำนวนที่นั่งต้องเป็นตัวเลขและมากกว่า 0 ขึ้นไป" });
            }
        }

        let newUploadUrl = existingVehicle.uploadUrl;
        if (uploadedFile) {
            // ประกอบ Web URL Path โดยใช้ filename เพื่อให้พร้อมสำหรับ Frontend นำไปใช้งาน
            newUploadUrl = '/attachments/vehicles/images/' + uploadedFile.filename;
            if (existingVehicle.uploadUrl) {
                const oldFilePath = path.join(
                    __dirname,
                    '..',
                    '..',
                    existingVehicle.uploadUrl.replace(/^\/attachments\//, 'attachments/')
                );
                await safeDeleteFile(oldFilePath);
            }
        } else if (req.body.uploadUrl) {
            newUploadUrl = req.body.uploadUrl; // รองรับกรณีส่ง path มาตรงๆ

            if (
                newUploadUrl.startsWith('/attachments/') &&
                !newUploadUrl.startsWith('/attachments/vehicles/images/')
            ) {
                newUploadUrl = newUploadUrl.replace(
                    '/attachments/',
                    '/attachments/vehicles/images/'
                );
            }
        }

        const updatedVehicle = await prisma.vehicle.update({
            where: { id: vehicleId },
            data: {
                vehicleName: vehicleName || existingVehicle.vehicleName,
                plateNumber: plateNumber || existingVehicle.plateNumber,
                brand: brand || existingVehicle.brand,
                model: model || existingVehicle.model,
                province: province !== undefined ? province : existingVehicle.province,
                seats: (seats !== undefined && seats !== '') ? parseInt(seats, 10) : existingVehicle.seats,
                status: normalizedStatus || existingVehicle.status,
                uploadUrl: newUploadUrl
            }
        });

        // 🟢 บันทึก/อัปเดตเอกสาร พ.ร.บ. ใน VehicleDocument
        const docNum = actDocumentNumber || documentNumber;
        
        let docIssue = undefined;
        const rawIssue = actIssueDate || issueDate;
        if (rawIssue) {
            const parsedIssueDate = new Date(rawIssue);
            if (isNaN(parsedIssueDate.getTime())) {
                if (uploadedFile) await safeDeleteFile(uploadedFile.path);
                if (actFile) await safeDeleteFile(actFile.path);
                return res.status(400).json({ success: false, error: "รูปแบบวันคุ้มครอง พ.ร.บ. ไม่ถูกต้อง" });
            }
            docIssue = parsedIssueDate;
        }

        let docExpiry = undefined;
        const rawExpiry = actExpiryDate || expiryDate;
        if (rawExpiry) {
            const parsedDate = new Date(rawExpiry);
            if (isNaN(parsedDate.getTime())) {
                if (uploadedFile) await safeDeleteFile(uploadedFile.path);
                if (actFile) await safeDeleteFile(actFile.path);
                return res.status(400).json({ success: false, error: "รูปแบบวันที่หมดอายุ พ.ร.บ. ไม่ถูกต้อง" });
            }
            docExpiry = parsedDate;
        }

        let actUploadUrl = actFile ? '/attachments/vehicles/images/' + actFile.filename : undefined;

        if (actFile || docNum !== undefined || docIssue !== undefined || docExpiry !== undefined) {
            // 🟢 เพิ่ม Log นี้เข้าไป เพื่อบังคับให้ไฟล์มีการอัปเดต และเคลียร์บัคตัว F เก่าที่ค้างใน Docker
            console.log(`[DEBUG] updateVehicle: Processing document for Vehicle ID: ${vehicleId}`);
            
            const docType = await prisma.documentType.upsert({
                where: { name: 'พ.ร.บ.' },
                update: {},
                create: { name: 'พ.ร.บ.' }
            });

            const existingDoc = await prisma.vehicleDocument.findFirst({
                where: {
                    vehicleId: vehicleId,
                    documentTypeId: docType.id
                }
            });

            if (existingDoc) {
                await prisma.vehicleDocument.update({
                    where: { id: existingDoc.id },
                    data: {
                        documentNumber: docNum !== undefined ? docNum : existingDoc.documentNumber,
                        issueDate: docIssue !== undefined ? docIssue : existingDoc.issueDate,
                        expiryDate: docExpiry !== undefined ? docExpiry : existingDoc.expiryDate,
                        uploadUrl: actUploadUrl !== undefined ? actUploadUrl : existingDoc.uploadUrl
                    }
                });
            } else {
                await prisma.vehicleDocument.create({
                    data: {
                        vehicleId: vehicleId,
                        documentTypeId: docType.id,
                        documentNumber: docNum || null,
                        issueDate: docIssue || null,
                        expiryDate: docExpiry || null,
                        uploadUrl: actUploadUrl || null
                    }
                });
            }
        }

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

        const actDocument = await prisma.vehicleDocument.findFirst({
            where: {
                vehicleId: vehicleId,
                documentType: { name: 'พ.ร.บ.' }
            }
        });

        const vehicleResponse = {
            ...updatedVehicle,
            actDocumentNumber: actDocument ? actDocument.documentNumber : null,
            actIssueDate: actDocument ? actDocument.issueDate : null,
            actExpiryDate: actDocument ? actDocument.expiryDate : null,
            actUploadUrl: actDocument ? actDocument.uploadUrl : null
        };

        return res.status(200).json({ success: true, data: vehicleResponse, message: "แก้ไขข้อมูลรถสำเร็จ" });
    } catch (error) {
        const uploadedFile = req.file || (req.files && req.files.image && req.files.image[0]);
        const actFile = req.files && (req.files.actDocument?.[0] || req.files.actFile?.[0] || req.files.act_file?.[0] || req.files.document?.[0]);
        if (uploadedFile) await safeDeleteFile(uploadedFile.path);
        if (actFile) await safeDeleteFile(actFile.path);
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
            return res.status(409).json({ 
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

        // 🟢 1. ตรวจสอบ Enum สถานะที่อนุญาต และแปลงเป็น Format มาตรฐาน
        const normalizedStatus = status ? status.trim().toUpperCase().replace(/\s+/g, '_') : null;
        const allowedStatuses = ['AVAILABLE', 'IN_USE', 'MAINTENANCE', 'INACTIVE', 'RESERVED'];
        if (!normalizedStatus || !allowedStatuses.includes(normalizedStatus)) {
            return res.status(400).json({ success: false, error: "สถานะรถยนต์ไม่ถูกต้อง" });
        }

        const existingVehicle = await prisma.vehicle.findUnique({ where: { id: vehicleId } });
        if (!existingVehicle || existingVehicle.isDeleted) {
            return res.status(404).json({ success: false, error: "ไม่พบข้อมูลรถยนต์ที่ต้องการเปลี่ยนสถานะ" });
        }

        // 🟢 2. Business Logic: ปิดการบล็อก 409 เพื่อให้ Admin สามารถเปลี่ยนสถานะรถฉุกเฉิน (เช่น รถเสียต้องเข้า MAINTENANCE) ได้ทันทีแม้จะมีคิวจองล่วงหน้าอยู่
        /*
        if (normalizedStatus === 'MAINTENANCE' || normalizedStatus === 'INACTIVE') {
            const futureBookings = await prisma.vehicleBooking.findMany({
                where: {
                    vehicleId: vehicleId,
                    endDatetime: { gt: new Date() },
                    status: { notIn: ['CANCELLED', 'REJECTED'] }
                }
            });

            if (futureBookings.length > 0) {
                return res.status(409).json({ 
                    success: false, 
                    error: `ไม่สามารถเปลี่ยนสถานะเป็น ${normalizedStatus} ได้ เนื่องจากมีรายการจองในอนาคตค้างอยู่ ${futureBookings.length} รายการ`
                });
            }
        }
        */

        const updatedVehicle = await prisma.vehicle.update({
            where: { id: vehicleId },
            data: { status: normalizedStatus }
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
                    details: `User ${actionUserId} updated status of vehicle ID ${vehicleId} from ${existingVehicle.status} to ${normalizedStatus}`
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