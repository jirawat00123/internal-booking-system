const { PrismaClient, BookingStatus, VehicleStatus } = require('@prisma/client');
const prisma = new PrismaClient();
const notificationService = require('../services/notificationService');
const fs = require('fs');
const path = require('path');

// Helper สำหรับเปรียบเทียบ Diff ค่าเก่าและค่าใหม่ก่อนลง DB
const calculateDiff = (oldObj, newObj) => {
    const diff = { old: {}, new: {} };
    Object.keys(newObj).forEach((key) => {
        if (newObj[key] !== undefined && String(oldObj[key] ?? '') !== String(newObj[key] ?? '')) {
            diff.old[key] = oldObj[key] ?? null;
            diff.new[key] = newObj[key];
        }
    });
    return diff;
};

// Helper สำหรับบันทึก Audit Log ตรงตาม Schema AuditLog
const recordAuditLog = async (tx, { action, module, entityId, entityType, userId, details }) => {
    const client = tx || prisma;

    // แปลง userId และ entityId ให้ปลอดภัย (ถ้าไม่มี/แปลงไม่ได้จะใส่ null)
    const parsedUserId = userId ? parseInt(userId, 10) : null;
    const safeUserId = (!isNaN(parsedUserId) && parsedUserId > 0) ? parsedUserId : null;

    const parsedEntityId = entityId ? parseInt(entityId, 10) : null;
    const safeEntityId = (!isNaN(parsedEntityId) && parsedEntityId > 0) ? parsedEntityId : null;

    try {
        return await client.auditLog.create({
            data: {
                action: String(action),
                module: String(module || 'VEHICLE_BOOKING'),
                entityId: safeEntityId,
                entityType: entityType ? String(entityType) : 'VEHICLE_BOOKING',
                userId: safeUserId,
                details: typeof details === 'object' ? JSON.stringify(details) : (details ? String(details) : null)
            }
        });
    } catch (error) {
        console.error('[AuditLog Error] บันทึก Audit Log ไม่สำเร็จ:', error);
        return null;
    }
};

// Helper Function สำหรับค้นหาและดึงไฟล์อัปโหลดจาก req.files (รองรับทั้ง Array และ Object)
const getUploadedFile = (files, fieldNames) => {
    if (!files) return null;
    const targets = Array.isArray(fieldNames) ? fieldNames : [fieldNames];

    if (Array.isArray(files)) {
        return files.find(file => targets.includes(file.fieldname)) || null;
    }

    for (const name of targets) {
        if (files[name] && files[name][0]) {
            return files[name][0];
        }
    }

    return null;
};

