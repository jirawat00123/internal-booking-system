const { PrismaClient, BookingStatus, VehicleStatus } = require('@prisma/client');
const prisma = new PrismaClient();
const notificationService = require('../services/notificationService'); // 🟢 1. นำเข้า notificationService

// =======================================================
// 1. สร้างรายการจองรถยนต์ (POST)
// =======================================================
exports.createBooking = async (req, res) => {
    try {
        const { vehicleId, destination, startDatetime, returnDate, endDatetime, passengerCount, passengers, driverType, userId, purpose } = req.body;
        const finalEndDate = endDatetime || returnDate;

        if (!vehicleId || !startDatetime || !finalEndDate) {
            return res.status(400).json({ success: false, error: "กรุณาส่งข้อมูลที่จำเป็นให้ครบถ้วน" });
        }

        const finalPassengers = parseInt(passengerCount || passengers) || 1;
        const finalUserId = parseInt(req.user?.userId || req.user?.id, 10);

        const reqStart = new Date(startDatetime);
        const reqEnd = new Date(finalEndDate);
        const now = new Date();

        if (reqStart < now) {
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

            const booking = await tx.vehicleBooking.create({
                data: {
                    vehicleId: parseInt(vehicleId),
                    userId: finalUserId, 
                    destination: destination || "-",
                    startDatetime: reqStart,
                    endDatetime: reqEnd,
                    passengers: finalPassengers, 
                    purpose: purpose || "ใช้งานบริษัท",
                    status: BookingStatus.PENDING
                },
                include: { vehicle: true }
            });

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

        return res.status(201).json({ success: true, data: newBooking, message: "บันทึกคำขอจองรถสำเร็จ รอการอนุมัติ" });

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
            const now = new Date();
            const effectiveStartDate = new Date(startDate) > now ? new Date(startDate) : now;

            whereClause.startDatetime = { lte: new Date(endDate) };
            whereClause.endDatetime = { gte: effectiveStartDate };

            if (status) {
                whereClause.status = status;
            } else {
                whereClause.status = {
                    notIn: [BookingStatus.COMPLETED, BookingStatus.CANCELLED, BookingStatus.EXPIRED, BookingStatus.REJECTED]
                };
            }
        } else if (status) {
            whereClause.status = status;
        }

        if (vehicleId) {
            whereClause.vehicleId = parseInt(vehicleId, 10);
        }

        const bookings = await prisma.vehicleBooking.findMany({
            where: whereClause,
            orderBy: { createdAt: 'desc' },
            include: {
                vehicle: true,
                user: { include: { employee: true } }
            }
        });

        const currentUserId = req.user ? parseInt(req.user?.userId || req.user?.id, 10) : null;
        const currentUserRole = req.user ? req.user.role : 'USER';
        
        const bookingsWithPermissions = bookings.map(booking => {
            const isOwner = currentUserId === booking.userId;
            const isAdmin = currentUserRole === 'ADMIN';
            const isPendingOrApproved = [BookingStatus.PENDING, BookingStatus.APPROVED].includes(booking.status);

            return {
                ...booking,
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
                data: { status: validStatus }
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
                    data: { isRead: true, status: 'read' }
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
        if (isNaN(bookingId)) {
            return res.status(400).json({ success: false, error: "รหัสการจองไม่ถูกต้อง" });
        }

        const { status, remark } = req.body;
        const validStatus = status ? BookingStatus[status.toUpperCase()] : BookingStatus.IN_USE;

        const bookingExists = await prisma.vehicleBooking.findUnique({
            where: { id: bookingId },
            include: { vehicle: true }
        });

        if (!bookingExists) {
            return res.status(404).json({ success: false, error: `ไม่พบรายการจองรหัส #${bookingId} ในระบบ` });
        }

        const now = new Date();
        if (now < bookingExists.startDatetime) {
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
                data: { status: validStatus }
            });

            await tx.vehicle.update({
                where: { id: bookingExists.vehicleId },
                data: { status: VehicleStatus.IN_USE }
            });

            const currentUserId = parseInt(req.user?.userId || req.user?.id, 10);

            await tx.vehicleLog.create({
                data: {
                    vehicleBookingId: bookingId,
                    checkoutTime: now,
                    checkoutMileage: bookingExists.vehicle.currentMileage || 0,
                    checkoutFuelLevel: 100,
                    checkoutById: currentUserId
                }
            });

            if (req.files && Object.keys(req.files).length > 0) {
                const imagesToSave = [];
                if (req.files['frontImage']) imagesToSave.push(req.files['frontImage'][0]);
                if (req.files['backImage']) imagesToSave.push(req.files['backImage'][0]);
                if (req.files['plateImage']) imagesToSave.push(req.files['plateImage'][0]);

                for (const file of imagesToSave) {
                    await tx.attachment.create({
                        data: {
                            entityType: "VEHICLE_RELEASE_IMAGE",
                            entityId: bookingId,
                            fileName: file.originalname,
                            filePath: file.path,
                            fileType: file.mimetype,
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
                            hasAttachments: req.files ? true : false,
                            remark: remark || "ทำการปล่อยรถออกและบันทึกภาพถ่าย"
                        })
                    }
                });
            }

            await tx.notification.updateMany({
                where: { entityType: 'VEHICLE_BOOKING', entityId: bookingId, isRead: false },
                data: { isRead: true, status: 'read' }
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
        if (error.message === 'PREVIOUS_BOOKING_ACTIVE') {
            return res.status(409).json({ success: false, code: "PREVIOUS_BOOKING_ACTIVE", error: "มีคิวก่อนหน้าที่ยังใช้งานรถอยู่" });
        }
        return res.status(500).json({ success: false, error: "เกิดข้อผิดพลาดในการบันทึกข้อมูลปล่อยรถ" });
    }
};

// =======================================================
// 5. เสร็จสิ้นการใช้งานรถ (PUT /:id/complete)
// =======================================================
exports.completeVehicleBooking = async (req, res) => {
    try {
        const bookingId = parseInt(req.params.id, 10);
        const reqUserId = parseInt(req.user?.userId || req.user?.id, 10);
        const userRole = req.user?.role;

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
        if (now < booking.endDatetime) {
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

        await prisma.$transaction(async (tx) => {
            await tx.vehicleBooking.update({
                where: { id: bookingId },
                data: { status: BookingStatus.COMPLETED } 
            });

            const latestLog = await tx.vehicleLog.findFirst({
                where: { vehicleBookingId: bookingId },
                orderBy: { createdAt: 'desc' }
            });

            if (latestLog) {
                await tx.vehicleLog.update({
                    where: { id: latestLog.id },
                    data: {
                        returnTime: new Date(),
                        returnById: reqUserId
                    }
                });
            }

            await tx.vehicle.update({
                where: { id: booking.vehicleId },
                data: { status: VehicleStatus.AVAILABLE } 
            });

            if (req.files && Object.keys(req.files).length > 0) {
                const imagesToSave = [];
                if (req.files['frontImage']) imagesToSave.push(req.files['frontImage'][0]);
                if (req.files['backImage']) imagesToSave.push(req.files['backImage'][0]);
                if (req.files['plateImage']) imagesToSave.push(req.files['plateImage'][0]);

                for (const file of imagesToSave) {
                    await tx.attachment.create({
                        data: {
                            entityType: "VEHICLE_RETURN_IMAGE",
                            entityId: bookingId,
                            fileName: file.originalname,
                            filePath: file.path,
                            fileType: file.mimetype,
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
                        hasAttachments: req.files ? true : false,
                        remark: "เสร็จสิ้นการใช้งานและคืนสถานะรถว่าง (รับรถเข้า)"
                    })
                }
            });

            await tx.notification.updateMany({
                where: { entityType: 'VEHICLE_BOOKING', entityId: bookingId, isRead: false },
                data: { isRead: true, status: 'read' }
            });
        });

        return res.status(200).json({
            success: true,
            message: "Vehicle booking completed successfully."
        });

    } catch (error) {
        console.error("Complete Booking Error:", error);
        return res.status(500).json({ success: false, message: "เกิดข้อผิดพลาดของระบบ" });
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
                data: { status: BookingStatus.APPROVED }
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
                data: { status: BookingStatus.REJECTED }
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

        const now = new Date();
        if (now >= booking.startDatetime) {
            return res.status(400).json({ success: false, error: "ถึงเวลารับรถตามปกติแล้ว ไม่จำเป็นต้องขอปลดล็อกก่อนเวลา" });
        }

        // ส่ง Notification หายูสเซอร์ผู้จอง
        await notificationService.createNotification({
            recipientId: booking.userId, // 🟢 แก้ไข: ใช้ recipientId แทน/เพิ่ม เพื่อให้ Map ID ผู้รับถูกต้อง
            userId: booking.userId,      // (คงไว้เผื่อ Service เดิมมี validation เช็คค่านี้ด้วย)
            title: "⚠️ คำขอรับรถก่อนเวลา",
            message: `เจ้าหน้าที่ขอคำยินยอมปล่อยรถยนต์ทะเบียน ${booking.vehicle.plateNumber} ก่อนเวลาจอง กรุณากดยืนยันหากท่านต้องการรับรถเลย`,
            type: 'EARLY_RELEASE_REQUEST', // 🟢 แก้ไข: ระบุ Type เฉพาะเจาะจง เพื่อให้ Mobile App ดักไปสร้าง Action ยืนยัน/ปฏิเสธ ได้
            entityType: 'VEHICLE_BOOKING',
            entityId: bookingId,
            status: 'unread' // 🟢 เพิ่ม status บังคับให้เป็น unread เสมอเมื่อสร้างใหม่
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
            data: { isRead: true, status: 'read' }
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

        // ส่ง Notification หายูสเซอร์ผู้จอง
        await notificationService.createNotification({
            recipientId: booking.userId,
            userId: booking.userId,
            title: "⚠️ คำขอคืนรถก่อนเวลา",
            message: `เจ้าหน้าที่ขอคำยินยอมรับคืนรถยนต์ทะเบียน ${booking.vehicle.plateNumber} ก่อนเวลาจอง กรุณากดยืนยันหากท่านคืนรถแล้ว`,
            type: 'EARLY_RETURN_REQUEST',
            entityType: 'VEHICLE_BOOKING',
            entityId: bookingId,
            status: 'unread'
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
            data: { isRead: true, status: 'read' }
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

        const now = new Date();
        const effectiveStartDate = new Date(startDate) > now ? new Date(startDate) : now;

        let whereClause = {
            startDatetime: { lte: new Date(endDate) },
            endDatetime: { gte: effectiveStartDate }
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
                vehicle: true,
                user: {
                    include: {
                        employee: {
                            include: { department: true }
                        }
                    }
                }
            },
            orderBy: { startDatetime: 'asc' }
        });

        return res.status(200).json({
            success: true,
            data: bookings
        });

    } catch (error) {
        console.error("Get Vehicle Calendar Error:", error);
        return res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลปฏิทินการจองรถยนต์ได้" });
    }
};

exports.getHistory = exports.getBookings;
exports.returnVehicle = exports.completeVehicleBooking;