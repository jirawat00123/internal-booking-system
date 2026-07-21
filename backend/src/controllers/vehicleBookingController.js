const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();


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

            // 🚨 [Validation 4] จัดการสถานะตัวรถแบบ Dynamic (Dynamic Vehicle Status Toggle)
            // หากการจองนี้ระบุให้เริ่มต้นใช้งานทันที (กำหนด Buffer ไว้เผื่อเวลาเลื่อนในแอปหน้าบ้าน 15 นาที)
            // ระบบจะทำการเปลี่ยนสถานะรถคันนี้เป็น RESERVED ทันทีเพื่อให้ไปแสดงผลที่หน้าป้อมยามของ SECURITY

            // 🚨 [Validation 4] ปรับปรุงการล็อกสถานะรถยนต์ทันทีกดจอง (Immediate Vehicle Lock)
            // ตรวจสอบว่ารถคันนี้ต้องอยู่ในสถานะ AVAILABLE ณ วินาทีที่กดจอง
            if (vehicle.status !== 'AVAILABLE') {
                throw new Error('VEHICLE_NOT_AVAILABLE');
            }
            
            // สั่งอัปเดตสถานะของตัวรถยนต์จาก AVAILABLE -> RESERVED ทันที ไม่ว่าจะจองช่วงเวลาใดก็ตาม
            // เพื่อให้หน้าจัดการรถของแอดมิน และหน้าจองธรรมดา ซิงค์สถานะตรงกันว่ารถคันนี้ติดคิวจองแล้ว
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
                vehicle: true, // 💡 ดึงข้อมูลรถพ่วงมาด้วย
                user: {
                    include: {
                        employee: true // 💡 ดึงข้อมูล employee เพื่อเอาชื่อผู้ทำรายการไปโชว์
                    }
                }
            }
        });

        // 💡 ส่งข้อมูลกลับไปให้ Flutter ในก้อน 'data'
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
        const { status } = req.body; // รับสถานะภาษาไทยมาจากแอป Flutter

        if (isNaN(bookingId) || !status) {
            return res.status(400).json({ success: false, error: "ข้อมูลไม่ถูกต้อง" });
        }

        const existingBooking = await prisma.vehicleBooking.findUnique({
            where: { id: bookingId }
        });

        if (!existingBooking) {
            return res.status(404).json({ success: false, error: "ไม่พบข้อมูลการจองนี้" });
        }

        // ✅ 1. ย้ายบล็อกตรวจสอบสิทธิ์เข้ามาอยู่ภายในฟังก์ชัน (ใต้จุดที่ดึงข้อมูลสำเร็จ)
        // 🛡️ ตรวจสอบสิทธิ์ (Authorization & IDOR Check)
        if (req.user.role === 'ADMIN') {
            // อนุญาต: ADMIN ทำได้ทุกอย่าง
        } else if (req.user.role === 'USER' && existingBooking.userId === parseInt(req.user.userId, 10)) {
            // อนุญาต: USER แก้ไขได้เฉพาะรายการที่ตัวเองเป็นเจ้าของเท่านั้น
        } else {
            // ดีดออก: GUARD, SECURITY หรือ Role อื่นๆ รวมถึง USER ที่พยายามแก้ของคนอื่น
            return res.status(403).json({ 
                success: false, 
                error: 'คุณไม่มีสิทธิ์แก้ไขหรือยกเลิกการจองของผู้อื่น' 
            });
        }

        // 💡 แปลงสถานะภาษาไทยจากแอป ให้ตรงกับ Enum ภาษาอังกฤษในฐานข้อมูล (Prisma)
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

        res.status(200).json({ success: true, data: updatedBooking, message: "อัปเดตสถานะสำเร็จ" });
    } catch (error) {
        console.error("Update Booking Status Error:", error);
        res.status(500).json({ success: false, error: "ไม่สามารถอัปเดตสถานะได้" });
    }
};

// ✅ วางการ Export ไว้ท้ายสุดของฟังก์ชันอย่างถูกต้อง
exports.getHistory = exports.getBookings;