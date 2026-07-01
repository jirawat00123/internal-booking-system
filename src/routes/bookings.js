const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { authenticateToken } = require('../middlewares/auth');
const bookingController = require('../controllers/bookingController');

const router = express.Router();
const prisma = new PrismaClient();

// 🚗 [GET] /api/bookings - ดึงประวัติรายการจองทั้งหมดจาก Database (รองรับระบบ Booking History)
router.get('/', authenticateToken, async (req, res, next) => {
  try {
    // แก้จากของเดิม เป็นแบบนี้
const bookings = await prisma.roomBooking.findMany({
   include: {
      room: true,
      user: {
         include: {
            employee: true // ดึงข้อมูลพนักงาน (ที่มีชื่อ นามสกุล รหัสพนักงาน) ออกมาด้วย
         }
      }
   },
   orderBy: {
      bookingDate: "desc"
   }
});

    res.status(200).json({
      success: true,
      message: "ดึงข้อมูลรายการจองสำเร็จ (Booking API is ready to use!)",
      bookings: bookings
    });
  } catch (error) {
    console.error('Get Bookings Error:', error);
    res.status(500).json({ 
      success: false, 
      error: "ระบบดึงข้อมูลการจองขัดข้อง",
      developerMessage: error.message 
    });
  }
});

// 🔍 [POST] /api/bookings/check-availability - เส้นทางสำหรับเช็คเวลาว่าง
// POST /api/bookings/check-availability
router.post('/check-availability', authenticateToken, async (req, res, next) => {
    try {
        const { room_id, booking_date, start_time, end_time } = req.body;

        // 1. จำลองการรวมวันที่และเวลาให้เป็น Date Object ที่สมบูรณ์
        // (เพื่อให้ Prisma ใช้เปรียบเทียบ lt, gt ได้อย่างถูกต้อง)
        const requestStart = new Date(`${booking_date}T${start_time}.000Z`);
        const requestEnd = new Date(`${booking_date}T${end_time}.000Z`);
        const queryDate = new Date(`${booking_date}T00:00:00.000Z`);

        // 2. ค้นหาการจองที่มีอยู่ในระบบและเวลาทับซ้อนกัน
        const overlappingBooking = await prisma.roomBooking.findFirst({
            where: {
                roomId: parseInt(room_id),
                bookingDate: queryDate,
                status: {
                    not: "Cancelled" // ไม่เอาคิวที่ยกเลิกไปแล้วมาคิด
                },
                AND: [
                    {
                        startTime: {
                            lt: requestEnd // เริ่มก่อนที่เราจะจบ
                        }
                    },
                    {
                        endTime: {
                            gt: requestStart // จบหลังที่เราเริ่ม
                        }
                    }
                ]
            }
        });

        // 3. ตรวจสอบผลลัพธ์และตอบกลับ Frontend
        if (overlappingBooking) {
            // กรณีคิวชน! (เจอข้อมูลทับซ้อน)
            return res.status(409).json({
                success: false,
                available: false,
                message: "ห้องประชุมนี้มีการจองในช่วงเวลาดังกล่าวแล้ว",
                conflict: {
                    id: overlappingBooking.id,
                    title: overlappingBooking.title,
                    time: `${overlappingBooking.startTime.toISOString()} - ${overlappingBooking.endTime.toISOString()}`
                }
            });
        }

        // กรณีคิวว่าง! (ไม่เจอข้อมูลทับซ้อน)
        return res.status(200).json({
            success: true,
            available: true,
            message: "เวลาว่าง สามารถดำเนินการจองได้"
        });

    } catch (error) {
        next(error);
    }
});

// ➕ [POST] /api/bookings - เส้นทางสำหรับสร้างรายการจองใหม่
router.post('/', authenticateToken, bookingController.createBooking);

// ❌ [PATCH] /api/bookings/:id/cancel - เส้นทางสำหรับยกเลิกการจอง (Soft Delete)
router.patch('/:id/cancel', authenticateToken, async (req, res, next) => {
    try {
        const { id } = req.params;

        // ทำ Soft Delete โดยการอัปเดตสถานะ (ไม่ได้ลบแถวข้อมูล)
        const canceledBooking = await prisma.roomBooking.update({
            where: { 
                id: parseInt(id) // อย่าลืมแปลง id เป็นตัวเลข (Int)
            },
            data: { 
                status: 'Cancelled' // หรือ 'Canceled' ตามที่ระบบของคุณกำหนดไว้
            }
        });

        return res.status(200).json({
            success: true,
            message: "ยกเลิกการจองห้องประชุมเรียบร้อยแล้ว",
            data: canceledBooking
        });
    } catch (error) {
        next(error); // ส่งต่อให้ error handler ตัวเดิมจัดการหากมีข้อผิดพลาด
    }
});

// 🚨 ส่งออก router นี้ออกไปให้ index.js เรียกใช้งาน
module.exports = router;