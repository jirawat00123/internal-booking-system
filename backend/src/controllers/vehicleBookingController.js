const { PrismaClient, BookingStatus, VehicleStatus } = require('@prisma/client');
const prisma = new PrismaClient();
const notificationService = require('../services/notificationService');
const fs = require('fs');
const path = require('path');

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
        const { vehicleId, destination, startDatetime, returnDate, endDatetime, passengerCount, passengers, passengerNames, driverType, driverLicenseUrl, userId, purpose } = req.body;
        const finalEndDate = endDatetime || returnDate;

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

        if (!vehicleId || !startDatetime || !finalEndDate) {
            return res.status(400).json({ success: false, error: "กรุณาส่งข้อมูลที่จำเป็นให้ครบถ้วน" });
        }

        const finalPassengers = parseInt(passengerCount || passengers) || 1;
        const finalUserId = parseInt(req.user?.userId || req.user?.id || userId || req.body?.userId, 10);

        // --- เพิ่ม DEBUG LOG ตาม PHASE 3.1 ---
        console.log('[CREATE VEHICLE BOOKING] req.body:', JSON.stringify(req.body, null, 2));
        console.log('[PASSENGER INPUT] passengers:', passengers);
        console.log('[PASSENGER INPUT] passengerNames:', passengerNames);

        let parsedPassengerNames = [];
        
        // จัดการกรณี Flutter ส่งมาเป็น Array ตรงๆ, JSON String หรือ FormData Array (ดักจับ Key ที่เป็นไปได้ทั้งหมด)
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

        // กรณี Flutter ส่ง Array มาผ่าน FormData โดยระบุ Index (เช่น passengerNames[0], passengers[], ฯลฯ)
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

        // ดึงเฉพาะชื่อ กรณี Flutter ส่งมาเป็น Object { fullName: "..." }
        const cleanPassengerNames = parsedPassengerNames.map(name => {
            if (typeof name === 'object' && name !== null) {
                return String(name.fullName || name.name || '').trim();
            }
            return String(name).trim();
        }).filter(Boolean);

        console.log('[PASSENGER INPUT] cleanPassengerNames:', cleanPassengerNames);

        let validatedPassengersCount = finalPassengers;
        if (cleanPassengerNames.length > finalPassengers) {
            // ปรับจำนวนผู้โดยสารตามรายชื่อที่แนบมาจริง หากตัวเลขน้อยกว่า ป้องกันการเกิด Error 400
            validatedPassengersCount = cleanPassengerNames.length;
        }

        const reqStart = new Date(startDatetime);
        const reqEnd = new Date(finalEndDate);
        const nowBuffer = new Date(Date.now() - 5 * 60 * 1000);

        if (reqStart < nowBuffer) {
            return res.status(400).json({ success: false, error: "ไม่สามารถทำรายการจองรถยนต์ย้อนหลังได้ กรุณาเลือกเวลาที่เป็นปัจจุบันหรืออนาคต" });
        }

        if (reqStart >= reqEnd) {
            return res.status(400).json({ success: false, error: "เวลาสิ้นสุดการจองต้องอยู่หลังเวลาเริ่มต้นการจองเสมอ" });
        }

        const newBooking = await prisma.$transaction(async (tx) => {
            const conflictingBooking = await tx.vehicleBooking.findFirst({
                where: {
                    vehicleId: parseInt(vehicleId),
                    status: {
                        notIn: [BookingStatus.CANCELLED, BookingStatus.COMPLETED, BookingStatus.REJECTED] 
                    },
                    startDatetime: { lt: reqEnd },
                    endDatetime: { gt: reqStart }
                }
            });

            if (conflictingBooking) {
                throw new Error('TIME_OVERLAP');
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
                    driverType: driverType || "ขับขี่เอง",
                    driverLicenseUrl: finalDriverLicenseUrl,
                    status: BookingStatus.PENDING,
                    passengerDetails: cleanPassengerNames.length > 0 ? {
                        create: cleanPassengerNames.map(name => ({ fullName: name }))
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
                    attachments: true,
                    passengerDetails: true
                }
            });

            const targetRawLicense = req.body.driverLicenseUrl || req.body.driverLicense || driverLicenseUrl;
            let licenseBuffer = null;
            let tempSourcePath = null;
            let fileExt = '.png';

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
                        attachments: true,
                        passengerDetails: true
                    }
                });
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
        const formattedNewBooking = {
            ...newBooking,
            userName: newBooking.user?.employee?.fullName || newBooking.user?.username || '-',
            passengerNames: newBooking.passengerDetails?.map(p => p.fullName) || cleanPassengerNames,
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

        const currentUserId = parseInt(req.user?.userId || req.user?.id, 10);

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

        const updatedBooking = await prisma.$transaction(async (tx) => {
            if (validStatus === BookingStatus.APPROVED) {
                const conflictingBooking = await tx.vehicleBooking.findFirst({
                    where: {
                        id: { not: bookingId },
                        vehicleId: existingBooking.vehicleId,
                        status: {
                            notIn: [
                                BookingStatus.CANCELLED,
                                BookingStatus.COMPLETED,
                                BookingStatus.REJECTED
                            ]
                        },
                        startDatetime: { lt: existingBooking.endDatetime },
                        endDatetime: { gt: existingBooking.startDatetime }
                    }
                });

                if (conflictingBooking) {
                    throw new Error('TIME_OVERLAP');
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

            if (!isNaN(currentUserId)) {
                const auditAction = validStatus === BookingStatus.APPROVED ? "APPROVE_VEHICLE_BOOKING" : 
                                   (validStatus === BookingStatus.COMPLETED ? "COMPLETED_VEHICLE_BOOKING" : "UPDATE_VEHICLE_BOOKING");

                await tx.auditLog.create({
                    data: {
                        action: auditAction,
                        module: 'VEHICLE_BOOKING',
                        userId: currentUserId,
                        entityId: bookingId,
                        entityType: 'VEHICLE_BOOKING',
                        details: JSON.stringify({
                            oldStatus: existingBooking.status,
                            newStatus: validStatus,
                            remark: remark || `อัปเดตสถานะรถยนต์เป็น ${validStatus}`
                        })
                    }
                });
            }

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

        res.status(500).json({ success: false, error: "ไม่สามารถอัปเดตสถานะได้" });
    }
};

// =======================================================
// 4. บันทึกการปล่อยรถออก (PUT /:id/release) - ย้ายทุกอย่างเข้า Transaction 🟢
// =======================================================
exports.releaseVehicle = async (req, res) => {
    try {
        const bookingId = parseInt(req.params.id, 10);
        const currentUserId = parseInt(req.user?.userId || req.user?.id, 10);

        if (isNaN(bookingId)) {
            return res.status(400).json({ success: false, error: "รหัสการจองไม่ถูกต้อง" });
        }
        if (isNaN(currentUserId)) {
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

        if (bookingExists.status === BookingStatus.IN_USE) {
            return res.status(409).json({ success: false, code: "ALREADY_IN_USE", error: "รายการจองนี้ได้ทำการปล่อยรถไปแล้ว" });
        }

        if ([BookingStatus.CANCELLED, BookingStatus.COMPLETED, BookingStatus.REJECTED].includes(bookingExists.status)) {
            return res.status(409).json({ success: false, code: "INVALID_STATUS", error: "รายการจองนี้อยู่ในสถานะที่ไม่สามารถปล่อยรถได้" });
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

        const parsedMileage = parseFloat(checkoutMileage || mileage);
        const finalMileage = !isNaN(parsedMileage) ? parsedMileage : (bookingExists.vehicle.currentMileage || 0);
        const parsedFuel = parseFloat(checkoutFuelLevel || fuelLevel);
        const finalFuelLevel = !isNaN(parsedFuel) ? parsedFuel : 100;

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

            // 🟢 1. สร้าง โฟลเดอร์ปลายทาง NAS / Inspections Target และคัดลอกย้ายไฟล์เข้ามาให้เรียบร้อย
            const baseUploadDir = process.env.UPLOAD_DIR || path.join(__dirname, '../../attachments');
            const releaseDir = path.join(baseUploadDir, 'vehicles', 'inspections', String(bookingId), 'release');
            if (!fs.existsSync(releaseDir)) {
                fs.mkdirSync(releaseDir, { recursive: true, mode: 0o777 });
            }

            const moveFileToNAS = (file) => {
                if (!file) return;
                const filename = file.filename || (file.path ? path.basename(file.path) : null) || file.originalname || `${Date.now()}-${Math.round(Math.random() * 1e9)}.jpg`;
                const destPath = path.join(releaseDir, filename);

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
            [frontFile, backFile, mileageFile].forEach(moveFileToNAS);

            const normalizePath = (filePath) => {
                if (!filePath) return null;
                const clean = filePath.replace(/\\/g, '/');
                const idx = clean.indexOf('attachments/');
                return idx !== -1 ? '/' + clean.substring(idx) : (clean.startsWith('/') ? clean : '/' + clean);
            };

            const currentUploadedNames = [frontFile, backFile, mileageFile].filter(Boolean).map(f => f.filename);

            if (fs.existsSync(releaseDir) && currentUploadedNames.length > 0) {
                const files = fs.readdirSync(releaseDir);
                for (const file of files) {
                    if (!currentUploadedNames.includes(file)) {
                        try { fs.unlinkSync(path.join(releaseDir, file)); } catch (e) {}
                    }
                }
            }

            // 🟢 2. เช็ก Log ว่ามีอยู่แล้วหรือไม่ แทนการใช้ upsert ที่ต้องพึ่งพา Unique Field
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

            let imagesToSave = [frontFile, backFile, mileageFile].filter(Boolean);
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
                            entityType: "VEHICLE_RELEASE_IMAGE",
                            entityId: bookingId,
                            fileName: file.originalname || file.filename || `release_${Date.now()}.jpg`,
                            filePath: file.relativePath,
                            fileType: file.mimetype || 'image/jpeg',
                            uploadedBy: { connect: { id: currentUserId } },
                            bookingVehicle: { connect: { id: bookingId } }
                        }
                    });
                }
            }

            if (!isNaN(currentUserId)) {
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
            }

            await tx.notification.updateMany({
                where: { entityType: 'VEHICLE_BOOKING', entityId: bookingId, isRead: false },
                data: { isRead: true }
            });

            return updatedBooking;
        });

        return res.status(200).json({
            success: true,
            message: "อัปเดตการปล่อยรถและบันทึกรูปภาพสำเร็จ",
            data: updatedData
        });

    } catch (error) {
        console.error("Release Vehicle Error:", error);
        
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

        if (userRole !== 'ADMIN' && userRole !== 'GUARD' && userRole !== 'SECURITY' && booking.userId !== reqUserId) {
            return res.status(403).json({ success: false, message: "คุณไม่มีสิทธิ์ทำรายการนี้" });
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
                        notIn: [
                            BookingStatus.CANCELLED,
                            BookingStatus.COMPLETED,
                            BookingStatus.REJECTED
                        ]
                    },
                    startDatetime: { lt: booking.endDatetime },
                    endDatetime: { gt: booking.startDatetime }
                }
            });

            if (conflictingBooking) {
                throw new Error('TIME_OVERLAP');
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

        // 🟢 ยกเลิกการบังคับใช้ new Date() เป็นจุดเริ่มต้น เพื่อให้ปฏิทินแสดงรายการที่ผ่านมาแล้วได้ครบถ้วน
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
                attachments: true,
                passengerDetails: true
            },
            orderBy: { startDatetime: 'asc' }
        });

        // 🟢 Map สถานะ APPROVED เป็น RESERVED และแนบข้อมูลไฟล์ พ.ร.บ. ก่อนส่งไปหน้า Calendar
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

            return {
                ...booking,
                userName: booking.user?.employee?.fullName || booking.user?.username || '-',
                passengerNames: extractedPassengerNames.length > 0 ? extractedPassengerNames : (booking.passengerNames || []),
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