// =======================================================
// 1. สร้างรายการจองรถยนต์ (POST)
// =======================================================
exports.createBooking = async (req, res) => {
    try {
        const { vehicleId, destination, startDatetime, endDatetime, passengerCount, passengers, passengerNames, outboundPassengers, inboundPassengers, driverType, companyDriverId, driverEmployeeId, driverUserId, driverLicenseUrl, userId, purpose } = req.body;
        
        console.log('[VEHICLE-END-DATETIME] 1. รับค่าจาก Client - startDatetime:', startDatetime, 'endDatetime:', endDatetime);
        
        const finalEndDate = endDatetime;

        const requestFiles = req.files || (req.file ? [req.file] : null);
        const licenseFile = getUploadedFile(requestFiles, ['driverLicenseUrl', 'driverLicense', 'licenseImage', 'license', 'file', 'image', 'attachments']) || (Array.isArray(requestFiles) && requestFiles.length > 0 ? requestFiles[0] : null);

        const normalizeLicensePath = (filePath) => {
            if (!filePath) return null;
            const clean = String(filePath).replace(/\\/g, '/');
            const idx = clean.indexOf('attachments/');
            return idx !== -1 ? '/' + clean.substring(idx) : (clean.startsWith('/') ? clean : '/' + clean);
        };

        const rawLicenseBody = req.body.driverLicenseUrl || req.body.driverLicense || driverLicenseUrl || null;
        const finalDriverLicenseUrl = licenseFile ? normalizeLicensePath(licenseFile.path) : (rawLicenseBody && !rawLicenseBody.startsWith('data:image') ? normalizeLicensePath(rawLicenseBody) : null);

        if (!vehicleId || !startDatetime || !finalEndDate || String(finalEndDate).trim() === '') {
            return res.status(400).json({ success: false, error: "กรุณาระบุข้อมูลยานพาหนะ เวลาเริ่มต้น และเวลาสิ้นสุด (ห้ามเว้นว่าง) ให้ครบถ้วนและชัดเจน" });
        }

        if (isNaN(new Date(startDatetime).getTime()) || isNaN(new Date(finalEndDate).getTime())) {
            return res.status(400).json({ success: false, error: "รูปแบบวันและเวลาไม่ถูกต้อง" });
        }

        const finalPassengers = parseInt(passengerCount || passengers) || 1;
        const finalUserId = parseInt(req.user?.userId || req.user?.id || userId || req.body?.userId, 10);

        console.log('[CREATE VEHICLE BOOKING] req.body:', JSON.stringify(req.body, null, 2));
        console.log('[PASSENGER INPUT] passengers:', passengers);
        console.log('[PASSENGER INPUT] passengerNames:', passengerNames);

        let parsedPassengerNames = [];
        const targetKeys = ['passengerNames', 'passengers', 'passengerDetails', 'vehicleBookingPassengers'];
        
        targetKeys.forEach(key => {
            const val = req.body[key];
            if (val) {
                if (typeof val === 'string') {
                    try {
                        const parsed = JSON.parse(val);
                        if (Array.isArray(parsed)) {
                            parsedPassengerNames.push(...parsed);
                        } else if (isNaN(val)) {
                            parsedPassengerNames.push(val);
                        }
                    } catch (e) {
                        if (val.includes(',')) {
                            parsedPassengerNames.push(...val.split(','));
                        } else if (isNaN(val)) {
                            parsedPassengerNames.push(val);
                        }
                    }
                } else if (Array.isArray(val)) {
                    parsedPassengerNames.push(...val);
                }
            }
        });

        const keys = Object.keys(req.body).filter(k => 
            k.startsWith('passengerNames[') || k === 'passengerNames[]' ||
            k.startsWith('passengers[') || k === 'passengers[]' ||
            k.startsWith('passengerDetails[') || k === 'passengerDetails[]' ||
            k.startsWith('vehicleBookingPassengers[') || k === 'vehicleBookingPassengers[]'
        );
        if (keys.length > 0) {
            keys.forEach(k => {
                const val = req.body[k];
                if (Array.isArray(val)) parsedPassengerNames.push(...val);
                else parsedPassengerNames.push(val);
            });
        }

        if (typeof parsedPassengerNames === 'string') {
            parsedPassengerNames = [parsedPassengerNames];
        }

        if (!Array.isArray(parsedPassengerNames)) {
            return res.status(400).json({ success: false, error: "ข้อมูลรายชื่อผู้โดยสารต้องอยู่ในรูปแบบ Array" });
        }

        const cleanPassengerNames = parsedPassengerNames.map(name => {
            if (typeof name === 'object' && name !== null) {
                return String(name.fullName || name.name || '').trim();
            }
            return String(name).trim();
        }).filter(Boolean);

        const parsePassengerArray = (input) => {
            if (!input) return [];
            let result = [];
            if (typeof input === 'string') {
                try {
                    const parsed = JSON.parse(input);
                    if (Array.isArray(parsed)) result.push(...parsed);
                    else if (isNaN(input)) result.push(input);
                } catch (e) {
                    if (input.includes(',')) result.push(...input.split(','));
                    else if (isNaN(input)) result.push(input);
                }
            } else if (Array.isArray(input)) {
                result.push(...input);
            }
            return result.map(p => typeof p === 'object' && p !== null ? String(p.fullName || p.name || '').trim() : String(p).trim()).filter(Boolean);
        };

        const cleanOutboundNames = parsePassengerArray(outboundPassengers || req.body['outboundPassengers[]']);
        const cleanInboundNames = parsePassengerArray(inboundPassengers || req.body['inboundPassengers[]']);

        console.log('[PASSENGER INPUT] cleanPassengerNames:', cleanPassengerNames);
        console.log('[PASSENGER INPUT] cleanOutboundNames:', cleanOutboundNames);
        console.log('[PASSENGER INPUT] cleanInboundNames:', cleanInboundNames);

        let validatedPassengersCount = finalPassengers;
        const totalUniquePassengerCount = Math.max(cleanPassengerNames.length, cleanOutboundNames.length, cleanInboundNames.length);
        if (totalUniquePassengerCount > finalPassengers) {
            validatedPassengersCount = totalUniquePassengerCount;
        }

        let passengerDetailsToCreate = [];
        if (cleanOutboundNames.length > 0 || cleanInboundNames.length > 0) {
            cleanOutboundNames.forEach(name => passengerDetailsToCreate.push({ fullName: name, tripType: 'OUTBOUND' }));
            cleanInboundNames.forEach(name => passengerDetailsToCreate.push({ fullName: name, tripType: 'INBOUND' }));
        } else if (cleanPassengerNames.length > 0) {
            cleanPassengerNames.forEach(name => passengerDetailsToCreate.push({ fullName: name, tripType: 'BOTH' }));
        }

        const isCompanyDriver = driverType === 'COMPANY' || driverType === 'COMPANY_DRIVER' || driverType === 'บริษัท' || driverType === 'พนักงานขับรถ';
        const normalizedDriverType = isCompanyDriver ? 'COMPANY' : 'SELF_DRIVE';

        const targetDriverEmployeeId = isCompanyDriver ? null : (driverEmployeeId || req.body.driverEmployeeId);
        const targetDriverUserId = isCompanyDriver ? null : (driverUserId || req.body.driverUserId);

        const parsedDriverEmployeeId = targetDriverEmployeeId ? parseInt(targetDriverEmployeeId, 10) : null;
        const parsedDriverUserId = targetDriverUserId ? parseInt(targetDriverUserId, 10) : null;

        let existingDriverLicenseUrl = null;

        if (normalizedDriverType === 'SELF_DRIVE') {
            if (!parsedDriverEmployeeId && !parsedDriverUserId) {
                return res.status(400).json({ success: false, error: "กรุณาระบุผู้ขับขี่ (driverEmployeeId หรือ driverUserId) สำหรับการขับรถเอง" });
            }

            let driverName = '';
            let driverEmp = null;

            if (parsedDriverEmployeeId) {
                driverEmp = await prisma.employee.findUnique({
                    where: { id: parsedDriverEmployeeId }
                });
                driverName = driverEmp?.fullName || '';
            }

            if (!driverName && parsedDriverUserId) {
                const driverUser = await prisma.user.findUnique({
                    where: { id: parsedDriverUserId },
                    include: { employee: true }
                });
                driverEmp = driverUser?.employee || null;
                driverName = driverEmp?.fullName || driverUser?.username || '';
            }

            const isDriverInPassengers = cleanPassengerNames.includes(driverName) || 
                                         cleanOutboundNames.includes(driverName) || 
                                         cleanInboundNames.includes(driverName);

            if (!isDriverInPassengers) {
                return res.status(400).json({ success: false, error: "ปฏิเสธการจอง: ผู้ขับขี่ต้องมีรายชื่ออยู่ในกลุ่มผู้โดยสารเท่านั้น" });
            }

            if (driverEmp) {
                existingDriverLicenseUrl = driverEmp.driverLicenseUrl || null;
                const hasLicense = !!driverEmp.driverLicenseUrl;
                const expiryDate = driverEmp.driverLicenseExpiryDate;
                const isExpired = expiryDate ? new Date(expiryDate) < new Date() : false;
                const hasNewUpload = !!licenseFile || !!rawLicenseBody;

                if (hasLicense && isExpired && !hasNewUpload) {
                    return res.status(400).json({ success: false, error: "ใบขับขี่ของผู้ขับขี่หมดอายุแล้ว ไม่สามารถทำรายการจองได้" });
                }
                if (!hasLicense && !hasNewUpload) {
                    return res.status(400).json({ success: false, error: "ผู้ขับขี่ยังไม่มีข้อมูลใบขับขี่ในระบบ กรุณาอัปโหลดใบขับขี่เพื่อดำเนินการต่อ" });
                }
            }
        }

        const reqStart = new Date(startDatetime);
        const reqEnd = new Date(finalEndDate);
        
        console.log('[VEHICLE-END-DATETIME] 2. แปลงค่าเป็น Date Object (เวลาจริง) - reqEnd:', reqEnd);
        
        const nowBuffer = new Date(Date.now() - 5 * 60 * 1000);

        if (reqStart < nowBuffer) {
            return res.status(400).json({ success: false, error: "ไม่สามารถทำรายการจองรถยนต์ย้อนหลังได้ กรุณาเลือกเวลาที่เป็นปัจจุบันหรืออนาคต" });
        }

        if (reqStart >= reqEnd) {
            return res.status(400).json({ success: false, error: "เวลาสิ้นสุดการจองต้องอยู่หลังเวลาเริ่มต้นการจองเสมอ" });
        }

        console.log('[VEHICLE-END-DATETIME] 3. ก่อนส่งเข้า Prisma - reqStart:', reqStart, 'reqEnd:', reqEnd);

        const newBooking = await prisma.$transaction(async (tx) => {
            const conflictingBooking = await tx.vehicleBooking.findFirst({
                where: {
                    vehicleId: parseInt(vehicleId),
                    status: {
                        in: [BookingStatus.PENDING, BookingStatus.APPROVED, BookingStatus.IN_USE] 
                    },
                    startDatetime: { lt: reqEnd },
                    endDatetime: { gt: reqStart }
                }
            });

            if (conflictingBooking) {
                throw new Error('TIME_OVERLAP');
            }

            if (parsedDriverEmployeeId && normalizedDriverType === 'SELF_DRIVE') {
                const conflictingSelfDriver = await tx.vehicleBooking.findFirst({
                    where: {
                        driverEmployeeId: parsedDriverEmployeeId,
                        status: { 
                            in: [BookingStatus.PENDING, BookingStatus.APPROVED, BookingStatus.IN_USE] 
                        },
                        startDatetime: { lt: reqEnd },
                        endDatetime: { gt: reqStart }
                    }
                });
                if (conflictingSelfDriver) throw new Error('DRIVER_OVERLAP');
            }

            let booking = await tx.vehicleBooking.create({
                data: {
                    vehicleId: parseInt(vehicleId),
                    userId: finalUserId, 
                    destination: destination || "-",
                    startDatetime: reqStart,
                    endDatetime: reqEnd,
                    passengers: validatedPassengersCount, 
                    purpose: purpose || "ใช้งานบริษัท",
                    driverType: normalizedDriverType,
                    driverEmployeeId: targetDriverEmployeeId,
                    driverUserId: normalizedDriverType === 'SELF_DRIVE' ? parsedDriverUserId : null,
                    driverLicenseUrl: isCompanyDriver ? null : (finalDriverLicenseUrl || existingDriverLicenseUrl),
                    status: BookingStatus.PENDING,
                    passengerDetails: passengerDetailsToCreate.length > 0 ? {
                        create: passengerDetailsToCreate
                    } : undefined
                },
                include: {
                    vehicle: {
                        include: {
                            documents: {
                                include: {
                                    documentType: true
                                }
                            }
                        }
                    },
                    user: {
                        include: { employee: true }
                    },
                    driverEmployee: true,
                    attachments: true,
                    passengerDetails: true
                }
            });

            const targetRawLicense = req.body.driverLicenseUrl || req.body.driverLicense || driverLicenseUrl;
            let licenseBuffer = null;
            let tempSourcePath = null;
            let fileExt = '.png';

            if (!isCompanyDriver) {
                if (licenseFile) {
                    fileExt = path.extname(licenseFile.originalname || licenseFile.filename || '.png') || '.png';
                    if (licenseFile.buffer) {
                        licenseBuffer = licenseFile.buffer;
                    } else if (licenseFile.path) {
                        tempSourcePath = licenseFile.path;
                    }
                } else if (targetRawLicense && typeof targetRawLicense === 'string') {
                    if (targetRawLicense.startsWith('data:image')) {
                        const matches = targetRawLicense.match(/^data:image\/([a-zA-Z0-9]+);base64,(.+)$/);
                        if (matches) {
                            fileExt = `.${matches[1]}`;
                            licenseBuffer = Buffer.from(matches[2], 'base64');
                        }
                    } else if (targetRawLicense.includes('attachments/')) {
                        fileExt = path.extname(targetRawLicense) || '.png';
                        const baseUploadDir = process.env.UPLOAD_DIR || path.join(__dirname, '../../attachments');
                        const cleanPath = targetRawLicense.replace(/\\/g, '/');
                        const relPath = cleanPath.substring(cleanPath.indexOf('attachments/') + 'attachments/'.length);
                        const possiblePath1 = path.join(baseUploadDir, relPath);
                        const possiblePath2 = path.join(__dirname, '../../', cleanPath.startsWith('/') ? cleanPath.substring(1) : cleanPath);

                        if (fs.existsSync(possiblePath1)) {
                            tempSourcePath = possiblePath1;
                        } else if (fs.existsSync(possiblePath2)) {
                            tempSourcePath = possiblePath2;
                        }
                    }
                }
            }

            if (licenseBuffer || tempSourcePath) {
                const baseUploadDir = process.env.UPLOAD_DIR || path.join(__dirname, '../../attachments');
                const licenseDir = path.join(baseUploadDir, 'vehicles', 'license_driver');
                if (!fs.existsSync(licenseDir)) {
                    fs.mkdirSync(licenseDir, { recursive: true, mode: 0o777 });
                }

                const rawUserName = req.user?.username || req.user?.name || booking.user?.employee?.fullName || `user_${finalUserId}`;
                const cleanUserName = String(rawUserName).replace(/[^a-zA-Z0-9_\u0E00-\u0E7F]/g, '_');
                const timestamp = Math.floor(Date.now() / 1000);
                const newFileName = `booking_${booking.id}_${cleanUserName}_${timestamp}${fileExt}`;
                const destPath = path.join(licenseDir, newFileName);

                if (licenseBuffer) {
                    fs.writeFileSync(destPath, licenseBuffer);
                    try { fs.chmodSync(destPath, 0o777); } catch (e) {}
                } else if (tempSourcePath && fs.existsSync(tempSourcePath)) {
                    fs.copyFileSync(tempSourcePath, destPath);
                    try { fs.chmodSync(destPath, 0o777); } catch (e) {}
                }

                const savedLicenseUrl = `/attachments/vehicles/license_driver/${newFileName}`;

                booking = await tx.vehicleBooking.update({
                    where: { id: booking.id },
                    data: { driverLicenseUrl: savedLicenseUrl },
                    include: {
                        vehicle: {
                            include: {
                                documents: {
                                    include: {
                                        documentType: true
                                    }
                                }
                            }
                        },
                        user: {
                            include: { employee: true }
                        },
                        driverEmployee: true,
                        attachments: true,
                        passengerDetails: true
                    }
                });

                if (normalizedDriverType === 'SELF_DRIVE' && parsedDriverEmployeeId) {
                    await tx.employee.update({
                        where: { id: parsedDriverEmployeeId },
                        data: { driverLicenseUrl: savedLicenseUrl }
                    });
                }
            }

            const actionUserId = parseInt(req.user?.userId || req.user?.id, 10) || finalUserId;
            if (actionUserId) {
                await tx.auditLog.create({
                    data: {
                        action: "CREATE_VEHICLE_BOOKING",
                        module: "VEHICLE_BOOKING",
                        entityId: booking.id,
                        entityType: "VEHICLE_BOOKING",
                        userId: actionUserId,
                        details: JSON.stringify({
                            newStatus: BookingStatus.PENDING,
                            destination: booking.destination,
                            remark: 'สร้างการจองรถยนต์ใหม่ รอการอนุมัติ'
                        })
                    }
                });
            }
            return booking;
        });

        console.log('[VEHICLE-END-DATETIME] 4. หลังบันทึกลง Database - endDatetime:', newBooking.endDatetime);

        await notificationService.notifyAdmins({
            title: "มีคำขอจองรถยนต์ใหม่",
            message: `รอการอนุมัติ: รถยนต์ทะเบียน ${newBooking.vehicle.plateNumber} (ปลายทาง: ${destination || '-'})`,
            type: 'APPROVAL',
            entityType: 'VEHICLE_BOOKING',
            entityId: newBooking.id
        });

        const actDoc = newBooking.vehicle?.documents?.find(doc => {
            const docTypeName = doc.documentType?.name || doc.name || doc.title || '';
            const docTypeKey = doc.documentType?.key || doc.type || '';
            return docTypeName.includes('พ.ร.บ') || docTypeName.includes('พรบ') || docTypeName.toUpperCase().includes('ACT') || docTypeKey.toUpperCase().includes('ACT');
        });
        const rawActUrl = newBooking.vehicle?.actFilePath || newBooking.vehicle?.act_file_path || newBooking.vehicle?.actFile || (actDoc ? (actDoc.uploadUrl || actDoc.filePath || actDoc.url || null) : null);
        const normalizePath = (filePath) => {
            if (!filePath) return null;
            const clean = String(filePath).replace(/\\/g, '/');
            const idx = clean.indexOf('attachments/');
            return idx !== -1 ? '/' + clean.substring(idx) : (clean.startsWith('/') ? clean : '/' + clean);
        };
        const actUrl = normalizePath(rawActUrl);

        const outboundList = newBooking.passengerDetails?.filter(p => p.tripType === 'OUTBOUND').map(p => p.fullName) || cleanOutboundNames;
        const inboundList = newBooking.passengerDetails?.filter(p => p.tripType === 'INBOUND').map(p => p.fullName) || cleanInboundNames;

        const formattedNewBooking = {
            ...newBooking,
            userName: newBooking.user?.employee?.fullName || newBooking.user?.username || '-',
            passengerNames: newBooking.passengerDetails?.map(p => p.fullName) || cleanPassengerNames,
            outboundPassengers: outboundList,
            inboundPassengers: inboundList,
            outboundPassengerNames: outboundList,
            inboundPassengerNames: inboundList,
            companyDriver: newBooking.driverEmployee || null,
            companyDriverName: newBooking.driverEmployee?.fullName || newBooking.driverEmployee?.name || '-',
            actDocumentUrl: actUrl,
            actFilePath: actUrl,
            act_file_path: actUrl,
            actFile: actUrl,
            act_file: actUrl,
            actUrl: actUrl,
            actUploadUrl: actUrl,
            pororborUrl: actUrl,
            vehicle: newBooking.vehicle ? {
                ...newBooking.vehicle,
                actDocumentUrl: actUrl,
                actFilePath: actUrl,
                act_file_path: actUrl,
                actFile: actUrl,
                act_file: actUrl,
                actUrl: actUrl,
                actUploadUrl: actUrl,
                pororborUrl: actUrl
            } : newBooking.vehicle
        };

        return res.status(201).json({ success: true, data: formattedNewBooking, message: "บันทึกคำขอจองรถสำเร็จ รอการอนุมัติ" });

    } catch (error) {
        console.error("Create Vehicle Booking Error:", error);
        if (error.message === 'TIME_OVERLAP') {
            return res.status(400).json({ success: false, error: "รถคันนี้ถูกจับจองไปแล้วในช่วงเวลาดังกล่าว กรุณาเปลี่ยนช่วงเวลาหรือเลือกเปลี่ยนรถคันใหม่" });
        }
        if (error.message === 'DRIVER_OVERLAP') {
            return res.status(400).json({ success: false, error: "พนักงานขับรถหรือผู้ขับขี่มีคิวงานซ้อนในช่วงเวลาดังกล่าว กรุณาเปลี่ยนคนขับ" });
        }
        return res.status(500).json({ success: false, error: "ไม่สามารถดำเนินการสร้างรายการจองรถยนต์ได้" });
    }
};

