const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// =======================================================
// 1. สร้างรายการจองรถยนต์ (POST)
// =======================================================
exports.createBooking = async (req, res) => {
    try {
        // 💡 1. ดักรับตัวแปรเผื่อไว้หลายๆ ชื่อ (เพิ่ม passengers และ userId)
        const { vehicleId, destination, startDatetime, endDatetime, passengerCount, passengers, driverType, userId, purpose } = req.body;

        if (!vehicleId || !startDatetime || !endDatetime) {
            return res.status(400).json({ success: false, error: "กรุณาส่งข้อมูลที่จำเป็นให้ครบถ้วน" });
        }

        // 💡 2. เช็กจำนวนคน (รับทั้ง passengerCount หรือ passengers ถ้าไม่ส่งมาจะให้เป็น 1)
        const finalPassengers = parseInt(passengerCount || passengers) || 1;

        // 💡 3. เช็กคนจอง (ถ้าหน้าแอป Flutter ส่ง userId มาให้เซฟคนนั้น แต่ภาพรวมถ้าไม่ส่ง ให้ใช้คน Login)
        const finalUserId = userId ? parseInt(userId) : req.user.userId; 

        const reqStart = new Date(startDatetime);
        const reqEnd = new Date(endDatetime);
        const now = new Date();

        // 🚨 [Validation 1] ตรวจสอบการจองย้อนหลัง (ห้ามจองช่วงเวลาในอดีต)
        if (reqStart < now) {
            return res.status(400).json({ success: false, error: "ไม่สามารถทำรายการจองรถยนต์ย้อนหลังได้ กรุณาเลือกเวลาที่เป็นปัจจุบันหรืออนาคต" });
        }

        // 🚨 [Validation 2] ตรวจสอบความสมเหตุสมผลของช่วงเวลา
        if (reqStart >= reqEnd) {
            return res.status(400).json({ success: false, error: "เวลาสิ้นสุดการจอง (endDatetime) ต้องอยู่หลังเวลาเริ่มต้นการจองเสมอ" });
        }

        // ทำงานภายใต้ Prisma Transaction เพื่อความปลอดภัยและป้องกันสภาวะ Race Condition 
        const newBooking = await prisma.$transaction(async (tx) => {
            
            // 🚨 [Validation 3] คำนวณหาช่วงเวลาทับซ้อนกัน (Overlapping Check) ด้วยสมการสากล
            const conflictingBooking = await tx.vehicleBooking.findFirst({
                where: {
                    vehicleId: parseInt(vehicleId),
                    status: {
                        notIn: ['Cancelled', 'Completed', 'Rejected'] // ละเว้นใบจองที่ถูกยกเลิกไปแล้วเพื่อคืนสิทธิ์เวลาให้กับระบบ
                    },
                    startDatetime: { lt: reqEnd },
                    endDatetime: { gt: reqStart }
                }
            });

            if (conflictingBooking) {
                throw new Error('TIME_OVERLAP');
            }

            // ตรวจสอบความถูกต้องและสถานะของตัวรถยนต์ในระบบจริง
            const vehicle = await tx.vehicle.findUnique({
                where: { id: parseInt(vehicleId) }
            });

            if (!vehicle || vehicle.isDeleted) {
                throw new Error('VEHICLE_NOT_FOUND');
            }

            // 🚨 [Validation 4] ปรับปรุงการล็อกสถานะรถยนต์ทันทีกดจอง (Immediate Vehicle Lock)
            if (vehicle.status !== 'AVAILABLE') {
                throw new Error('VEHICLE_NOT_AVAILABLE');
            }
            
            // สั่งอัปเดตสถานะของตัวรถยนต์จาก AVAILABLE -> RESERVED ทันที
            await tx.vehicle.update({
                where: { id: vehicle.id },
                data: { status: 'RESERVED' }
            });

            // บันทึกสร้างเอกสารใบจองรถยนต์ลงตารางหลักตามกลไกเดิม
            return await tx.vehicleBooking.create({
                data: {
                    vehicleId: parseInt(vehicleId),
                    userId: finalUserId, 
                    destination: destination || "-",
                    startDatetime: reqStart,
                    endDatetime: reqEnd,
                    passengers: finalPassengers, 
                    purpose: purpose || "ใช้งานบริษัท",
                    status: "Pending" 
                }
            });
        });

        // 🟢 บันทึก AuditLog เมื่อสร้างรายการจองรถสำเร็จ
        const actionUserId = req.user?.userId ? parseInt(req.user.userId, 10) : finalUserId;
if (actionUserId) {
            await prisma.auditLog.create({
                data: {
                    action: "CREATE_VEHICLE_BOOKING",
                    module: "VEHICLE_BOOKING",
                    entityId: newBooking.id,
                    entityType: "VEHICLE_BOOKING",
                    userId: actionUserId,
                    details: `User ${actionUserId} created vehicle booking ID ${newBooking.id} for vehicle ID ${vehicleId}`
                }
            }).catch(err => console.error("AuditLog Error [CREATE_VEHICLE_BOOKING]:", err.message));
        }

        return res.status(201).json({ success: true, data: newBooking, message: "จองรถสำเร็จและบันทึกคิวเรียบร้อย" });

    } catch (error) {
        console.error("Create Vehicle Booking Error:", error);
        if (error.message === 'TIME_OVERLAP') {
            return res.status(400).json({ success: false, error: "รถคันนี้ถูกจับจองไปแล้วในช่วงเวลาดังกล่าว กรุณาเปลี่ยนช่วงเวลาหรือเลือกเปลี่ยนรถคันใหม่" });
        }
        if (error.message === 'VEHICLE_NOT_FOUND') {
            return res.status(404).json({ success: false, error: "ไม่พบข้อมูลยานพาหนะคันนี้ในระบบ" });
        }
        if (error.message === 'VEHICLE_NOT_AVAILABLE') {
            return res.status(400).json({ success: false, error: "ยานพาหนะนี้ไม่พร้อมใช้งานเนื่องจากติดคิวบริการอื่นในขณะนี้" });
        }
        return res.status(500).json({ success: false, error: "ไม่สามารถดำเนินการสร้างรายการจองรถยนต์ได้" });
    }
};

