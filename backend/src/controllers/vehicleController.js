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

// Helper Function: สำหรับจัดการและย้ายไฟล์ไปยัง NAS / Target Directory
const saveFileToNAS = (file, subFolder) => {
    if (!file) return null;
    const nasPath = path.normalize('/Internal Booking System/Internal Booking System/attachments');
    const localFallbackPath = path.resolve(__dirname, '../../attachments');

    let baseUploadDir = process.env.UPLOAD_DIR;
    
    // 🟢 ป้องกันกรณี UPLOAD_DIR เป็น Path สัมพัทธ์ หรือชี้ไปที่ uploads ภายใน backend
    if (baseUploadDir && !path.isAbsolute(baseUploadDir)) {
        baseUploadDir = path.resolve(__dirname, '../../', baseUploadDir);
    }

    if (!baseUploadDir || baseUploadDir.includes('uploads') || baseUploadDir.includes('backend')) {
        try {
            fs.accessSync(nasPath, fs.constants.R_OK | fs.constants.W_OK);
            baseUploadDir = nasPath;
        } catch (err) {
            baseUploadDir = localFallbackPath;
        }
    }

    // 🟢 บังคับเฉพาะไฟล์ พ.ร.บ. (documents) ให้เซฟลง attachments ตาม Path ที่ระบุเท่านั้น (ห้ามอยู่ใน backend)
        if (subFolder === 'documents') {
            try {
                fs.accessSync(nasPath, fs.constants.R_OK | fs.constants.W_OK);
                baseUploadDir = nasPath;
            } catch (err) {
                baseUploadDir = localFallbackPath;
            }
        }

    const targetDir = path.join(baseUploadDir, 'vehicles', subFolder);

    if (!fs.existsSync(targetDir)) {
        fs.mkdirSync(targetDir, { recursive: true, mode: 0o777 });
    }

    let filename = file.filename || (file.path ? path.basename(file.path) : null) || file.originalname || `${Date.now()}-${Math.round(Math.random() * 1e9)}${path.extname(file.originalname || '')}`;

    if (subFolder === 'documents') {
        filename = filename.replace(/^(vehicle_|file_)/, 'act_');
        if (!filename.startsWith('act_')) {
            filename = 'act_' + filename;
        }
    } else if (subFolder === 'images') {
        filename = filename.replace(/^(act_|file_)/, 'vehicle_');
        if (!filename.startsWith('vehicle_')) {
            filename = 'vehicle_' + filename;
        }
    }
    file.filename = filename;

    const destPath = path.join(targetDir, filename);

    if (file.buffer) {
        fs.writeFileSync(destPath, file.buffer);
        try { fs.chmodSync(destPath, 0o777); } catch (e) {}
    } else if (file.path) {
        const normalizedSrc = path.normalize(file.path);
        const normalizedDest = path.normalize(destPath);
        if (normalizedSrc !== normalizedDest && fs.existsSync(normalizedSrc)) {
            fs.copyFileSync(normalizedSrc, normalizedDest);
            try { fs.chmodSync(normalizedDest, 0o777); } catch (e) {}
            try { fs.unlinkSync(normalizedSrc); } catch (e) {}
        } else if (fs.existsSync(normalizedDest)) {
            try { fs.chmodSync(normalizedDest, 0o777); } catch (e) {}
        }
    }

    return '/attachments/vehicles/' + subFolder + '/' + filename;
};