// =======================================================
// 2. ดึงประวัติการจองทั้งหมด พร้อมแนบ Permissions สำหรับ Dumb UI (GET)
// =======================================================
exports.getBookings = async (req, res) => {
    try {
        const { startDate, endDate, vehicleId, status } = req.query;

        let whereClause = {};

        if (startDate && endDate) {
            whereClause.startDatetime = { lte: new Date(endDate) };
            whereClause.endDatetime = { gte: new Date(startDate) };

            if (status && status.toUpperCase() !== 'ALL') {
                whereClause.status = status;
            } else if (!status) {
                whereClause.status = {
                    notIn: [BookingStatus.COMPLETED, BookingStatus.CANCELLED, BookingStatus.EXPIRED, BookingStatus.REJECTED]
                };
            }
        } else if (status && status.toUpperCase() !== 'ALL') {
            whereClause.status = status;
        }

        if (vehicleId) {
            whereClause.vehicleId = parseInt(vehicleId, 10);
        }

        const bookings = await prisma.vehicleBooking.findMany({
            where: whereClause,
            orderBy: { createdAt: 'desc' },
            include: {
                vehicle: {
                    include: {
                        documents: {
                            include: {
                                documentType: true
                            }
                        }
                    }
                },
                user: { include: { employee: true } },
                driverEmployee: true,
                attachments: true,
                passengerDetails: true,
                vehicleLogs: {
                    include: {
                        checkoutBy: { include: { employee: true } },
                        returnBy: { include: { employee: true } }
                    }
                }
            }
        });

        const currentUserId = req.user ? parseInt(req.user?.userId || req.user?.id, 10) : null;
        const currentUserRole = req.user ? req.user.role : 'USER';
        
        const bookingsWithPermissions = bookings.map(booking => {
            const isOwner = currentUserId === booking.userId;
            const isAdmin = currentUserRole === 'ADMIN';
            const isPendingOrApproved = [BookingStatus.PENDING, BookingStatus.APPROVED].includes(booking.status);

            const actDoc = booking.vehicle?.documents?.find(doc => {
                const docTypeName = doc.documentType?.name || doc.name || doc.title || '';
                const docTypeKey = doc.documentType?.key || doc.type || '';
                return docTypeName.includes('พ.ร.บ') || docTypeName.includes('พรบ') || docTypeName.toUpperCase().includes('ACT') || docTypeKey.toUpperCase().includes('ACT');
            });

            const rawActUrl = booking.vehicle?.actFilePath || booking.vehicle?.act_file_path || booking.vehicle?.actFile || (actDoc ? (actDoc.uploadUrl || actDoc.filePath || actDoc.url || null) : null);

            const normalizePath = (filePath) => {
                if (!filePath) return null;
                const clean = String(filePath).replace(/\\/g, '/');
                const idx = clean.indexOf('attachments/');
                return idx !== -1 ? '/' + clean.substring(idx) : (clean.startsWith('/') ? clean : '/' + clean);
            };

            const actUrl = normalizePath(rawActUrl);

            const vehicleWithAct = booking.vehicle ? {
                ...booking.vehicle,
                actDocumentUrl: actUrl,
                actFilePath: actUrl,
                act_file_path: actUrl,
                actFile: actUrl,
                act_file: actUrl,
                actUrl: actUrl,
                actUploadUrl: actUrl,
                pororborUrl: actUrl
            } : booking.vehicle;

            const extractedPassengerNames = (booking.passengerDetails || [])
                .map(p => typeof p === 'object' && p !== null ? (p.fullName || p.passengerName || p.name || '') : String(p))
                .filter(name => name.trim().length > 0);

            const outboundList = (booking.passengerDetails || [])
                .filter(p => p.tripType === 'OUTBOUND')
                .map(p => typeof p === 'object' && p !== null ? (p.fullName || p.passengerName || p.name || '') : String(p))
                .filter(name => name.trim().length > 0);

            const inboundList = (booking.passengerDetails || [])
                .filter(p => p.tripType === 'INBOUND')
                .map(p => typeof p === 'object' && p !== null ? (p.fullName || p.passengerName || p.name || '') : String(p))
                .filter(name => name.trim().length > 0);

            const normalizedAttachments = (booking.attachments || []).map(att => ({
                ...att,
                filePath: normalizePath(att.filePath) || att.filePath,
                url: normalizePath(att.filePath) || att.filePath
            }));

            const latestLog = Array.isArray(booking.vehicleLogs)
                ? (booking.vehicleLogs.length > 0 ? booking.vehicleLogs[booking.vehicleLogs.length - 1] : null)
                : (booking.vehicleLogs || null);

            const logReleaseImages = latestLog ? [latestLog.checkoutFrontPhoto, latestLog.checkoutBackPhoto, latestLog.checkoutMileagePhoto].filter(Boolean).map(a => normalizePath(a)) : [];
            const logReturnImages = latestLog ? [latestLog.returnFrontPhoto, latestLog.returnBackPhoto, latestLog.returnMileagePhoto].filter(Boolean).map(a => normalizePath(a)) : [];

            const releaseImages = [
                ...normalizedAttachments
                    .filter(a => a.entityType === 'VEHICLE_RELEASE_IMAGE')
                    .map(a => a.filePath),
                ...logReleaseImages
            ];

            const returnImages = [
                ...normalizedAttachments
                    .filter(a => a.entityType === 'VEHICLE_RETURN_IMAGE')
                    .map(a => a.filePath),
                ...logReturnImages
            ];

            return {
                ...booking,
                userName: booking.user?.employee?.fullName || booking.user?.username || '-',
                passengerNames: extractedPassengerNames.length > 0 ? extractedPassengerNames : (booking.passengerNames || []),
                outboundPassengers: outboundList,
                inboundPassengers: inboundList,
                outboundPassengerNames: outboundList,
                inboundPassengerNames: inboundList,
                companyDriver: booking.driverEmployee || null,
                companyDriverName: booking.driverEmployee?.fullName || booking.driverEmployee?.name || '-',
                vehicle: vehicleWithAct,
                actDocumentUrl: actUrl,
                actFilePath: actUrl,
                act_file_path: actUrl,
                actFile: actUrl,
                act_file: actUrl,
                actUrl: actUrl,
                actUploadUrl: actUrl,
                pororborUrl: actUrl,
                attachments: normalizedAttachments,
                checkoutTime: latestLog?.checkoutTime || null,
                returnTime: latestLog?.returnTime || null,
                actualCheckoutTime: latestLog?.checkoutTime || null,
                actualReturnTime: latestLog?.returnTime || null,
                releaseImages: releaseImages,
                returnImages: returnImages,
                releasePhotos: releaseImages,
                returnPhotos: returnImages,
                vehicleLogs: booking.vehicleLogs || [],
                vehicleLog: latestLog,
                checkoutMileage: latestLog?.checkoutMileage || null,
                returnMileage: latestLog?.returnMileage || null,
                checkoutFuelLevel: latestLog?.checkoutFuelLevel || null,
                returnFuelLevel: latestLog?.returnFuelLevel || null,
                checkoutByName: latestLog?.checkoutBy?.employee?.fullName || latestLog?.checkoutBy?.username || '-',
                returnByName: latestLog?.returnBy?.employee?.fullName || latestLog?.returnBy?.username || '-',
                permissions: {
                    canCancel: (isOwner || isAdmin) && isPendingOrApproved,
                    canEdit: (isOwner || isAdmin) && booking.status === BookingStatus.PENDING,
                    canApprove: isAdmin && booking.status === BookingStatus.PENDING
                }
            };
        });

        res.status(200).json({ success: true, data: bookingsWithPermissions });
    } catch (error) {
        console.error("Get Vehicle Bookings Error:", error);
        res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลประวัติการจองได้" });
    }
};

// =======================================================
// 3. อัปเดตสถานะการจอง (PUT) 
// =======================================================
exports.updateBookingStatus = async (req, res) => {
    try {
        const bookingId = parseInt(req.params.id);
        const { status, remark } = req.body;

        if (isNaN(bookingId) || !status) {
            return res.status(400).json({ success: false, error: "ข้อมูลไม่ถูกต้อง" });
        }

        const existingBooking = await prisma.vehicleBooking.findUnique({
            where: { id: bookingId }
        });

        if (!existingBooking) {
            return res.status(404).json({ success: false, error: "ไม่พบข้อมูลการจองนี้" });
        }

        // ดึง userId อย่างปลอดภัย
        const currentUserId = req.user?.id || req.user?.userId || req.user?.sub || req.user?.user_id;

        if (req.user.role === 'ADMIN') {
            // อนุญาตให้ Admin จัดการสถานะ
        } else if (
            req.user.role === 'USER' &&
            existingBooking.userId === currentUserId &&
            ['CANCELLED'].includes(status?.toUpperCase())
        ) {
            // USER สามารถยกเลิกเฉพาะ Booking ของตัวเอง
        } else {
            return res.status(403).json({ success: false, error: 'คุณไม่มีสิทธิ์แก้ไขสถานะการจองนี้' });
        }

        const validStatus = BookingStatus[status?.toUpperCase()];
        if (!validStatus) {
            return res.status(400).json({ success: false, message: 'สถานะไม่ถูกต้องตามระบบ' });
        }

        if (validStatus === BookingStatus.IN_USE && existingBooking.driverType === 'COMPANY' && !existingBooking.driverEmployeeId) {
            return res.status(400).json({ success: false, error: "กรุณาจัดสรรพนักงานขับรถก่อน" });
        }

        const updatedBooking = await prisma.$transaction(async (tx) => {
            if (validStatus === BookingStatus.APPROVED) {
                const conflictingBooking = await tx.vehicleBooking.findFirst({
                    where: {
                        id: { not: bookingId },
                        vehicleId: existingBooking.vehicleId,
                        status: {
                            in: [BookingStatus.PENDING, BookingStatus.APPROVED, BookingStatus.IN_USE]
                        },
                        startDatetime: { lt: existingBooking.endDatetime },
                        endDatetime: { gt: existingBooking.startDatetime }
                    }
                });

                if (conflictingBooking) {
                    throw new Error('TIME_OVERLAP');
                }

                if (existingBooking.driverEmployeeId) {
                    const conflictingDriver = await tx.vehicleBooking.findFirst({
                        where: {
                            id: { not: bookingId },
                            driverEmployeeId: existingBooking.driverEmployeeId,
                            status: { 
                                in: [BookingStatus.PENDING, BookingStatus.APPROVED, BookingStatus.IN_USE] 
                            },
                            startDatetime: { lt: existingBooking.endDatetime },
                            endDatetime: { gt: existingBooking.startDatetime }
                        }
                    });
                    if (conflictingDriver) throw new Error('DRIVER_OVERLAP');
                }
            }

            const booking = await tx.vehicleBooking.update({
                where: { id: bookingId },
                data: { status: validStatus },
                include: {
                    user: { include: { employee: true } },
                    vehicle: true
                }
            });

            if (validStatus === BookingStatus.CANCELLED || validStatus === BookingStatus.COMPLETED || validStatus === BookingStatus.REJECTED) {
                await tx.vehicle.update({
                    where: { id: existingBooking.vehicleId },
                    data: { status: VehicleStatus.AVAILABLE }
                });
            } else if (validStatus === BookingStatus.IN_USE) {
                await tx.vehicle.update({
                    where: { id: existingBooking.vehicleId },
                    data: { status: VehicleStatus.IN_USE }
                });
            }

            const auditAction = validStatus === BookingStatus.APPROVED ? "APPROVE_VEHICLE_BOOKING" : 
                               (validStatus === BookingStatus.COMPLETED ? "COMPLETED_VEHICLE_BOOKING" : "UPDATE_VEHICLE_BOOKING");

            const diff = calculateDiff(
                { status: existingBooking.status },
                { status: validStatus }
            );

            await recordAuditLog(tx, {
                action: auditAction,
                module: 'VEHICLE_BOOKING',
                userId: currentUserId,
                entityId: bookingId,
                entityType: 'VEHICLE_BOOKING',
                details: {
                    diff,
                    remark: remark || `อัปเดตสถานะการจองรถยนต์เป็น ${validStatus}`
                }
            });

            if ([BookingStatus.CANCELLED, BookingStatus.COMPLETED, BookingStatus.REJECTED].includes(validStatus)) {
                await tx.notification.updateMany({
                    where: { entityType: 'VEHICLE_BOOKING', entityId: bookingId, isRead: false },
                    data: { isRead: true }
                });
            }

            return booking;
        });

        res.status(200).json({ success: true, data: updatedBooking, message: "อัปเดตสถานะสำเร็จ" });
    } catch (error) {
        console.error("Update Booking Status Error:", error);

        if (error.message === 'TIME_OVERLAP') {
            return res.status(409).json({
                success: false,
                error: "ไม่สามารถอนุมัติการจองได้ เนื่องจากช่วงเวลาซ้อนกับรายการจองอื่น"
            });
        }
        if (error.message === 'DRIVER_OVERLAP') {
            return res.status(409).json({
                success: false,
                error: "ไม่สามารถอนุมัติการจองได้ เนื่องจากพนักงานขับรถหรือผู้ขับขี่มีคิวงานซ้อน"
            });
        }

        res.status(500).json({ success: false, error: "ไม่สามารถอัปเดตสถานะได้" });
    }
};