// =======================================================
// 2. ดึงประวัติการจองทั้งหมด (GET)
// =======================================================
exports.getBookings = async (req, res) => {
    try {
        const bookings = await prisma.vehicleBooking.findMany({
            orderBy: { createdAt: 'desc' },
            include: {
                vehicle: true,
                user: {
                    include: {
                        employee: true
                    }
                }
            }
        });

        res.status(200).json({ success: true, data: bookings });
    } catch (error) {
        console.error("Get Vehicle Bookings Error:", error);
        res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลประวัติการจองได้" });
    }
};

// =======================================================
// 3. อัปเดตสถานะการจอง (PUT) - ใช้สำหรับยกเลิกคิว / คืนรถ
// =======================================================
exports.updateBookingStatus = async (req, res) => {
    try {
        const bookingId = parseInt(req.params.id);
        const { status } = req.body;

        if (isNaN(bookingId) || !status) {
            return res.status(400).json({ success: false, error: "ข้อมูลไม่ถูกต้อง" });
        }

        const existingBooking = await prisma.vehicleBooking.findUnique({
            where: { id: bookingId }
        });

        if (!existingBooking) {
            return res.status(404).json({ success: false, error: "ไม่พบข้อมูลการจองนี้" });
        }

        // 🛡️ ตรวจสอบสิทธิ์ (Authorization & IDOR Check)
        if (req.user.role === 'ADMIN') {
            // อนุญาต: ADMIN ทำได้ทุกอย่าง
        } else if (req.user.role === 'USER' && existingBooking.userId === parseInt(req.user.userId, 10)) {
            // อนุญาต: USER แก้ไขได้เฉพาะรายการที่ตัวเองเป็นเจ้าของเท่านั้น
        } else {
            return res.status(403).json({ 
                success: false, 
                error: 'คุณไม่มีสิทธิ์แก้ไขหรือยกเลิกการจองของผู้อื่น' 
            });
        }

        let dbStatus = status;
        if (status === 'ยกเลิกแล้ว') dbStatus = 'Cancelled';
        if (status === 'เสร็จสิ้น') dbStatus = 'Completed';
        if (status === 'กำลังใช้งาน') dbStatus = 'In_Use';
        if (status === 'รออนุมัติ') dbStatus = 'Pending';
        if (status === 'อนุมัติแล้ว') dbStatus = 'Approved';

        const updatedBooking = await prisma.vehicleBooking.update({
            where: { id: bookingId },
            data: { status: dbStatus }
        });

        // 🟢 บันทึก AuditLog เมื่ออัปเดตสถานะการจองรถสำเร็จ
        const actionUserId = req.user?.userId ? parseInt(req.user.userId, 10) : null;
        if (actionUserId) {
            await prisma.auditLog.create({
                data: {
                    action: 'UPDATE_VEHICLE_BOOKING_STATUS',
                    module: 'VEHICLE_BOOKING',
                    userId: actionUserId,
                    entityId: bookingId,
                    entityType: 'VEHICLE_BOOKING',
                    details: `User ${actionUserId} updated vehicle booking ID ${bookingId} status to ${dbStatus}`
                }
            }).catch(err => console.error("AuditLog Error [updateBookingStatus]:", err.message));
        }

        res.status(200).json({ success: true, data: updatedBooking, message: "อัปเดตสถานะสำเร็จ" });
    } catch (error) {
        console.error("Update Booking Status Error:", error);
        res.status(500).json({ success: false, error: "ไม่สามารถอัปเดตสถานะได้" });
    }
};