// 1. ดึงข้อมูลรถยนต์ทั้งหมด
exports.getVehicles = async (req, res) => {
    try {
        console.log('[TRACE] vehicleController.getVehicles START');

        // 🧪 ทดสอบ Query รถทั้งหมดใน DB โดยไม่ใส่ Filter เพื่อตรวจสอบข้อมูลดิบ
        const testVehicles = await prisma.vehicle.findMany();
        console.log('[DEBUG] All Vehicles in DB:', testVehicles);

        // 1. รับ Query Parameters
        const { search, status, page, limit } = req.query;
        
        const pageNum = parseInt(page, 10) || 1;
        const limitNum = parseInt(limit, 10) || 50;
        const skip = (pageNum - 1) * limitNum;

        // 2. สร้าง เงื่อนไขการกรอง (Filter)
        const whereClause = {
            isDeleted: false
        };

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

        console.log(`[TRACE] vehicleController.getVehicles BEFORE PRISMA`, { pageNum, limitNum, skip, whereClause });

        const totalItems = await prisma.vehicle.count({ where: whereClause });

        // ตรวจสอบว่า skip เกินจำนวนข้อมูลที่มีหรือไม่ หากเกินให้รีเซ็ตกลับเป็น 0
        const actualSkip = (skip >= totalItems && totalItems > 0) ? 0 : skip;

        const vehiclesList = await prisma.vehicle.findMany({
            where: whereClause,
            include: {
                documents: {
                    include: {
                        documentType: true
                    }
                }
            },
            orderBy: { id: 'asc' },
            skip: (page || limit) ? actualSkip : undefined,
            take: (page || limit) ? limitNum : undefined,
        });

        // จัดรูปแบบข้อมูล Master Data ของรถยนต์และเอกสาร พ.ร.บ. (ผูก Alias ให้ครอบคลุมทุก UI)
        const vehicles = vehiclesList.map(vehicle => {
            const actDocument = vehicle.documents && vehicle.documents.find(d => d.documentType && (d.documentType.name?.includes('พ.ร.บ') || d.documentType.name?.includes('พรบ')));
            const actUrl = actDocument ? actDocument.uploadUrl : null;
            const computedName = vehicle.vehicleName || [vehicle.brand, vehicle.model].filter(Boolean).join(' ') || vehicle.plateNumber || 'ไม่ระบุรุ่น';
            const plate = vehicle.plateNumber || vehicle.plate_number || vehicle.licensePlate || 'ไม่ระบุทะเบียน';
            const seatVal = vehicle.capacity || vehicle.seats || vehicle.seatCapacity || 4;

            return {
                ...vehicle,
                name: computedName,
                vehicleName: computedName,
                title: computedName,
                plateNumber: plate,
                plate_number: plate,
                licensePlate: plate,
                capacity: seatVal,
                seats: seatVal,
                seatCapacity: seatVal,
                status: vehicle.status || 'AVAILABLE',
                actDocumentNumber: actDocument ? actDocument.documentNumber : null,
                actIssueDate: actDocument ? actDocument.issueDate : null,
                actExpiryDate: actDocument ? actDocument.expiryDate : null,
                actUploadUrl: actUrl,
                actDocumentUrl: actUrl,
                actFilePath: actUrl,
                act_file_path: actUrl,
                actFile: actUrl,
                act_file: actUrl,
                actUrl: actUrl,
                pororborUrl: actUrl
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
                totalPages: Math.ceil(totalItems / limitNum) || 1
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

        // 🟢 รองรับทั้งกรณี Multer ส่งไฟล์รูป และไฟล์ พ.ร.บ. (รองรับทั้ง req.file, req.files แบบ Array และ Object)
        let uploadedFile = null;
        let actFile = null;

        if (req.file) {
            const singleFn = (req.file.fieldname || '').toLowerCase();
            const isAct = singleFn.includes('act') || singleFn.includes('pororbor') || singleFn.includes('doc') || singleFn.includes('pdf') || ['actdocument', 'actfile', 'act_file', 'document', 'doc', 'pdf', 'pororborfile', 'actfilepath', 'act_file_path'].includes(singleFn) || req.file.mimetype === 'application/pdf' || (req.file.originalname || '').toLowerCase().endsWith('.pdf') || ((actDocumentNumber || actExpiryDate || actIssueDate || documentNumber || expiryDate) && !['image', 'uploadurl', 'upload_url', 'vehicle_image'].includes(singleFn));
            if (isAct) {
                actFile = req.file;
            } else {
                uploadedFile = req.file;
            }
        }

        if (Array.isArray(req.files)) {
            actFile = actFile || req.files.find(f => (f.fieldname || '').toLowerCase().includes('act') || (f.fieldname || '').toLowerCase().includes('pororbor') || (f.fieldname || '').toLowerCase().includes('doc') || ['actdocument', 'actfile', 'act_file', 'document', 'doc', 'pdf', 'pororborfile', 'actfilepath', 'act_file_path'].includes((f.fieldname || '').toLowerCase()) || f.mimetype === 'application/pdf' || (f.originalname || '').toLowerCase().endsWith('.pdf'));
            uploadedFile = uploadedFile || req.files.find(f => f !== actFile && (['image', 'uploadurl', 'upload_url', 'vehicle_image'].includes((f.fieldname || '').toLowerCase()) || f.mimetype.startsWith('image/')));
        } else if (req.files && typeof req.files === 'object') {
            actFile = actFile || req.files.actDocument?.[0] || req.files.actFile?.[0] || req.files.act_file?.[0] || req.files.act?.[0] || req.files.document?.[0] || req.files.doc?.[0] || req.files.pdf?.[0] || req.files.pororbor?.[0] || req.files.pororborFile?.[0] || req.files.actFilePath?.[0];
            uploadedFile = uploadedFile || req.files.image?.[0] || req.files.uploadUrl?.[0] || req.files.vehicle_image?.[0] || req.files.file?.[0];
        }

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
            ? saveFileToNAS(uploadedFile, 'images')
            : (req.body.uploadUrl || null);

        if (uploadUrl) {
            uploadUrl = '/attachments/vehicles/images/' + path.basename(uploadUrl);
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

        let actUploadUrl = actFile ? saveFileToNAS(actFile, 'documents') : (req.body.actUploadUrl || req.body.actDocumentUrl || req.body.actFile || req.body.pororborUrl || null);
        if (actUploadUrl) {
            actUploadUrl = '/attachments/vehicles/documents/' + path.basename(actUploadUrl);
        }

        if (actFile || actUploadUrl || docNum || docIssue || docExpiry) {
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
            actUploadUrl: actUploadUrl || null,
            actDocumentUrl: actUploadUrl || null,
            actFilePath: actUploadUrl || null,
            act_file_path: actUploadUrl || null,
            actFile: actUploadUrl || null,
            act_file: actUploadUrl || null,
            actUrl: actUploadUrl || null,
            pororborUrl: actUploadUrl || null
        };

        return res.status(201).json({ success: true, data: vehicleResponse, message: 'เพิ่มรถยนต์สำเร็จ' });
    } catch (error) {
        let uploadedFile = null;
        let actFile = null;
        if (req.file) {
            const singleFn = (req.file.fieldname || '').toLowerCase();
            const isAct = singleFn.includes('act') || ['actdocument', 'actfile', 'act_file', 'document', 'doc', 'pdf'].includes(singleFn) || req.file.mimetype === 'application/pdf' || (req.file.originalname || '').toLowerCase().endsWith('.pdf');
            if (isAct) actFile = req.file;
            else uploadedFile = req.file;
        }
        if (Array.isArray(req.files)) {
            actFile = actFile || req.files.find(f => (f.fieldname || '').toLowerCase().includes('act') || ['actdocument', 'actfile', 'act_file', 'document', 'doc', 'pdf'].includes((f.fieldname || '').toLowerCase()) || f.mimetype === 'application/pdf' || (f.originalname || '').toLowerCase().endsWith('.pdf'));
            uploadedFile = uploadedFile || req.files.find(f => f !== actFile && (['image', 'uploadurl', 'upload_url', 'vehicle_image'].includes((f.fieldname || '').toLowerCase()) || f.mimetype.startsWith('image/')));
        } else if (req.files && typeof req.files === 'object') {
            actFile = actFile || req.files.actDocument?.[0] || req.files.actFile?.[0] || req.files.act_file?.[0] || req.files.act?.[0] || req.files.document?.[0] || req.files.doc?.[0] || req.files.pdf?.[0];
            uploadedFile = uploadedFile || req.files.image?.[0] || req.files.uploadUrl?.[0] || req.files.vehicle_image?.[0] || req.files.file?.[0];
        }
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

        const actDocument = vehicle.documents && vehicle.documents.find(d => d.documentType && (d.documentType.name?.includes('พ.ร.บ') || d.documentType.name?.includes('พรบ')));
        const actUrl = actDocument ? actDocument.uploadUrl : null;
        
        // คำนวณชื่อรถยนต์ (กรณีไม่มี vehicleName จะใช้ Brand + Model หรือ ทะเบียนรถแทน) ให้สอดคล้องกับ getVehicles
        const computedName = vehicle.vehicleName || [vehicle.brand, vehicle.model].filter(Boolean).join(' ') || vehicle.plateNumber || null;

        const vehicleData = {
            ...vehicle,
            vehicleName: computedName,
            actDocumentNumber: actDocument ? actDocument.documentNumber : null,
            actIssueDate: actDocument ? actDocument.issueDate : null,
            actExpiryDate: actDocument ? actDocument.expiryDate : null,
            actUploadUrl: actUrl,
            actDocumentUrl: actUrl,
            actFilePath: actUrl,
            act_file_path: actUrl,
            actFile: actUrl,
            act_file: actUrl,
            actUrl: actUrl,
            pororborUrl: actUrl
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

        // 🟢 รองรับทั้งกรณี Multer ส่งไฟล์รูป และไฟล์ พ.ร.บ. (รองรับทั้ง req.file, req.files แบบ Array และ Object)
        let uploadedFile = null;
        let actFile = null;

        if (req.file) {
            const singleFn = (req.file.fieldname || '').toLowerCase();
            const isAct = singleFn.includes('act') || singleFn.includes('pororbor') || singleFn.includes('doc') || singleFn.includes('pdf') || ['actdocument', 'actfile', 'act_file', 'document', 'doc', 'pdf', 'pororborfile', 'actfilepath', 'act_file_path'].includes(singleFn) || req.file.mimetype === 'application/pdf' || (req.file.originalname || '').toLowerCase().endsWith('.pdf') || ((actDocumentNumber || actExpiryDate || actIssueDate || documentNumber || expiryDate) && !['image', 'uploadurl', 'upload_url', 'vehicle_image'].includes(singleFn));
            if (isAct) {
                actFile = req.file;
            } else {
                uploadedFile = req.file;
            }
        }

        if (Array.isArray(req.files)) {
            actFile = actFile || req.files.find(f => (f.fieldname || '').toLowerCase().includes('act') || (f.fieldname || '').toLowerCase().includes('pororbor') || (f.fieldname || '').toLowerCase().includes('doc') || ['actdocument', 'actfile', 'act_file', 'document', 'doc', 'pdf', 'pororborfile', 'actfilepath', 'act_file_path'].includes((f.fieldname || '').toLowerCase()) || f.mimetype === 'application/pdf' || (f.originalname || '').toLowerCase().endsWith('.pdf'));
            uploadedFile = uploadedFile || req.files.find(f => f !== actFile && (['image', 'uploadurl', 'upload_url', 'vehicle_image'].includes((f.fieldname || '').toLowerCase()) || f.mimetype.startsWith('image/')));
        } else if (req.files && typeof req.files === 'object') {
            actFile = actFile || req.files.actDocument?.[0] || req.files.actFile?.[0] || req.files.act_file?.[0] || req.files.act?.[0] || req.files.document?.[0] || req.files.doc?.[0] || req.files.pdf?.[0] || req.files.pororbor?.[0] || req.files.pororborFile?.[0] || req.files.actFilePath?.[0];
            uploadedFile = uploadedFile || req.files.image?.[0] || req.files.uploadUrl?.[0] || req.files.vehicle_image?.[0] || req.files.file?.[0];
        }

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
            // ประกอบ Web URL Path โดยใช้ filename และเซฟไฟล์ลง NAS
            newUploadUrl = saveFileToNAS(uploadedFile, 'images');
            if (existingVehicle.uploadUrl) {
                const nasPath = path.normalize('/Internal Booking System/Internal Booking System/attachments');
                const localFallbackPath = path.resolve(__dirname, '../../attachments');
                let baseUploadDir = process.env.UPLOAD_DIR;
                
                if (baseUploadDir && !path.isAbsolute(baseUploadDir)) {
                    baseUploadDir = path.resolve(__dirname, '../../', baseUploadDir);
                }
                
                if (!baseUploadDir || baseUploadDir.includes('uploads') || baseUploadDir.includes('backend')) {
                    try {
                        fs.accessSync(nasPath, fs.constants.R_OK | fs.constants.W_OK);
                        baseUploadDir = nasPath;
                    } catch (err) {
                        baseUploadDir = localFallbackPath;
                    }
                }
                const relativePath = existingVehicle.uploadUrl.replace(/^\/(attachments|uploads)\/?/, '');
                const oldFilePath = path.join(baseUploadDir, relativePath);
                await safeDeleteFile(oldFilePath);
            }
        } else if (req.body.uploadUrl) {
            newUploadUrl = '/attachments/vehicles/images/' + path.basename(req.body.uploadUrl);
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

        if (actFile || req.body.actUploadUrl || req.body.actDocumentUrl || req.body.actFile || req.body.pororborUrl || docNum !== undefined || docIssue !== undefined || docExpiry !== undefined) {
            console.log(`[DEBUG] updateVehicle: Processing document for Vehicle ID: ${vehicleId}`);

            try {
                console.log('[DOCUMENT DEBUG] STEP 1 - document detected');
                console.log('[DOCUMENT DEBUG] req.file:', actFile);
                console.log('[DOCUMENT DEBUG] originalname =', actFile?.originalname);
                console.log('[DOCUMENT DEBUG] filename =', actFile?.filename);
                console.log('[DOCUMENT DEBUG] path =', actFile?.path);
                console.log('[DOCUMENT DEBUG] destination =', actFile?.destination);
                console.log('[DOCUMENT DEBUG] mimetype =', actFile?.mimetype);
                console.log('[DOCUMENT DEBUG] size =', actFile?.size);

                console.log('[DOCUMENT DEBUG] STEP 2 - before saving document');

                console.log('[DOCUMENT DEBUG] STEP 3 - before saveFileToNAS');
                console.log('[DOCUMENT DEBUG] saveFileToNAS input:', actFile ? (actFile.originalname || actFile.filename) : null);

                let actUploadUrl = actFile ? saveFileToNAS(actFile, 'documents') : (req.body.actUploadUrl || req.body.actDocumentUrl || req.body.actFile || req.body.pororborUrl || undefined);
                if (actUploadUrl) {
                    actUploadUrl = '/attachments/vehicles/documents/' + path.basename(actUploadUrl);
                }

                console.log('[DOCUMENT DEBUG] STEP 4 - after saveFileToNAS');
                console.log('[DOCUMENT DEBUG] saveFileToNAS result:', actUploadUrl);

                const nasPath = path.normalize('/Internal Booking System/Internal Booking System/attachments');
                const localFallbackPath = path.resolve(__dirname, '../../attachments');
                let baseUploadDir = process.env.UPLOAD_DIR;
                try {
                    fs.accessSync(nasPath, fs.constants.R_OK | fs.constants.W_OK);
                    baseUploadDir = nasPath;
                } catch (err) {
                    baseUploadDir = localFallbackPath;
                }

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

                console.log('[DOCUMENT DEBUG] STEP 5 - before VehicleDocument create/update');
                let savedDocument = null;

                if (existingDoc) {
                    if (actUploadUrl && existingDoc.uploadUrl) {
                        try {
                            fs.accessSync(nasPath, fs.constants.R_OK | fs.constants.W_OK);
                            baseUploadDir = nasPath;
                        } catch (err) {
                            baseUploadDir = localFallbackPath;
                        }

                        const relativePath = existingDoc.uploadUrl.replace(/^\/(attachments|uploads)\/?/, '');
                        const oldActPath = path.join(baseUploadDir, relativePath);
                        await safeDeleteFile(oldActPath);
                    }

                    let finalActUploadUrl = actUploadUrl !== undefined ? actUploadUrl : existingDoc.uploadUrl;
                    if (finalActUploadUrl) {
                        finalActUploadUrl = '/attachments/vehicles/documents/' + path.basename(finalActUploadUrl);
                    }

                    savedDocument = await prisma.vehicleDocument.update({
                        where: { id: existingDoc.id },
                        data: {
                            documentNumber: docNum !== undefined ? docNum : existingDoc.documentNumber,
                            issueDate: docIssue !== undefined ? docIssue : existingDoc.issueDate,
                            expiryDate: docExpiry !== undefined ? docExpiry : existingDoc.expiryDate,
                            uploadUrl: finalActUploadUrl
                        }
                    });
                } else {
                    savedDocument = await prisma.vehicleDocument.create({
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

                console.log('[DOCUMENT DEBUG] STEP 6 - after VehicleDocument create/update');
                console.log('[DOCUMENT DEBUG] VehicleDocument saved =', savedDocument);

                if (savedDocument?.uploadUrl) {
                    const relativePath = savedDocument.uploadUrl.replace(/^\/(attachments|uploads)\/?/, '');
                    const fullPhysicalPath = path.join(baseUploadDir, relativePath);
                    const fileExists = fs.existsSync(fullPhysicalPath);
                    console.log('[DOCUMENT DEBUG] physical file exists:', fileExists);
                    console.log('[DOCUMENT DEBUG] physical path:', fullPhysicalPath);
                }

                console.log('[DOCUMENT DEBUG] STEP 7 - updateVehicle completed');
            } catch (error) {
                console.error('[DOCUMENT ERROR] Failed to process vehicle document');
                console.error(error);
                console.error(error?.stack);
                throw error;
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
                documentType: {
                    name: { in: ['พ.ร.บ.', 'พรบ.', 'พรบ'] }
                }
            }
        });

        const actUrl = actDocument ? actDocument.uploadUrl : null;

        const vehicleResponse = {
            ...updatedVehicle,
            actDocumentNumber: actDocument ? actDocument.documentNumber : null,
            actIssueDate: actDocument ? actDocument.issueDate : null,
            actExpiryDate: actDocument ? actDocument.expiryDate : null,
            actUploadUrl: actUrl,
            actDocumentUrl: actUrl,
            actFilePath: actUrl,
            act_file_path: actUrl,
            actFile: actUrl,
            act_file: actUrl,
            actUrl: actUrl,
            pororborUrl: actUrl
        };

        return res.status(200).json({ success: true, data: vehicleResponse, message: "แก้ไขข้อมูลรถสำเร็จ" });
    } catch (error) {
        let uploadedFile = null;
        let actFile = null;
        if (req.file) {
            const singleFn = (req.file.fieldname || '').toLowerCase();
            const isAct = singleFn.includes('act') || ['actdocument', 'actfile', 'act_file', 'document', 'doc', 'pdf'].includes(singleFn) || req.file.mimetype === 'application/pdf' || (req.file.originalname || '').toLowerCase().endsWith('.pdf');
            if (isAct) actFile = req.file;
            else uploadedFile = req.file;
        }
        if (Array.isArray(req.files)) {
            actFile = actFile || req.files.find(f => (f.fieldname || '').toLowerCase().includes('act') || ['actdocument', 'actfile', 'act_file', 'document', 'doc', 'pdf'].includes((f.fieldname || '').toLowerCase()) || f.mimetype === 'application/pdf' || (f.originalname || '').toLowerCase().endsWith('.pdf'));
            uploadedFile = uploadedFile || req.files.find(f => f !== actFile && (['image', 'uploadurl', 'upload_url', 'vehicle_image'].includes((f.fieldname || '').toLowerCase()) || f.mimetype.startsWith('image/')));
        } else if (req.files && typeof req.files === 'object') {
            actFile = actFile || req.files.actDocument?.[0] || req.files.actFile?.[0] || req.files.act_file?.[0] || req.files.act?.[0] || req.files.document?.[0] || req.files.doc?.[0] || req.files.pdf?.[0];
            uploadedFile = uploadedFile || req.files.image?.[0] || req.files.uploadUrl?.[0] || req.files.vehicle_image?.[0] || req.files.file?.[0];
        }
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

        // 🟢 ทำการยกเลิกคิวจองในอนาคตอัตโนมัติ เพื่อไม่ให้ค้างในระบบ
        if (futureBookings.length > 0) {
            await prisma.vehicleBooking.updateMany({
                where: {
                    vehicleId: vehicleId,
                    endDatetime: { gt: new Date() },
                    status: { notIn: ['CANCELLED', 'REJECTED'] }
                },
                data: { status: 'CANCELLED' }
            });
        }

        // 🟢 ปิดการบล็อก 409 Conflict เพื่อให้ Admin สามารถ Soft Delete ได้ทันที
        /*
        if (futureBookings.length > 0) {
            return res.status(409).json({ 
                success: false, 
                error: "ไม่สามารถลบรถคันนี้ได้ เนื่องจากมีคิวจองใช้งานในอนาคต",
                futureBookingsCount: futureBookings.length
            });
        }
        */

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