// =======================================================
// 4. บันทึกการปล่อยรถออก (PUT /:id/release) - ย้ายทุกอย่างเข้า Transaction 🟢
// =======================================================
exports.releaseVehicle = async (req, res) => {
    try {
        const bookingId = parseInt(req.params.id, 10);
        // TASK 8: Parse currentUserId และ Validate Number.isInteger
        const currentUserId = parseInt(req.user?.id || req.user?.userId, 10);

        if (isNaN(bookingId)) {
            return res.status(400).json({ success: false, error: "รหัสการจองไม่ถูกต้อง" });
        }
        if (!Number.isInteger(currentUserId)) {
            return res.status(401).json({ success: false, error: "ไม่พบข้อมูลผู้ดำเนินการ (Unauthorized)" });
        }

        const { status, remark, mileage, checkoutMileage, fuelLevel, checkoutFuelLevel } = req.body;
        const validStatus = status ? BookingStatus[status.toUpperCase()] : BookingStatus.IN_USE;

        const bookingExists = await prisma.vehicleBooking.findUnique({
            where: { id: bookingId },
            include: { vehicle: true }
        });

        if (!bookingExists) {
            return res.status(404).json({ success: false, error: `ไม่พบรายการจองรหัส #${bookingId} ในระบบ` });
        }

        // TASK 1: Status Check & Driver Rules
        if (bookingExists.status === BookingStatus.IN_USE) {
            return res.status(409).json({ success: false, code: "ALREADY_IN_USE", error: "รายการจองนี้ได้ทำการปล่อยรถไปแล้ว" });
        }

        if ([BookingStatus.CANCELLED, BookingStatus.COMPLETED, BookingStatus.REJECTED].includes(bookingExists.status)) {
            return res.status(409).json({ success: false, code: "INVALID_STATUS", error: "รายการจองนี้อยู่ในสถานะที่ไม่สามารถปล่อยรถได้" });
        }

        const hasCompanyDriver = bookingExists.driverEmployeeId; 
        if (['COMPANY', 'COMPANY_DRIVER'].includes(bookingExists.driverType) && !hasCompanyDriver) {
            return res.status(422).json({ success: false, error: "กรุณาจัดสรรพนักงานขับรถก่อนดำเนินการปล่อยรถ (Unprocessable Entity)" });
        }
        if (bookingExists.driverType === 'SELF_DRIVE' && !(bookingExists.driverEmployeeId || bookingExists.driverUserId || bookingExists.userId)) {
            return res.status(422).json({ success: false, error: "กรุณาระบุผู้ขับขี่ (Driver) ก่อนดำเนินการปล่อยรถ (Unprocessable Entity)" });
        }

        const now = new Date();
        const userRole = req.user?.role;
        const isAuthorizedStaff = ['ADMIN', 'GUARD', 'SECURITY'].includes(userRole);

        if (now < bookingExists.startDatetime && !isAuthorizedStaff) {
            const consentLog = await prisma.auditLog.findFirst({
                where: {
                    module: 'VEHICLE_BOOKING',
                    entityId: bookingId,
                    action: 'EARLY_RELEASE_CONSENT_GRANTED'
                }
            });

            if (!consentLog) {
                return res.status(409).json({
                    success: false,
                    code: "EARLY_RELEASE_REQUIRES_APPROVAL",
                    error: "ยังไม่ถึงเวลาปล่อยรถ และยังไม่มีการยินยอมรับรถก่อนเวลาจากผู้จอง"
                });
            }
        }

        // TASK 2 & 9: Overlap Re-check ก่อน Release คืน 409 พร้อม Detail
        const conflictingBooking = await prisma.vehicleBooking.findFirst({
            where: {
                id: { not: bookingId },
                vehicleId: bookingExists.vehicleId,
                status: {
                    in: [BookingStatus.PENDING, BookingStatus.APPROVED, BookingStatus.IN_USE]
                },
                startDatetime: { lt: bookingExists.endDatetime },
                endDatetime: { gt: bookingExists.startDatetime }
            }
        });

        if (conflictingBooking) {
            return res.status(409).json({
                success: false,
                message: "ไม่สามารถปล่อยรถได้ เนื่องจากมีรายการจองซ้อนทับ",
                conflict: {
                    bookingId: conflictingBooking.id,
                    startDatetime: conflictingBooking.startDatetime,
                    endDatetime: conflictingBooking.endDatetime,
                    status: conflictingBooking.status
                }
            });
        }

        // TASK 4: Mileage Logic เดิม 
        const parsedMileage = parseFloat(checkoutMileage || mileage);
        const finalMileage = !isNaN(parsedMileage) ? parsedMileage : (bookingExists.vehicle.currentMileage || 0);
        const parsedFuel = parseFloat(checkoutFuelLevel || fuelLevel);
        const finalFuelLevel = !isNaN(parsedFuel) ? parsedFuel : 100;

        const requestFiles = req.files || (req.file ? [req.file] : null);
        const allUploadedFiles = requestFiles ? (Array.isArray(requestFiles) ? requestFiles : Object.values(requestFiles).flat()) : [];
        let frontFile = getUploadedFile(requestFiles, ['frontImage', 'front', 'frontPhoto', 'checkoutFrontPhoto', 'checkout_front_photo']) || allUploadedFiles[0];
        let backFile = getUploadedFile(requestFiles, ['backImage', 'back', 'backPhoto', 'checkoutBackPhoto', 'checkout_back_photo']) || allUploadedFiles[1];
        let mileageFile = getUploadedFile(requestFiles, ['mileageImage', 'mileage', 'mileagePhoto', 'checkoutMileagePhoto', 'checkout_mileage_photo', 'dashboardImage']) || allUploadedFiles[2];

        const assignedFiles = [frontFile, backFile, mileageFile].filter(Boolean);
        const unassignedFiles = allUploadedFiles.filter(f => !assignedFiles.includes(f));

        if (!frontFile && unassignedFiles.length > 0) frontFile = unassignedFiles.shift();
        if (!backFile && unassignedFiles.length > 0) backFile = unassignedFiles.shift();
        if (!mileageFile && unassignedFiles.length > 0) mileageFile = unassignedFiles.shift();

        const baseUploadDir = process.env.UPLOAD_DIR || path.join(__dirname, '../../attachments');
        const releaseDir = path.join(baseUploadDir, 'vehicles', 'inspections', String(bookingId), 'release');

        const normalizePath = (filePath) => {
            if (!filePath) return null;
            const clean = filePath.replace(/\\/g, '/');
            const idx = clean.indexOf('attachments/');
            return idx !== -1 ? '/' + clean.substring(idx) : (clean.startsWith('/') ? clean : '/' + clean);
        };

        let imagesToSave = [frontFile, backFile, mileageFile].filter(Boolean);
        if (imagesToSave.length === 0 && allUploadedFiles.length > 0) {
            imagesToSave = allUploadedFiles;
        }

        // เตรียมรายชื่อไฟล์และ Path ล่วงหน้า เพื่อใช้งานใน Transaction และ File I/O ถัดไป
        const uniqueFilesMap = new Map();
        imagesToSave.forEach((file, index) => {
            if (file) {
                const filename = file.filename || (file.path ? path.basename(file.path) : null) || file.originalname || `${Date.now()}-${Math.round(Math.random() * 1e9)}.jpg`;
                const destPath = path.join(releaseDir, filename);
                const relativePath = normalizePath(destPath) || filename;
                
                if (!uniqueFilesMap.has(relativePath)) {
                    uniqueFilesMap.set(relativePath, { ...file, filename, destPath, relativePath });
                }
            }
        });

        // TASK 3 & 7: DB Transaction (ไม่รวม File I/O)
        const updatedData = await prisma.$transaction(async (tx) => {
            const previousActive = await tx.vehicleBooking.findFirst({
                where: {
                    vehicleId: bookingExists.vehicleId,
                    status: BookingStatus.IN_USE,
                    id: { not: bookingId }
                }
            });

            if (previousActive) {
                throw new Error("PREVIOUS_BOOKING_ACTIVE");
            }

            const updatedBooking = await tx.vehicleBooking.update({
                where: { id: bookingId },
                data: { status: validStatus },
                include: {
                    user: { include: { employee: true } },
                    vehicle: true
                }
            });

            await tx.vehicle.update({
                where: { id: bookingExists.vehicleId },
                data: { 
                    status: VehicleStatus.IN_USE,
                    currentMileage: finalMileage
                }
            });

            const existingLog = await tx.vehicleLog.findFirst({
                where: { vehicleBookingId: bookingId }
            });

            if (existingLog) {
                await tx.vehicleLog.update({
                    where: { id: existingLog.id },
                    data: {
                        checkoutTime: now,
                        checkoutMileage: finalMileage,
                        checkoutFuelLevel: finalFuelLevel,
                        checkoutById: currentUserId
                    }
                });
            } else {
                await tx.vehicleLog.create({
                    data: {
                        vehicleBookingId: bookingId,
                        checkoutTime: now,
                        checkoutMileage: finalMileage,
                        checkoutFuelLevel: finalFuelLevel,
                        checkoutById: currentUserId
                    }
                });
            }

            // TASK 5: เช็ก Attachment Duplicate ก่อน Create
            for (const file of uniqueFilesMap.values()) {
                const existingAttachment = await tx.attachment.findFirst({
                    where: {
                        entityType: "VEHICLE_RELEASE_IMAGE",
                        entityId: bookingId,
                        fileName: file.filename
                    }
                });

                if (existingAttachment) {
                    await tx.attachment.update({
                        where: { id: existingAttachment.id },
                        data: {
                            filePath: file.relativePath,
                            fileType: file.mimetype || 'image/jpeg'
                        }
                    });
                } else {
                    await tx.attachment.create({
                        data: {
                            entityType: "VEHICLE_RELEASE_IMAGE",
                            entityId: bookingId,
                            fileName: file.filename,
                            filePath: file.relativePath,
                            fileType: file.mimetype || 'image/jpeg',
                            uploadedBy: { connect: { id: currentUserId } },
                            bookingVehicle: { connect: { id: bookingId } }
                        }
                    });
                }
            }

            await tx.auditLog.create({
                data: {
                    action: 'RELEASE_VEHICLE',
                    module: 'VEHICLE_BOOKING',
                    userId: currentUserId,
                    entityId: bookingId,
                    entityType: 'VEHICLE_BOOKING',
                    details: JSON.stringify({
                        oldStatus: bookingExists.status,
                        newStatus: validStatus,
                        hasAttachments: (req.files || req.file) ? true : false,
                        remark: remark || "ทำการปล่อยรถออกและบันทึกภาพถ่าย"
                    })
                }
            });

            await tx.notification.updateMany({
                where: { entityType: 'VEHICLE_BOOKING', entityId: bookingId, isRead: false },
                data: { isRead: true }
            });

            return updatedBooking;
        });

        // TASK 6 & 7: Finalize File I/O หลัง DB Transaction สำเร็จ และยกเลิกการ Cleanup Folder อื่น
        if (!fs.existsSync(releaseDir)) {
            fs.mkdirSync(releaseDir, { recursive: true, mode: 0o777 });
        }

        for (const file of uniqueFilesMap.values()) {
            const destPath = file.destPath;
            if (file.buffer) {
                fs.writeFileSync(destPath, file.buffer);
                try { fs.chmodSync(destPath, 0o777); } catch (e) {}
            } else if (file.path) {
                if (file.path !== destPath && fs.existsSync(file.path)) {
                    fs.copyFileSync(file.path, destPath);
                    try { fs.chmodSync(destPath, 0o777); } catch (e) {}
                    try { fs.unlinkSync(file.path); } catch (e) {}
                }
            }
        }

        return res.status(200).json({
            success: true,
            message: "อัปเดตการปล่อยรถและบันทึกรูปภาพสำเร็จ",
            data: updatedData
        });

    } catch (error) {
        console.error("Release Vehicle Error:", error);
        
        // ถ้าเกิด Error (รวมถึง DB Transaction Fail) ให้ลบไฟล์ Temp ทิ้ง
        const requestFiles = req.files || (req.file ? [req.file] : null);
        if (requestFiles) {
            const tempFiles = Array.isArray(requestFiles) ? requestFiles : Object.values(requestFiles).flat();
            tempFiles.forEach(file => {
                if (file.path && fs.existsSync(file.path)) {
                    try { fs.unlinkSync(file.path); } catch (e) {}
                }
            });
        }

        if (error.message === 'PREVIOUS_BOOKING_ACTIVE') {
            return res.status(409).json({ success: false, code: "PREVIOUS_BOOKING_ACTIVE", error: "มีคิวก่อนหน้าที่ยังใช้งานรถอยู่" });
        }
        if (error.code === 'P2002') {
            return res.status(409).json({ success: false, code: "DUPLICATE_RECORD", error: "รายการ Log การใช้งานรถยนต์นี้ถูกสร้างไปแล้ว" });
        }
        return res.status(500).json({ success: false, error: "เกิดข้อผิดพลาดในการบันทึกข้อมูลปล่อยรถ", developerMessage: error.message });
    }
};

