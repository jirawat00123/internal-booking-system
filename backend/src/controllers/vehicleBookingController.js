const { PrismaClient, BookingStatus, VehicleStatus } = require('@prisma/client');
const prisma = new PrismaClient();
const notificationService = require('../services/notificationService'); // 🟢 1. นำเข้า notificationService

// =======================================================
// 1. สร้างรายการจองรถยนต์ (POST)
// =======================================================
exports.createBooking = async (req, res) => {
    try {
        const { vehicleId, destination, startDatetime, endDatetime, passengerCount, passengers, driverType, userId, purpose } = req.body;

        if (!vehicleId || !startDatetime || !endDatetime) {
            return res.status(400).json({ success: false, error: "กรุณาส่งข้อมูลที่จำเป็นให้ครบถ้วน" });
        }

        const finalPassengers = parseInt(passengerCount || passengers) || 1;
        const finalUserId = userId ? parseInt(userId) : req.user.userId; 

        const reqStart = new Date(startDatetime);
        const reqEnd = new Date(endDatetime);
        const now = new Date();

        if (reqStart < now) {
            return res.status(400).json({ success: false, error: "ไม่สามารถทำรายการจองรถยนต์ย้อนหลังได้ กรุณาเลือกเวลาที่เป็นปัจจุบันหรืออนาคต" });
        }

        if (reqStart >= reqEnd) {
            return res.status(400).json({ success: false, error: "เวลาสิ้นสุดการจอง (endDatetime) ต้องอยู่หลังเวลาเริ่มต้นการจองเสมอ" });
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

            await tx.vehicle.update({
                where: { id: parseInt(vehicleId) },
                data: { status: VehicleStatus.RESERVED } 
            });

            const booking = await tx.vehicleBooking.create({
                data: {
                    vehicleId: parseInt(vehicleId),
                    userId: finalUserId, 
                    destination: destination || "-",
                    startDatetime: reqStart,
                    endDatetime: reqEnd,
                    passengers: finalPassengers, 
                    purpose: purpose || "ใช้งานบริษัท",
                    status: BookingStatus.PENDING // 🟢 เปลี่ยนจาก RESERVED เป็น PENDING รออนุมัติ
                },
                include: { vehicle: true } // ดึงข้อมูลรถมาเพื่อใช้ในการแจ้งเตือน
            });

            // 🟢 ย้าย AuditLog เข้ามาใน Transaction + จัดฟอร์แมต JSON
            const actionUserId = req.user?.userId ? parseInt(req.user.userId, 10) : finalUserId;
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

        // 🔔 2. แจ้งเตือน Admin ว่ามีรายการขอจองรถยนต์ใหม่
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
        const bookings = await prisma.vehicleBooking.findMany({
            orderBy: { createdAt: 'desc' },
            include: {
                vehicle: true,
                user: { include: { employee: true } }
            }
        });

        // 🟢 แปลงข้อมูลและแนบสิทธิ์ (Permissions) กลับไปให้ Frontend อัตโนมัติ
        const currentUserId = req.user ? parseInt(req.user.userId, 10) : null;
        const currentUserRole = req.user ? req.user.role : 'USER';
        
        const bookingsWithPermissions = bookings.map(booking => {
            const isOwner = currentUserId === booking.userId;
            const isAdmin = currentUserRole === 'ADMIN';
            const isPendingOrApproved = [BookingStatus.RESERVED, BookingStatus.PENDING, BookingStatus.APPROVED].includes(booking.status);

            return {
                ...booking,
                permissions: {
                    canCancel: (isOwner || isAdmin) && isPendingOrApproved,
                    canEdit: (isOwner || isAdmin) && booking.status === BookingStatus.PENDING, // แก้เป็น PENDING ตาม Workflow
                    canApprove: isAdmin && booking.status === BookingStatus.PENDING // เพิ่มสิทธิ์อนุมัติ
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

        if (req.user.role === 'ADMIN') {
            // อนุญาต
        } else if (req.user.role === 'USER' && existingBooking.userId === parseInt(req.user.userId, 10)) {
            // อนุญาต
        } else {
            return res.status(403).json({ success: false, error: 'คุณไม่มีสิทธิ์แก้ไขหรือยกเลิกการจองของผู้อื่น' });
        }

        const validStatus = BookingStatus[status?.toUpperCase()];
        if (!validStatus) {
            return res.status(400).json({ success: false, message: 'สถานะไม่ถูกต้องตามระบบ' });
        }

        const updatedBooking = await prisma.$transaction(async (tx) => {
            const booking = await tx.vehicleBooking.update({
                where: { id: bookingId },
                data: { status: validStatus }
            });

            // อัปเดตสถานะของตัวรถให้สอดคล้องกับสถานะการจอง
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
            } else if (validStatus === BookingStatus.APPROVED || validStatus === BookingStatus.RESERVED) {
                await tx.vehicle.update({
                    where: { id: existingBooking.vehicleId },
                    data: { status: VehicleStatus.RESERVED }
                });
            }

            // 🟢 AuditLog เป็น JSON
            const actionUserId = req.user?.userId ? parseInt(req.user.userId, 10) : null;
            if (actionUserId) {
                const auditAction = validStatus === BookingStatus.APPROVED ? "APPROVE_VEHICLE_BOOKING" : 
                                   (validStatus === BookingStatus.COMPLETED ? "COMPLETED_VEHICLE_BOOKING" : "UPDATE_VEHICLE_BOOKING");

                await tx.auditLog.create({
                    data: {
                        action: auditAction,
                        module: 'VEHICLE_BOOKING',
                        userId: actionUserId,
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
            return booking;
        });

        res.status(200).json({ success: true, data: updatedBooking, message: "อัปเดตสถานะสำเร็จ" });
    } catch (error) {
        console.error("Update Booking Status Error:", error);
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
            where: { id: bookingId }
        });

        if (!bookingExists) {
            return res.status(404).json({ success: false, error: `ไม่พบรายการจองรหัส #${bookingId} ในระบบ` });
        }

        // 🟢 มัดรวม Update Booking, Upload Image, Vehicle Status และ AuditLog เข้าด้วยกัน
        const updatedData = await prisma.$transaction(async (tx) => {
            const updatedBooking = await tx.vehicleBooking.update({
                where: { id: bookingId },
                data: { status: validStatus }
            });

            // อัปเดตสถานะในตาราง Vehicle เป็น IN_USE (กำลังใช้งาน)
            await tx.vehicle.update({
                where: { id: bookingExists.vehicleId },
                data: { status: VehicleStatus.IN_USE }
            });

if (req.files && Object.keys(req.files).length > 0) {
                const imagesToSave = [];
                if (req.files['frontImage']) imagesToSave.push(req.files['frontImage'][0]);
                if (req.files['backImage']) imagesToSave.push(req.files['backImage'][0]); // 👈 เพิ่มบรรทัดนี้สำหรับรูปหลังรถ
                if (req.files['plateImage']) imagesToSave.push(req.files['plateImage'][0]);

                for (const file of imagesToSave) {
                    await tx.attachment.create({
                        data: {
                            entityType: "VEHICLE_RELEASE_IMAGE",
                            entityId: bookingId,
                            fileName: file.originalname,
                            filePath: file.path,
                            fileType: file.mimetype,
                            uploadedBy: { connect: { id: parseInt(req.user.userId, 10) } },
                            bookingVehicle: { connect: { id: bookingId } }
                        }
                    });
                }
            }

            const actionUserId = req.user?.userId ? parseInt(req.user.userId, 10) : null;
            if (actionUserId) {
                await tx.auditLog.create({
                    data: {
                        action: 'RELEASE_VEHICLE',
                        module: 'VEHICLE_BOOKING',
                        userId: actionUserId,
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

            return updatedBooking;
        });

        return res.status(200).json({
            success: true,
            message: "อัปเดตการปล่อยรถและบันทึกรูปภาพสำเร็จ",
            data: updatedData
        });

    } catch (error) {
        console.error("Release Vehicle Error:", error);
        return res.status(500).json({ success: false, error: "เกิดข้อผิดพลาดในการบันทึกข้อมูลปล่อยรถ" });
    }
};

// =======================================================
// 5. เสร็จสิ้นการใช้งานรถ (PUT /:id/complete)
// =======================================================
exports.completeVehicleBooking = async (req, res) => {
    try {
        const bookingId = parseInt(req.params.id, 10);
        const reqUserId = parseInt(req.user.userId, 10);
        const userRole = req.user.role;

        const booking = await prisma.vehicleBooking.findUnique({
            where: { id: bookingId }
        });

        if (!booking) {
            return res.status(404).json({ success: false, message: "ไม่พบรายการจอง" });
        }

        if (userRole !== 'ADMIN' && booking.userId !== reqUserId) {
            return res.status(403).json({ success: false, message: "คุณไม่มีสิทธิ์ทำรายการนี้" });
        }

        await prisma.$transaction(async (tx) => {
            await tx.vehicleBooking.update({
                where: { id: bookingId },
                data: { status: BookingStatus.COMPLETED } 
            });

            await tx.vehicle.update({
                where: { id: booking.vehicleId },
                data: { status: VehicleStatus.AVAILABLE } 
            });

            // 🟢 AuditLog เป็น JSON
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
                        remark: "เสร็จสิ้นการใช้งานและคืนสถานะรถว่าง"
                    })
                }
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
        const adminId = parseInt(req.user.userId, 10);

        const booking = await prisma.vehicleBooking.findUnique({ where: { id: bookingId } });
        if (!booking) return res.status(404).json({ success: false, error: "ไม่พบการจอง" });

        const updatedBooking = await prisma.$transaction(async (tx) => {
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
        return res.status(500).json({ success: false, error: "ไม่สามารถอนุมัติได้" });
    }
};

// =======================================================
// 🟢 7. ปฏิเสธการจองรถยนต์ (POST /:id/reject)
// =======================================================
exports.rejectVehicleBooking = async (req, res) => {
    try {
        const bookingId = parseInt(req.params.id, 10);
        const adminId = parseInt(req.user.userId, 10);
        const { remark } = req.body;

        const booking = await prisma.vehicleBooking.findUnique({ where: { id: bookingId } });
        if (!booking) return res.status(404).json({ success: false, error: "ไม่พบการจอง" });

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

exports.getHistory = exports.getBookings;