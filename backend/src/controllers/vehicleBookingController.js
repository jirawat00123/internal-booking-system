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

        // 💡 3. เช็กคนจอง (ถ้าหน้าแอป Flutter ส่ง userId มาให้เซฟคนนั้น แต่ถ้าไม่ส่ง ให้ใช้คน Login)
        const finalUserId = userId ? parseInt(userId) : req.user.id;

        const newBooking = await prisma.vehicleBooking.create({
            data: {
                vehicleId: parseInt(vehicleId),
                userId: finalUserId, // 👈 ใช้ ID ที่ดักไว้ถูกต้องแล้ว
                destination: destination || "-",
                startDatetime: new Date(startDatetime),
                endDatetime: new Date(endDatetime),
                passengers: finalPassengers, // 👈 ใช้จำนวนคนที่ดักไว้ถูกต้องแล้ว
                purpose: purpose || "ใช้งานบริษัท",
                driverType: driverType || "ขับขี่เอง",
                status: "Pending" // ค่าเริ่มต้นคือ รออนุมัติ
            }
        });

        res.status(201).json({ success: true, data: newBooking, message: "จองรถสำเร็จ" });
    } catch (error) {
        console.error("Create Vehicle Booking Error:", error);
        res.status(500).json({ success: false, error: "ไม่สามารถสร้างการจองรถได้" });
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