// =======================================================
// 5. เสร็จสิ้นการใช้งานรถ (PUT /:id/complete)
// =======================================================
exports.completeVehicleBooking = async (req, res) => {
    try {
        const bookingId = parseInt(req.params.id, 10);
        const reqUserId = parseInt(req.user?.userId || req.user?.id, 10);

        if (isNaN(bookingId)) {
            return res.status(400).json({ success: false, error: "รหัสการจองไม่ถูกต้อง" });
        }
        if (isNaN(reqUserId)) {
            return res.status(401).json({ success: false, error: "ไม่พบข้อมูลผู้ดำเนินการ (Unauthorized)" });
        }

        const userRole = req.user?.role;
        const { returnMileage, mileage, returnFuelLevel, fuelLevel } = req.body;

        const booking = await prisma.vehicleBooking.findUnique({
            where: { id: bookingId }
        });

        if (!booking) {
            return res.status(404).json({ success: false, message: "ไม่พบรายการจอง" });
        }

        if (booking.status !== BookingStatus.IN_USE) {
            return res.status(409).json({ success: false, code: "NOT_IN_USE", message: "รายการจองนี้ยังไม่ได้ถูกปล่อยรถ หรือเสร็จสิ้นไปแล้ว" });
        }

        const isOwner = booking.userId === reqUserId;
        const isAssignedSelfDriver = booking.driverType === 'SELF_DRIVE' && (booking.driverUserId === reqUserId || booking.driverEmployeeId === reqUserId);
        const isAssignedCompanyDriver = ['COMPANY', 'COMPANY_DRIVER'].includes(booking.driverType) && booking.driverEmployeeId === reqUserId;

        if (userRole !== 'ADMIN' && userRole !== 'GUARD' && userRole !== 'SECURITY' && !isOwner && !isAssignedSelfDriver && !isAssignedCompanyDriver) {
            return res.status(403).json({ success: false, message: "คุณไม่มีสิทธิ์ทำรายการนี้ (อนุญาตเฉพาะผู้จอง, คนขับรถที่ถูกจัดสรร หรือเจ้าหน้าที่ที่เกี่ยวข้อง)" });
        }

        const now = new Date();
        const isAuthorizedStaff = ['ADMIN', 'GUARD', 'SECURITY'].includes(userRole);

        if (now < booking.endDatetime && !isAuthorizedStaff) {
            const consentLog = await prisma.auditLog.findFirst({
                where: {
                    module: 'VEHICLE_BOOKING',
                    entityId: bookingId,
                    action: 'EARLY_RETURN_CONSENT_GRANTED'
                }
            });

            if (!consentLog) {
                return res.status(409).json({
                    success: false,
                    code: "EARLY_RETURN_REQUIRES_APPROVAL",
                    message: "ยังไม่ถึงเวลาคืนรถตามกำหนด และยังไม่มีการยินยอมคืนรถก่อนเวลาจากผู้จอง"
                });
            }
        }

        const parsedReturnMileage = parseFloat(returnMileage || mileage);
        const parsedReturnFuel = parseFloat(returnFuelLevel || fuelLevel);

        await prisma.$transaction(async (tx) => {
            await tx.vehicleBooking.update({
                where: { id: bookingId },
                data: { status: BookingStatus.COMPLETED } 
            });

            const latestLog = await tx.vehicleLog.findFirst({
                where: { vehicleBookingId: bookingId },
                orderBy: { createdAt: 'desc' }
            });

            const requestFiles = req.files || (req.file ? [req.file] : null);
            const allUploadedFiles = requestFiles ? (Array.isArray(requestFiles) ? requestFiles : Object.values(requestFiles).flat()) : [];
            let returnFrontFile = getUploadedFile(requestFiles, ['frontImage', 'returnFrontPhoto', 'return_front_photo', 'front', 'frontPhoto']) || allUploadedFiles[0];
            let returnBackFile = getUploadedFile(requestFiles, ['backImage', 'returnBackPhoto', 'return_back_photo', 'back', 'backPhoto']) || allUploadedFiles[1];
            let returnMileageFile = getUploadedFile(requestFiles, ['mileageImage', 'returnMileagePhoto', 'return_mileage_photo', 'mileage', 'mileagePhoto', 'dashboardImage']) || allUploadedFiles[2];

            const assignedFiles = [returnFrontFile, returnBackFile, returnMileageFile].filter(Boolean);
            const unassignedFiles = allUploadedFiles.filter(f => !assignedFiles.includes(f));

            if (!returnFrontFile && unassignedFiles.length > 0) returnFrontFile = unassignedFiles.shift();
            if (!returnBackFile && unassignedFiles.length > 0) returnBackFile = unassignedFiles.shift();
            if (!returnMileageFile && unassignedFiles.length > 0) returnMileageFile = unassignedFiles.shift();

            // 🟢 1. สร้าง โฟลเดอร์ปลายทาง NAS / Inspections Target และคัดลอกย้ายไฟล์เข้ามาให้เรียบร้อย
            const baseUploadDir = process.env.UPLOAD_DIR || path.join(__dirname, '../../attachments');
            const returnDir = path.join(baseUploadDir, 'vehicles', 'inspections', String(bookingId), 'return');
            if (!fs.existsSync(returnDir)) {
                fs.mkdirSync(returnDir, { recursive: true, mode: 0o777 });
            }

            const moveFileToNAS = (file) => {
                if (!file) return;
                const filename = file.filename || (file.path ? path.basename(file.path) : null) || file.originalname || `${Date.now()}-${Math.round(Math.random() * 1e9)}.jpg`;
                const destPath = path.join(returnDir, filename);

                if (file.buffer) {
                    fs.writeFileSync(destPath, file.buffer);
                    try { fs.chmodSync(destPath, 0o777); } catch (e) {}
                    file.path = destPath;
                    file.filename = filename;
                } else if (file.path) {
                    if (file.path !== destPath && fs.existsSync(file.path)) {
                        fs.copyFileSync(file.path, destPath);
                        try { fs.chmodSync(destPath, 0o777); } catch (e) {}
                        try { fs.unlinkSync(file.path); } catch (e) {}
                    } else if (fs.existsSync(destPath)) {
                        try { fs.chmodSync(destPath, 0o777); } catch (e) {}
                    }
                    file.path = destPath;
                    file.filename = filename;
                }
            };
            [returnFrontFile, returnBackFile, returnMileageFile].forEach(moveFileToNAS);

            const normalizePath = (filePath) => {
                if (!filePath) return null;
                const clean = filePath.replace(/\\/g, '/');
                const idx = clean.indexOf('attachments/');
                return idx !== -1 ? '/' + clean.substring(idx) : (clean.startsWith('/') ? clean : '/' + clean);
            };

            const currentUploadedNames = [returnFrontFile, returnBackFile, returnMileageFile].filter(Boolean).map(f => f.filename);

            if (fs.existsSync(returnDir) && currentUploadedNames.length > 0) {
                const files = fs.readdirSync(returnDir);
                for (const file of files) {
                    if (!currentUploadedNames.includes(file)) {
                        try { fs.unlinkSync(path.join(returnDir, file)); } catch (e) {}
                    }
                }
            }

            if (latestLog) {
                const logUpdateData = {
                    returnTime: new Date(),
                    returnById: reqUserId
                };
                if (!isNaN(parsedReturnMileage)) {
                    logUpdateData.returnMileage = parsedReturnMileage;
                }
                if (!isNaN(parsedReturnFuel)) {
                    logUpdateData.returnFuelLevel = parsedReturnFuel;
                }
                await tx.vehicleLog.update({
                    where: { id: latestLog.id },
                    data: logUpdateData
                });
            } else {
                await tx.vehicleLog.create({
                    data: {
                        vehicleBookingId: bookingId,
                        returnTime: new Date(),
                        returnMileage: !isNaN(parsedReturnMileage) ? parsedReturnMileage : undefined,
                        returnFuelLevel: !isNaN(parsedReturnFuel) ? parsedReturnFuel : undefined,
                        returnById: reqUserId
                    }
                });
            }

            const vehicleUpdateData = { status: VehicleStatus.AVAILABLE };
            if (!isNaN(parsedReturnMileage) && parsedReturnMileage > 0) {
                vehicleUpdateData.currentMileage = parsedReturnMileage;
            }

            await tx.vehicle.update({
                where: { id: booking.vehicleId },
                data: vehicleUpdateData
            });

            let imagesToSave = [returnFrontFile, returnBackFile, returnMileageFile].filter(Boolean);
            if (imagesToSave.length === 0 && allUploadedFiles.length > 0) {
                imagesToSave = allUploadedFiles;
            }
            if (imagesToSave.length > 0) {
                const uniqueFilesMap = new Map();

                imagesToSave.forEach((file, index) => {
                    if (file) {
                        const relativePath = normalizePath(file.path) || file.filename || file.originalname || `file_${index}`;
                        if (!uniqueFilesMap.has(relativePath)) {
                            uniqueFilesMap.set(relativePath, { ...file, relativePath });
                        }
                    }
                });

                for (const file of uniqueFilesMap.values()) {
                    await tx.attachment.create({
                        data: {
                            entityType: "VEHICLE_RETURN_IMAGE",
                            entityId: bookingId,
                            fileName: file.originalname || file.filename || `return_${Date.now()}.jpg`,
                            filePath: file.relativePath,
                            fileType: file.mimetype || 'image/jpeg',
                            uploadedBy: { connect: { id: reqUserId } },
                            bookingVehicle: { connect: { id: bookingId } }
                        }
                    });
                }
            }

            await tx.auditLog.create({
                data: {
                    action: 'COMPLETE_VEHICLE_BOOKING',
                    module: 'VEHICLE_BOOKING',
                    entityId: bookingId,
                    entityType: 'VEHICLE_BOOKING',
                    userId: reqUserId,
                    details: JSON.stringify({
                        oldStatus: booking.status,
                        newStatus: BookingStatus.COMPLETED,
                        hasAttachments: (req.files || req.file) ? true : false,
                        remark: "เสร็จสิ้นการใช้งานและคืนสถานะรถว่าง (รับรถเข้า)"
                    })
                }
            });

            await tx.notification.updateMany({
                where: { entityType: 'VEHICLE_BOOKING', entityId: bookingId, isRead: false },
                data: { isRead: true }
            });
        });

        return res.status(200).json({
            success: true,
            message: "Vehicle booking completed successfully."
        });

    } catch (error) {
        console.error("Complete Booking Error:", error);

        const requestFiles = req.files || (req.file ? [req.file] : null);
        if (requestFiles) {
            const tempFiles = Array.isArray(requestFiles) ? requestFiles : Object.values(requestFiles).flat();
            tempFiles.forEach(file => {
                if (file.path && fs.existsSync(file.path)) {
                    try { fs.unlinkSync(file.path); } catch (e) {}
                }
            });
        }

        return res.status(500).json({ success: false, message: "เกิดข้อผิดพลาดของระบบ", developerMessage: error.message });
    }
};

// =======================================================
// 🟢 6. อนุมัติการจองรถยนต์ (POST /:id/approve)
// =======================================================
exports.approveVehicleBooking = async (req, res) => {
    try {
        const bookingId = parseInt(req.params.id, 10);
        const adminId = parseInt(req.user?.userId || req.user?.id, 10);

        const booking = await prisma.vehicleBooking.findUnique({ where: { id: bookingId } });
        if (!booking) return res.status(404).json({ success: false, error: "ไม่พบการจอง" });

        if (booking.status !== BookingStatus.PENDING) {
            return res.status(409).json({
                success: false,
                error: "รายการจองนี้ไม่อยู่ในสถานะรออนุมัติ"
            });
        }

        const updatedBooking = await prisma.$transaction(async (tx) => {
            const conflictingBooking = await tx.vehicleBooking.findFirst({
                where: {
                    id: { not: bookingId },
                    vehicleId: booking.vehicleId,
                    status: {
                        in: [BookingStatus.PENDING, BookingStatus.APPROVED, BookingStatus.IN_USE]
                    },
                    startDatetime: { lt: booking.endDatetime },
                    endDatetime: { gt: booking.startDatetime }
                }
            });

            if (conflictingBooking) {
                throw new Error('TIME_OVERLAP');
            }

            if (booking.driverEmployeeId) {
                const conflictingDriver = await tx.vehicleBooking.findFirst({
                    where: {
                        id: { not: bookingId },
                        driverEmployeeId: booking.driverEmployeeId,
                        status: { 
                            in: [BookingStatus.PENDING, BookingStatus.APPROVED, BookingStatus.IN_USE] 
                        },
                        startDatetime: { lt: booking.endDatetime },
                        endDatetime: { gt: booking.startDatetime }
                    }
                });
                if (conflictingDriver) throw new Error('DRIVER_OVERLAP');
            }

            const updated = await tx.vehicleBooking.update({
                where: { id: bookingId },
                data: { status: BookingStatus.APPROVED },
                include: {
                    user: { include: { employee: true } },
                    vehicle: true
                }
            });

            await tx.auditLog.create({
                data: {
                    action: 'APPROVE_VEHICLE_BOOKING',
                    module: 'VEHICLE_BOOKING',
                    userId: adminId,
                    entityId: bookingId,
                    entityType: 'VEHICLE_BOOKING',
                    details: JSON.stringify({ oldStatus: booking.status, newStatus: BookingStatus.APPROVED })
                }
            });
            return updated;
        });

        // 🔔 ส่ง Notification หายูสเซอร์
        await notificationService.createNotification({
            userId: booking.userId,
            title: "✅ อนุมัติการจองรถยนต์",
            message: `คำขอจองรถยนต์ของคุณ (ปลายทาง: ${booking.destination || '-'}) ได้รับการอนุมัติแล้ว`,
            type: 'APPROVAL',
            entityType: 'VEHICLE_BOOKING',
            entityId: bookingId
        });

        return res.status(200).json({ success: true, data: updatedBooking, message: "อนุมัติสำเร็จ" });
    } catch (error) {
        console.error("Approve Vehicle Error:", error);

        if (error.message === 'TIME_OVERLAP') {
            return res.status(409).json({
                success: false,
                error: "ไม่สามารถอนุมัติการจองได้ เนื่องจากช่วงเวลาซ้อนกับรายการจองอื่น"
            });
        }
        if (error.message === 'DRIVER_OVERLAP') {
            return res.status(409).json({
                success: false,
                error: "ไม่สามารถอนุมัติการจองได้ เนื่องจากพนักงานขับรถหรือผู้ขับขี่มีคิวงานซ้อน"
            });
        }

        return res.status(500).json({ success: false, error: "ไม่สามารถอนุมัติได้" });
    }
};