// =======================================================
// 4. บันทึกการปล่อยรถออก (PUT /:id/release) - รับรูปถ่ายหน้ารถและป้ายทะเบียน
// =======================================================
exports.releaseVehicle = async (req, res) => {
    console.log("\n===== [3] Entering Controller: releaseVehicle =====");
    try {
        const bookingId = parseInt(req.params.id, 10);
        console.log(`===== [4] After Validation: bookingId = ${bookingId} =====`);
        
        if (isNaN(bookingId)) {
            console.log("===== [STOP] Invalid bookingId =====");
            return res.status(400).json({ success: false, error: "รหัสการจองไม่ถูกต้อง" });
        }

        const { status, parkingSlot } = req.body;
        console.log(`===== [4.1] Request Body Status: ${status} =====`);

        console.log("===== [5] Prisma Query: findUnique Booking =====");
        const bookingExists = await prisma.vehicleBooking.findUnique({
            where: { id: bookingId }
        });

        if (!bookingExists) {
            console.log("===== [STOP] Booking Not Found in DB =====");
            return res.status(404).json({ success: false, error: `ไม่พบรายการจองรหัส #${bookingId} ในระบบ` });
        }

        console.log("===== [6] Booking Found, Proceeding to Update =====");
        const updatedBooking = await prisma.vehicleBooking.update({
            where: { id: bookingId },
            data: { 
                status: status || 'In_Use'
            }
        });
        console.log("===== [7] Prisma Update: Booking Status Updated =====");

        console.log("===== [8] Checking req.files for Attachments =====");
        if (req.files && Object.keys(req.files).length > 0) {
            console.log(`===== [8.1] Files Detected: ${Object.keys(req.files).join(', ')} =====`);
            const imagesToSave = [];
            if (req.files['frontImage']) imagesToSave.push(req.files['frontImage'][0]);
            if (req.files['plateImage']) imagesToSave.push(req.files['plateImage'][0]);

            for (const file of imagesToSave) {
                console.log(`===== [8.2] Prisma Create: Saving Attachment ${file.originalname} =====`);
                await prisma.attachment.create({
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
            console.log("===== [8.3] All Attachments Saved Successfully =====");
        } else {
            console.log("===== [8.1] No Files Attached. Skipping Attachment Creation =====");
        }

        // 🟢 บันทึก AuditLog เมื่อปล่อยรถสำเร็จ
        const actionUserId = req.user?.userId ? parseInt(req.user.userId, 10) : null;
        if (actionUserId) {
            await prisma.auditLog.create({
                data: {
                    action: 'RELEASE_VEHICLE',
                    module: 'VEHICLE_BOOKING',
                    userId: actionUserId,
                    entityId: bookingId,
                    entityType: 'VEHICLE_BOOKING',
                    details: `User ${actionUserId} released vehicle for booking ID ${bookingId}`
                }
            }).catch(err => console.error("AuditLog Error [releaseVehicle]:", err.message));
        }

        console.log("===== [9] Commit Success: Sending Response =====");
        return res.status(200).json({
            success: true,
            message: "อัปเดตการปล่อยรถและบันทึกรูปภาพสำเร็จ",
            data: updatedBooking
        });

    } catch (error) {
        console.error("===== [ERROR] 🔴 Controller Crashed =====", error);
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
            // 1. อัปเดตสถานะใบจอง
            await tx.vehicleBooking.update({
                where: { id: bookingId },
                data: { status: 'Completed' }
            });

            // 2. คืนสถานะรถยนต์
            await tx.vehicle.update({
                where: { id: booking.vehicleId },
                data: { status: 'AVAILABLE' }
            });

            // 3. บันทึก Audit Log ตรงตาม Schema ใหม่
            await tx.auditLog.create({
                data: {
                    action: 'COMPLETE_VEHICLE_BOOKING',
                    module: 'VEHICLE_BOOKING',
                    entityId: bookingId,
                    entityType: 'VEHICLE_BOOKING',
                    userId: reqUserId,
                    details: `User ${reqUserId} completed vehicle booking ${bookingId} and released vehicle ${booking.vehicleId}`
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

exports.getHistory = exports.getBookings;