// =======================================================
// 🟢 7. ปฏิเสธการจองรถยนต์ (POST /:id/reject)
// =======================================================
exports.rejectVehicleBooking = async (req, res) => {
    try {
        const bookingId = parseInt(req.params.id, 10);
        const adminId = parseInt(req.user?.userId || req.user?.id, 10);
        const { remark } = req.body;

        const booking = await prisma.vehicleBooking.findUnique({ where: { id: bookingId } });
        if (!booking) return res.status(404).json({ success: false, error: "ไม่พบการจอง" });

        if (booking.status !== BookingStatus.PENDING) {
            return res.status(409).json({
                success: false,
                error: "รายการจองนี้ไม่อยู่ในสถานะรออนุมัติ"
            });
        }

        const updatedBooking = await prisma.$transaction(async (tx) => {
            const updated = await tx.vehicleBooking.update({
                where: { id: bookingId },
                data: { status: BookingStatus.REJECTED },
                include: {
                    user: { include: { employee: true } },
                    vehicle: true
                }
            });

            await tx.vehicle.update({
                where: { id: booking.vehicleId },
                data: { status: VehicleStatus.AVAILABLE }
            });

            await tx.auditLog.create({
                data: {
                    action: 'REJECT_VEHICLE_BOOKING',
                    module: 'VEHICLE_BOOKING',
                    userId: adminId,
                    entityId: bookingId,
                    entityType: 'VEHICLE_BOOKING',
                    details: JSON.stringify({ remark: remark || 'ปฏิเสธคำขอจองโดยผู้ดูแลระบบ' })
                }
            });
            return updated;
        });

        // 🔔 ส่ง Notification หายูสเซอร์
        await notificationService.createNotification({
            userId: booking.userId,
            title: "❌ ปฏิเสธการจองรถยนต์",
            message: `คำขอจองรถยนต์ของคุณถูกปฏิเสธ หมายเหตุ: ${remark || 'ไม่ระบุเหตุผล'}`,
            type: 'APPROVAL',
            entityType: 'VEHICLE_BOOKING',
            entityId: bookingId
        });

        return res.status(200).json({ success: true, data: updatedBooking, message: "ปฏิเสธสำเร็จ" });
    } catch (error) {
        console.error("Reject Vehicle Error:", error);
        return res.status(500).json({ success: false, error: "ไม่สามารถปฏิเสธได้" });
    }
};

// =======================================================
// 🟢 8. ส่งคำขอปล่อยรถก่อนเวลาไปยังผู้จอง (POST /:id/early-request)
// =======================================================
exports.requestEarlyRelease = async (req, res) => {
    try {
        const bookingId = parseInt(req.params.id, 10);
        const requesterId = parseInt(req.user?.userId || req.user?.id, 10);

        const booking = await prisma.vehicleBooking.findUnique({
            where: { id: bookingId },
            include: { vehicle: true }
        });

        if (!booking) return res.status(404).json({ success: false, error: "ไม่พบข้อมูลการจอง" });

        if (![BookingStatus.APPROVED, BookingStatus.PENDING].includes(booking.status)) {
            return res.status(409).json({ success: false, error: "รายการจองนี้ไม่อยู่ในสถานะที่ขอรับรถก่อนเวลาได้" });
        }

        const now = new Date();
        if (now >= booking.startDatetime) {
            return res.status(400).json({ success: false, error: "ถึงเวลารับรถตามปกติแล้ว ไม่จำเป็นต้องขอปลดล็อกก่อนเวลา" });
        }

        await notificationService.createNotification({
            recipientId: booking.userId,
            userId: booking.userId,
            title: "⚠️ คำขอรับรถก่อนเวลา",
            message: `เจ้าหน้าที่ขอคำยินยอมปล่อยรถยนต์ทะเบียน ${booking.vehicle.plateNumber} ก่อนเวลาจอง กรุณากดยืนยันหากท่านต้องการรับรถเลย`,
            type: 'APPROVAL',
            entityType: 'VEHICLE_BOOKING',
            entityId: bookingId
        });

        // บันทึก AuditLog สถานะการร้องขอ
        await prisma.auditLog.create({
            data: {
                action: 'EARLY_RELEASE_REQUESTED',
                module: 'VEHICLE_BOOKING',
                userId: requesterId,
                entityId: bookingId,
                entityType: 'VEHICLE_BOOKING',
                details: JSON.stringify({ remark: "ส่งคำขอรับรถก่อนเวลาไปยังผู้จอง" })
            }
        });

        return res.status(200).json({ success: true, message: "ส่งคำขอรับรถก่อนเวลาไปยังผู้จองเรียบร้อยแล้ว" });
    } catch (error) {
        console.error("Request Early Release Error:", error);
        return res.status(500).json({ success: false, error: "เกิดข้อผิดพลาดในการส่งคำขอรับรถก่อนเวลา" });
    }
};

// =======================================================
// 🟢 9. ผู้จองตอบรับหรือปฏิเสธคำขอปล่อยรถก่อนเวลา (POST /:id/early-respond)
// =======================================================
exports.respondEarlyRelease = async (req, res) => {
    try {
        const bookingId = parseInt(req.params.id, 10);
        const userId = parseInt(req.user?.userId || req.user?.id, 10);
        const { approved, action } = req.body;

        if (isNaN(userId)) {
            return res.status(401).json({ success: false, error: "ไม่พบสิทธิ์การใช้งานหรือรูปแบบผู้ใช้งานไม่ถูกต้อง" });
        }

        const booking = await prisma.vehicleBooking.findUnique({ where: { id: bookingId } });
        if (!booking) return res.status(404).json({ success: false, error: "ไม่พบข้อมูลการจอง" });

        if (booking.userId !== userId) {
            return res.status(403).json({ success: false, error: "คุณไม่มีสิทธิ์ตอบรับคำขอนี้" });
        }

        if (['COMPLETED', 'CANCELLED', 'REJECTED'].includes(booking.status)) {
            return res.status(400).json({ success: false, error: "รายการจองนี้สิ้นสุดไปแล้ว ไม่สามารถตอบรับคำขอได้" });
        }

        const normalizedAction = action ? String(action).toUpperCase() : '';
        const isApproved = approved === true || approved === 'true' || ['APPROVE', 'CONFIRM', 'ACCEPT', 'AGREE', 'YES'].includes(normalizedAction);
        const finalAction = isApproved ? 'EARLY_RELEASE_CONSENT_GRANTED' : 'EARLY_RELEASE_CONSENT_DENIED';

        await prisma.auditLog.create({
            data: {
                action: finalAction,
                module: 'VEHICLE_BOOKING',
                userId: userId,
                entityId: bookingId,
                entityType: 'VEHICLE_BOOKING',
                details: JSON.stringify({ approved: isApproved, actionReceived: action })
            }
        });

        await prisma.notification.updateMany({
            where: { entityType: 'VEHICLE_BOOKING', entityId: bookingId, isRead: false },
            data: { isRead: true }
        });

        return res.status(200).json({
            success: true,
            message: isApproved ? "ยินยอมให้ปล่อยรถก่อนเวลาเรียบร้อยแล้ว" : "ปฏิเสธการรับรถก่อนเวลา"
        });
    } catch (error) {
        console.error("Respond Early Release Error:", error);
        return res.status(500).json({ success: false, error: "เกิดข้อผิดพลาดในการตอบรับคำขอรับรถก่อนเวลา" });
    }
};

// =======================================================
// 🟢 10. ส่งคำขอรับรถคืนก่อนเวลาไปยังผู้จอง (POST /:id/early-return-request)
// =======================================================
exports.requestEarlyReturn = async (req, res) => {
    try {
        const bookingId = parseInt(req.params.id, 10);
        const requesterId = parseInt(req.user?.userId || req.user?.id, 10);

        const booking = await prisma.vehicleBooking.findUnique({
            where: { id: bookingId },
            include: { vehicle: true }
        });

        if (!booking) return res.status(404).json({ success: false, error: "ไม่พบข้อมูลการจอง" });

        if (booking.status !== BookingStatus.IN_USE) {
            return res.status(409).json({ success: false, error: "รายการจองนี้ไม่อยู่ในสถานะใช้งาน" });
        }

        const now = new Date();
        if (now >= booking.endDatetime) {
            return res.status(400).json({ success: false, error: "ถึงเวลาคืนรถตามปกติแล้ว ไม่จำเป็นต้องขอปลดล็อกก่อนเวลา" });
        }

        await notificationService.createNotification({
            recipientId: booking.userId,
            userId: booking.userId,
            title: "⚠️ คำขอคืนรถก่อนเวลา",
            message: `เจ้าหน้าที่ขอคำยินยอมรับคืนรถยนต์ทะเบียน ${booking.vehicle.plateNumber} ก่อนเวลาจอง กรุณากดยืนยันหากท่านคืนรถแล้ว`,
            type: 'APPROVAL',
            entityType: 'VEHICLE_BOOKING',
            entityId: bookingId
        });

        // บันทึก AuditLog สถานะการร้องขอ
        await prisma.auditLog.create({
            data: {
                action: 'EARLY_RETURN_REQUESTED',
                module: 'VEHICLE_BOOKING',
                userId: requesterId,
                entityId: bookingId,
                entityType: 'VEHICLE_BOOKING',
                details: JSON.stringify({ remark: "ส่งคำขอคืนรถก่อนเวลาไปยังผู้จอง" })
            }
        });

        return res.status(200).json({ success: true, message: "ส่งคำขอรับรถคืนก่อนเวลาไปยังผู้จองเรียบร้อยแล้ว" });
    } catch (error) {
        console.error("Request Early Return Error:", error);
        return res.status(500).json({ success: false, error: "เกิดข้อผิดพลาดในการส่งคำขอรับรถคืนก่อนเวลา" });
    }
};

// =======================================================
// 🟢 11. ผู้จองตอบรับหรือปฏิเสธคำขอรับรถคืนก่อนเวลา (POST /:id/early-return-respond)
// =======================================================
exports.respondEarlyReturn = async (req, res) => {
    try {
        const bookingId = parseInt(req.params.id, 10);
        const userId = parseInt(req.user?.userId || req.user?.id, 10);
        const { approved, action } = req.body;

        if (isNaN(userId)) {
            return res.status(401).json({ success: false, error: "ไม่พบสิทธิ์การใช้งานหรือรูปแบบผู้ใช้งานไม่ถูกต้อง" });
        }

        const booking = await prisma.vehicleBooking.findUnique({ where: { id: bookingId } });
        if (!booking) return res.status(404).json({ success: false, error: "ไม่พบข้อมูลการจอง" });

        if (booking.userId !== userId) {
            return res.status(403).json({ success: false, error: "คุณไม่มีสิทธิ์ตอบรับคำขอนี้" });
        }

        if (['COMPLETED', 'CANCELLED', 'REJECTED'].includes(booking.status)) {
            return res.status(400).json({ success: false, error: "รายการจองนี้สิ้นสุดไปแล้ว ไม่สามารถตอบรับคำขอได้" });
        }

        const normalizedAction = action ? String(action).toUpperCase() : '';
        const isApproved = approved === true || approved === 'true' || ['APPROVE', 'CONFIRM', 'ACCEPT', 'AGREE', 'YES'].includes(normalizedAction);
        const finalAction = isApproved ? 'EARLY_RETURN_CONSENT_GRANTED' : 'EARLY_RETURN_CONSENT_DENIED';

        await prisma.auditLog.create({
            data: {
                action: finalAction,
                module: 'VEHICLE_BOOKING',
                userId: userId,
                entityId: bookingId,
                entityType: 'VEHICLE_BOOKING',
                details: JSON.stringify({ approved: isApproved, actionReceived: action })
            }
        });

        await prisma.notification.updateMany({
            where: { entityType: 'VEHICLE_BOOKING', entityId: bookingId, isRead: false },
            data: { isRead: true }
        });

        return res.status(200).json({
            success: true,
            message: isApproved ? "ยินยอมให้คืนรถก่อนเวลาเรียบร้อยแล้ว" : "ปฏิเสธการคืนรถก่อนเวลา"
        });
    } catch (error) {
        console.error("Respond Early Return Error:", error);
        return res.status(500).json({ success: false, error: "เกิดข้อผิดพลาดในการตอบรับคำขอรับรถคืนก่อนเวลา" });
    }
};

// =======================================================
// 12. ดึงข้อมูลปฏิทินการจองรถยนต์ (GET /calendar)
// =======================================================
exports.getVehicleCalendar = async (req, res) => {
    try {
        const { startDate, endDate, vehicleId, status } = req.query;

        if (!startDate || !endDate) {
            return res.status(400).json({ 
                success: false, 
                error: 'กรุณาระบุ startDate และ endDate' 
            });
        }

        let whereClause = {
            startDatetime: { lte: new Date(endDate) },
            endDatetime: { gte: new Date(startDate) }
        };

        if (vehicleId) {
            whereClause.vehicleId = parseInt(vehicleId, 10);
        }

        if (status) {
            whereClause.status = status;
        } else {
            whereClause.status = {
                notIn: [BookingStatus.COMPLETED, BookingStatus.CANCELLED, BookingStatus.EXPIRED, BookingStatus.REJECTED]
            };
        }

        const bookings = await prisma.vehicleBooking.findMany({
            where: whereClause,
            include: {
                vehicle: {
                    include: {
                        documents: {
                            include: {
                                documentType: true
                            }
                        }
                    }
                },
                user: {
                    include: {
                        employee: {
                            include: { department: true }
                        }
                    }
                },
                driverEmployee: true,
                attachments: true,
                passengerDetails: true
            },
            orderBy: { startDatetime: 'asc' }
        });

        const formattedBookings = bookings.map(booking => {
            const actDoc = booking.vehicle?.documents?.find(doc => {
                const docTypeName = doc.documentType?.name || doc.name || doc.title || '';
                const docTypeKey = doc.documentType?.key || doc.type || '';
                return docTypeName.includes('พ.ร.บ') || docTypeName.includes('พรบ') || docTypeName.toUpperCase().includes('ACT') || docTypeKey.toUpperCase().includes('ACT');
            });

            const rawActUrl = booking.vehicle?.actFilePath || booking.vehicle?.act_file_path || booking.vehicle?.actFile || (actDoc ? (actDoc.uploadUrl || actDoc.filePath || actDoc.url || null) : null);

            const normalizePath = (filePath) => {
                if (!filePath) return null;
                const clean = String(filePath).replace(/\\/g, '/');
                const idx = clean.indexOf('attachments/');
                return idx !== -1 ? '/' + clean.substring(idx) : (clean.startsWith('/') ? clean : '/' + clean);
            };

            const actUrl = normalizePath(rawActUrl);

            const vehicleWithAct = booking.vehicle ? {
                ...booking.vehicle,
                actDocumentUrl: actUrl,
                actFilePath: actUrl,
                act_file_path: actUrl,
                actFile: actUrl,
                act_file: actUrl,
                actUrl: actUrl,
                actUploadUrl: actUrl,
                pororborUrl: actUrl
            } : booking.vehicle;

            const extractedPassengerNames = (booking.passengerDetails || [])
                .map(p => typeof p === 'object' && p !== null ? (p.fullName || p.passengerName || p.name || '') : String(p))
                .filter(name => name.trim().length > 0);

            const outboundList = (booking.passengerDetails || [])
                .filter(p => p.tripType === 'OUTBOUND')
                .map(p => typeof p === 'object' && p !== null ? (p.fullName || p.passengerName || p.name || '') : String(p))
                .filter(name => name.trim().length > 0);

            const inboundList = (booking.passengerDetails || [])
                .filter(p => p.tripType === 'INBOUND')
                .map(p => typeof p === 'object' && p !== null ? (p.fullName || p.passengerName || p.name || '') : String(p))
                .filter(name => name.trim().length > 0);

            return {
                ...booking,
                userName: booking.user?.employee?.fullName || booking.user?.username || '-',
                passengerNames: extractedPassengerNames.length > 0 ? extractedPassengerNames : (booking.passengerNames || []),
                outboundPassengers: outboundList,
                inboundPassengers: inboundList,
                outboundPassengerNames: outboundList,
                inboundPassengerNames: inboundList,
                companyDriver: booking.driverEmployee || null,
                companyDriverName: booking.driverEmployee?.fullName || booking.driverEmployee?.name || '-',
                vehicle: vehicleWithAct,
                actDocumentUrl: actUrl,
                actFilePath: actUrl,
                act_file_path: actUrl,
                actFile: actUrl,
                act_file: actUrl,
                actUrl: actUrl,
                actUploadUrl: actUrl,
                pororborUrl: actUrl,
                status: booking.status === 'APPROVED' ? 'RESERVED' : booking.status
            };
        });

        return res.status(200).json({
            success: true,
            data: formattedBookings
        });

    } catch (error) {
        console.error("Get Vehicle Calendar Error:", error);
        return res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลปฏิทินการจองรถยนต์ได้" });
    }
};

exports.getHistory = exports.getBookings;
exports.returnVehicle = exports.completeVehicleBooking;

// =======================================================
// 13. ดึงข้อมูลการจองตาม ID (GET /:id)
// =======================================================
exports.getBookingById = async (req, res) => {
    try {
        const bookingId = parseInt(req.params.id, 10);
        if (isNaN(bookingId)) {
            return res.status(400).json({ success: false, error: "รหัสการจองไม่ถูกต้อง" });
        }

        const booking = await prisma.vehicleBooking.findUnique({
            where: { id: bookingId },
            include: {
                vehicle: {
                    include: {
                        documents: {
                            include: {
                                documentType: true
                            }
                        }
                    }
                },
                user: {
                    include: { employee: true }
                },
                driverEmployee: true,
                attachments: true,
                passengerDetails: true,
                vehicleLogs: {
                    include: {
                        checkoutBy: { include: { employee: true } },
                        returnBy: { include: { employee: true } }
                    }
                }
            }
        });

        if (!booking) {
            return res.status(404).json({ success: false, error: "ไม่พบข้อมูลการจอง" });
        }

        const actDoc = booking.vehicle?.documents?.find(doc => {
            const docTypeName = doc.documentType?.name || doc.name || doc.title || '';
            const docTypeKey = doc.documentType?.key || doc.type || '';
            return docTypeName.includes('พ.ร.บ') || docTypeName.includes('พรบ') || docTypeName.toUpperCase().includes('ACT') || docTypeKey.toUpperCase().includes('ACT');
        });

        const rawActUrl = booking.vehicle?.actFilePath || booking.vehicle?.act_file_path || booking.vehicle?.actFile || (actDoc ? (actDoc.uploadUrl || actDoc.filePath || actDoc.url || null) : null);

        const normalizePath = (filePath) => {
            if (!filePath) return null;
            const clean = String(filePath).replace(/\\/g, '/');
            const idx = clean.indexOf('attachments/');
            return idx !== -1 ? '/' + clean.substring(idx) : (clean.startsWith('/') ? clean : '/' + clean);
        };

        const actUrl = normalizePath(rawActUrl);

        const extractedPassengerNames = (booking.passengerDetails || [])
            .map(p => typeof p === 'object' && p !== null ? (p.fullName || p.passengerName || p.name || '') : String(p))
            .filter(name => name.trim().length > 0);

        const outboundList = (booking.passengerDetails || [])
            .filter(p => p.tripType === 'OUTBOUND')
            .map(p => typeof p === 'object' && p !== null ? (p.fullName || p.passengerName || p.name || '') : String(p))
            .filter(name => name.trim().length > 0);

        const inboundList = (booking.passengerDetails || [])
            .filter(p => p.tripType === 'INBOUND')
            .map(p => typeof p === 'object' && p !== null ? (p.fullName || p.passengerName || p.name || '') : String(p))
            .filter(name => name.trim().length > 0);

        const normalizedAttachments = (booking.attachments || []).map(att => ({
            ...att,
            filePath: normalizePath(att.filePath) || att.filePath,
            url: normalizePath(att.filePath) || att.filePath
        }));

        const latestLog = Array.isArray(booking.vehicleLogs)
            ? (booking.vehicleLogs.length > 0 ? booking.vehicleLogs[booking.vehicleLogs.length - 1] : null)
            : (booking.vehicleLogs || null);

        const logReleaseImages = latestLog ? [latestLog.checkoutFrontPhoto, latestLog.checkoutBackPhoto, latestLog.checkoutMileagePhoto].filter(Boolean).map(a => normalizePath(a)) : [];
        const logReturnImages = latestLog ? [latestLog.returnFrontPhoto, latestLog.returnBackPhoto, latestLog.returnMileagePhoto].filter(Boolean).map(a => normalizePath(a)) : [];

        const releaseImages = [
            ...normalizedAttachments
                .filter(a => a.entityType === 'VEHICLE_RELEASE_IMAGE')
                .map(a => a.filePath),
            ...logReleaseImages
        ];

        const returnImages = [
            ...normalizedAttachments
                .filter(a => a.entityType === 'VEHICLE_RETURN_IMAGE')
                .map(a => a.filePath),
            ...logReturnImages
        ];

        const formattedBooking = {
            ...booking,
            userName: booking.user?.employee?.fullName || booking.user?.username || '-',
            passengerNames: extractedPassengerNames.length > 0 ? extractedPassengerNames : (booking.passengerNames || []),
            outboundPassengers: outboundList,
            inboundPassengers: inboundList,
            outboundPassengerNames: outboundList,
            inboundPassengerNames: inboundList,
            companyDriver: booking.driverEmployee || null,
            companyDriverName: booking.driverEmployee?.fullName || booking.driverEmployee?.name || '-',
            vehicle: booking.vehicle ? {
                ...booking.vehicle,
                actDocumentUrl: actUrl,
                actFilePath: actUrl,
                act_file_path: actUrl,
                actFile: actUrl,
                act_file: actUrl,
                actUrl: actUrl,
                actUploadUrl: actUrl,
                pororborUrl: actUrl
            } : booking.vehicle,
            actDocumentUrl: actUrl,
            actFilePath: actUrl,
            act_file_path: actUrl,
            actFile: actUrl,
            act_file: actUrl,
            actUrl: actUrl,
            actUploadUrl: actUrl,
            pororborUrl: actUrl,
            attachments: normalizedAttachments,
            checkoutTime: latestLog?.checkoutTime || null,
            returnTime: latestLog?.returnTime || null,
            actualCheckoutTime: latestLog?.checkoutTime || null,
            actualReturnTime: latestLog?.returnTime || null,
            releaseImages: releaseImages,
            returnImages: returnImages,
            releasePhotos: releaseImages,
            returnPhotos: returnImages,
            vehicleLogs: booking.vehicleLogs || [],
            vehicleLog: latestLog,
            checkoutMileage: latestLog?.checkoutMileage || null,
            returnMileage: latestLog?.returnMileage || null,
            checkoutFuelLevel: latestLog?.checkoutFuelLevel || null,
            returnFuelLevel: latestLog?.returnFuelLevel || null,
            checkoutByName: latestLog?.checkoutBy?.employee?.fullName || latestLog?.checkoutBy?.username || '-',
            returnByName: latestLog?.returnBy?.employee?.fullName || latestLog?.returnBy?.username || '-'
        };

        return res.status(200).json({ success: true, data: formattedBooking });
    } catch (error) {
        console.error("Get Booking By ID Error:", error);
        return res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลการจองได้" });
    }
};

// =======================================================
// 14. อัปเดตข้อมูลการจองรถยนต์ (PUT /:id) พร้อมบันทึก Diff
// =======================================================
exports.updateBooking = async (req, res) => {
    try {
        const bookingId = parseInt(req.params.id, 10);
        const currentUserId = req.user?.id || req.user?.userId || req.user?.sub || req.user?.user_id;

        if (isNaN(bookingId)) {
            return res.status(400).json({ success: false, error: "รหัสการจองไม่ถูกต้อง" });
        }

        const existingBooking = await prisma.vehicleBooking.findUnique({
            where: { id: bookingId }
        });

        if (!existingBooking) {
            return res.status(404).json({ success: false, error: "ไม่พบข้อมูลการจอง" });
        }

        const {
            vehicleId,
            destination,
            startDatetime,
            endDatetime,
            passengers,
            purpose,
            driverType,
            companyDriverId,
            driverEmployeeId,
            driverUserId
        } = req.body;

        console.log('[UPDATE BOOKING] Raw Request:', JSON.stringify(req.body, null, 2));
        
        if (endDatetime !== undefined) {
            console.log('[VEHICLE-END-DATETIME] 1. รับค่าจาก Client (Update) - endDatetime:', endDatetime);
        }

        if (startDatetime && isNaN(new Date(startDatetime).getTime())) {
            return res.status(400).json({ success: false, error: "รูปแบบวันและเวลาเริ่มต้นไม่ถูกต้อง" });
        }
        if (endDatetime !== undefined) {
            if (String(endDatetime).trim() === '') {
                return res.status(400).json({ success: false, error: "กรุณาระบุเวลาสิ้นสุด (ห้ามเว้นว่าง)" });
            }
            if (isNaN(new Date(endDatetime).getTime())) {
                return res.status(400).json({ success: false, error: "รูปแบบวันและเวลาสิ้นสุดไม่ถูกต้อง" });
            }
        }

        const updateData = {};
        if (vehicleId !== undefined) updateData.vehicleId = parseInt(vehicleId, 10);
        if (destination !== undefined) updateData.destination = destination;
        if (startDatetime !== undefined) updateData.startDatetime = new Date(startDatetime);
        if (endDatetime !== undefined) {
            updateData.endDatetime = new Date(endDatetime);
            console.log('[VEHICLE-END-DATETIME] 2. แปลงค่าเป็น Date Object (เวลาจริง Update) - endDatetime:', updateData.endDatetime);
        }
        if (passengers !== undefined) updateData.passengers = parseInt(passengers, 10);
        if (purpose !== undefined) updateData.purpose = purpose;
        if (driverType !== undefined) {
            updateData.driverType = (driverType === 'COMPANY' || driverType === 'บริษัท' || driverType === 'พนักงานขับรถ') ? 'COMPANY' : 'SELF_DRIVE';
        }
        const targetDriverEmpId = driverEmployeeId || companyDriverId;
        if (targetDriverEmpId !== undefined) {
            const parsedEmpId = parseInt(targetDriverEmpId, 10);
            updateData.driverEmployeeId = (!isNaN(parsedEmpId) && parsedEmpId > 0) ? parsedEmpId : null;
        }
        if (driverUserId !== undefined) {
            const parsedDriverUserId = parseInt(driverUserId, 10);
            updateData.driverUserId = (!isNaN(parsedDriverUserId) && parsedDriverUserId > 0) ? parsedDriverUserId : null;
        }

        console.log('[UPDATE BOOKING] Parsed Date:', { 
            startDatetime: updateData.startDatetime, 
            endDatetime: updateData.endDatetime 
        });

        const oldData = {
            vehicleId: existingBooking.vehicleId,
            destination: existingBooking.destination,
            startDatetime: existingBooking.startDatetime?.toISOString(),
            endDatetime: existingBooking.endDatetime?.toISOString(),
            passengers: existingBooking.passengers,
            purpose: existingBooking.purpose,
            driverType: existingBooking.driverType,
            driverEmployeeId: existingBooking.driverEmployeeId,
            driverUserId: existingBooking.driverUserId
        };

        const newDataToCompare = {
            vehicleId: updateData.vehicleId,
            destination: updateData.destination,
            startDatetime: updateData.startDatetime?.toISOString(),
            endDatetime: updateData.endDatetime?.toISOString(),
            passengers: updateData.passengers,
            purpose: updateData.purpose,
            driverType: updateData.driverType,
            driverEmployeeId: updateData.driverEmployeeId,
            driverUserId: updateData.driverUserId
        };

        const diff = calculateDiff(oldData, newDataToCompare);

        const prismaUpdateData = { ...updateData };
        console.log('[UPDATE BOOKING] Prisma Data:', JSON.stringify(prismaUpdateData, null, 2));
        
        if (updateData.endDatetime) {
            console.log('[VEHICLE-END-DATETIME] 3. ก่อนส่งเข้า Prisma (Update) - endDatetime:', updateData.endDatetime);
        }

        const updatedBooking = await prisma.$transaction(async (tx) => {
            if (updateData.startDatetime || updateData.endDatetime || updateData.vehicleId) {
                const checkStart = updateData.startDatetime || existingBooking.startDatetime;
                const checkEnd = updateData.endDatetime || existingBooking.endDatetime;
                const checkVehicle = updateData.vehicleId || existingBooking.vehicleId;

                const conflictingBooking = await tx.vehicleBooking.findFirst({
                    where: {
                        id: { not: bookingId },
                        vehicleId: checkVehicle,
                        status: {
                            in: [BookingStatus.PENDING, BookingStatus.APPROVED, BookingStatus.IN_USE]
                        },
                        startDatetime: { lt: new Date(checkEnd) },
                        endDatetime: { gt: new Date(checkStart) }
                    }
                });

                if (conflictingBooking) {
                    throw new Error('TIME_OVERLAP');
                }
            }

            const result = await tx.vehicleBooking.update({
                where: { id: bookingId },
                data: prismaUpdateData,
                include: {
                    vehicle: true,
                    driverEmployee: true,
                    user: { include: { employee: true } }
                }
            });

            if (Object.keys(diff.new).length > 0) {
                await recordAuditLog(tx, {
                    action: 'UPDATE_VEHICLE_BOOKING',
                    module: 'VEHICLE_BOOKING',
                    userId: currentUserId,
                    entityId: bookingId,
                    entityType: 'VEHICLE_BOOKING',
                    details: {
                        diff,
                        remark: 'แก้ไขข้อมูลการจองรถยนต์'
                    }
                });
            }

            return result;
        });

        console.log('[VEHICLE-END-DATETIME] 4. หลังบันทึกลง Database (Update) - endDatetime:', updatedBooking.endDatetime);

        return res.status(200).json({ success: true, data: updatedBooking, message: "อัปเดตข้อมูลการจองสำเร็จ" });
    } catch (error) {
        console.error("Update Booking Error:", error);
        if (error.message === 'TIME_OVERLAP') {
            return res.status(409).json({ success: false, error: "ไม่สามารถอัปเดตข้อมูลได้ เนื่องจากช่วงเวลาที่แก้ไขซ้อนทับกับการจองอื่น" });
        }
        return res.status(500).json({ success: false, error: "ไม่สามารถอัปเดตข้อมูลการจองได้" });
    }
};

exports.assignCompanyDriver = async (req, res) => {
    try {
        if (req.user?.role !== 'ADMIN') {
            return res.status(403).json({ success: false, error: 'เฉพาะผู้ดูแลระบบเท่านั้นที่สามารถจัดสรรพนักงานขับรถได้' });
        }

        const bookingId = parseInt(req.params.id, 10);
        const currentUserId = req.user?.id || req.user?.userId || req.user?.sub || req.user?.user_id;
        const { driverType, companyDriverId, driverEmployeeId, driverUserId, driverLicenseUrl } = req.body;

        if (isNaN(bookingId)) {
            return res.status(400).json({ success: false, error: "รหัสการจองไม่ถูกต้อง" });
        }

        const existingBooking = await prisma.vehicleBooking.findUnique({
            where: { id: bookingId }
        });

        if (!existingBooking) {
            return res.status(404).json({ success: false, error: "ไม่พบข้อมูลการจอง" });
        }

        if ([BookingStatus.COMPLETED, BookingStatus.CANCELLED, BookingStatus.REJECTED].includes(existingBooking.status)) {
            return res.status(400).json({ success: false, error: "ไม่สามารถจัดสรรคนขับให้รายการจองที่เสร็จสิ้น ยกเลิก หรือถูกปฏิเสธแล้วได้" });
        }

        const isCompanyDriver = driverType === 'COMPANY' || driverType === 'บริษัท' || driverType === 'พนักงานขับรถ' || (Boolean(companyDriverId) && companyDriverId !== 'null');
        const normalizedDriverType = isCompanyDriver ? 'COMPANY' : 'SELF_DRIVE';
        const parsedCompanyDriverId = (isCompanyDriver && companyDriverId && companyDriverId !== 'null' && !isNaN(parseInt(companyDriverId, 10))) ? parseInt(companyDriverId, 10) : null;
        
        const parsedDriverEmployeeId = (!isCompanyDriver && driverEmployeeId && !isNaN(parseInt(driverEmployeeId, 10))) ? parseInt(driverEmployeeId, 10) : (isCompanyDriver ? null : existingBooking.driverEmployeeId);
        const parsedDriverUserId = (!isCompanyDriver && driverUserId && !isNaN(parseInt(driverUserId, 10))) ? parseInt(driverUserId, 10) : (isCompanyDriver ? null : existingBooking.driverUserId);

        const targetDriverEmployeeId = isCompanyDriver ? parsedCompanyDriverId : parsedDriverEmployeeId;

        let driverEmp = null;
        if (targetDriverEmployeeId) {
            driverEmp = await prisma.employee.findUnique({
                where: { id: targetDriverEmployeeId }
            });
            if (!driverEmp) {
                return res.status(400).json({ success: false, error: "ไม่พบข้อมูลพนักงานขับรถในระบบ" });
            }

            if (driverEmp.driverLicenseExpiryDate && new Date(driverEmp.driverLicenseExpiryDate) < new Date()) {
                return res.status(400).json({ success: false, error: "ใบขับขี่ของพนักงานขับรถท่านนี้หมดอายุแล้ว ไม่สามารถจัดสรรได้" });
            }
        } else if (isCompanyDriver) {
            return res.status(400).json({ success: false, error: "กรุณาเลือกพนักงานขับรถของบริษัท" });
        }

        const requestFiles = req.files || (req.file ? [req.file] : null);
        const licenseFile = getUploadedFile(requestFiles, ['driverLicenseUrl', 'driverLicense', 'licenseImage', 'license', 'file', 'image', 'attachments']);
        
        const normalizeLicensePath = (filePath) => {
            if (!filePath) return null;
            const clean = String(filePath).replace(/\\/g, '/');
            const idx = clean.indexOf('attachments/');
            return idx !== -1 ? '/' + clean.substring(idx) : (clean.startsWith('/') ? clean : '/' + clean);
        };

        const rawLicenseBody = driverLicenseUrl || req.body.driverLicense || null;
        const finalDriverLicenseUrl = licenseFile 
            ? normalizeLicensePath(licenseFile.path) 
            : (rawLicenseBody && !rawLicenseBody.startsWith('data:image') 
                ? normalizeLicensePath(rawLicenseBody) 
                : (isCompanyDriver ? null : (driverEmp?.driverLicenseUrl || existingBooking.driverLicenseUrl)));

        const oldData = {
            driverType: existingBooking.driverType,
            driverEmployeeId: existingBooking.driverEmployeeId,
            driverUserId: existingBooking.driverUserId,
            driverLicenseUrl: existingBooking.driverLicenseUrl
        };

        const newDataToCompare = {
            driverType: normalizedDriverType,
            driverEmployeeId: targetDriverEmployeeId,
            driverUserId: isCompanyDriver ? null : parsedDriverUserId,
            driverLicenseUrl: isCompanyDriver ? null : finalDriverLicenseUrl
        };

        const diff = calculateDiff(oldData, newDataToCompare);

        const updatedBooking = await prisma.$transaction(async (tx) => {
            if (newDataToCompare.driverEmployeeId) {
                const conflictingDriver = await tx.vehicleBooking.findFirst({
                    where: {
                        id: { not: bookingId },
                        driverEmployeeId: newDataToCompare.driverEmployeeId,
                        status: { 
                            in: [BookingStatus.PENDING, BookingStatus.APPROVED, BookingStatus.IN_USE] 
                        },
                        startDatetime: { lt: existingBooking.endDatetime },
                        endDatetime: { gt: existingBooking.startDatetime }
                    }
                });
                if (conflictingDriver) throw new Error('DRIVER_OVERLAP');
            }

            const result = await tx.vehicleBooking.update({
                where: { id: bookingId },
                data: {
                    driverType: normalizedDriverType,
                    driverEmployeeId: targetDriverEmployeeId,
                    driverUserId: isCompanyDriver ? null : parsedDriverUserId,
                    driverLicenseUrl: newDataToCompare.driverLicenseUrl
                },
                include: {
                    driverEmployee: true,
                    vehicle: true,
                    user: { include: { employee: true } }
                }
            });

            if (Object.keys(diff.new).length > 0) {
                await recordAuditLog(tx, {
                    action: 'ASSIGN_DRIVER',
                    module: 'VEHICLE_BOOKING',
                    userId: currentUserId,
                    entityId: bookingId,
                    entityType: 'VEHICLE_BOOKING',
                    details: {
                        diff,
                        remark: 'จัดสรร/เปลี่ยนแปลงพนักงานขับรถ'
                    }
                });
            }

            return result;
        });

        return res.status(200).json({ success: true, data: updatedBooking, message: "จัดสรรคนขับสำเร็จ" });
    } catch (error) {
        console.error("Assign Driver Error:", error);
        if (error.message === 'DRIVER_OVERLAP') {
            return res.status(409).json({ success: false, error: "ไม่สามารถจัดสรรคนขับได้ เนื่องจากคนขับมีคิวงานซ้อนในช่วงเวลาดังกล่าว" });
        }
        return res.status(500).json({ success: false, error: "ไม่สามารถจัดสรรคนขับได้" });
    }
};

exports.assignDriver = exports.assignCompanyDriver;