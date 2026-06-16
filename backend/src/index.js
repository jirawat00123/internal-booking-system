const express = require('express');
const cors = require('cors');
const authRoutes = require('./routes/auth');
const bookingRoutes = require('./routes/bookings');
const resourceRoutes = require('./routes/resources');

// 📖 นำเข้า Swagger
const swaggerUi = require('swagger-ui-express');

const app = express();
app.use(cors());
app.use(express.json());

// 📑 ตั้งค่าหน้าปกคู่มือ API (อัปเกรดระบบใส่ Token)
const swaggerDocument = {
  openapi: '3.0.0',
  info: { 
    title: '🏢 Internal Booking API', 
    version: '1.0.0', 
    description: 'คู่มือสำหรับทีม Frontend (มีระบบใส่ตั๋วทดสอบ API)' 
  },
  // 🔒 1. เพิ่มระบบใส่ตั๋ว JWT (ปุ่ม Authorize รูปแม่กุญแจ)
  components: {
    securitySchemes: {
      BearerAuth: {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
        description: 'เอา Token ยาวๆ ที่ได้จากตอน Login มาใส่ที่นี่ (ไม่ต้องพิมพ์คำว่า Bearer นำหน้า)'
      }
    }
  },
  // 🔓 2. เปิดใช้งานระบบล็อกให้ทุกเส้นทางในคู่มือ
  security: [{ BearerAuth: [] }], 
  paths: {
    '/api/resources/rooms': {
      get: { summary: 'ดึงรายชื่อห้องประชุม', responses: { 200: { description: 'สำเร็จ' } } }
    },
    '/api/resources/vehicles': {
      get: { summary: 'ดึงรายชื่อรถยนต์บริษัท', responses: { 200: { description: 'สำเร็จ' } } }
    }
    // (สามารถเติมเส้นทางอื่นๆ เช่น /api/bookings/vehicle ต่อที่นี่ได้ในอนาคตครับ)
  }
};

// 📖 เปิดหน้าคู่มือ API ให้ Frontend เข้ามาดูและทดสอบ
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument));

// 🔌 เชื่อมต่อโมดูลเส้นทาง (Routing Middleware)
app.use('/api', authRoutes);              // ดูแลคิว /api/setup, /api/login, /api/me
app.use('/api/bookings', bookingRoutes);  // ดูแลคิว /api/bookings/room, /api/bookings/vehicle
app.use('/api/resources', resourceRoutes); // ดูแลคิว /api/resources/rooms, /api/resources/vehicles

// 🛡️ Middleware ดักจับ Error ส่วนกลาง (ช่วยชีวิตเพื่อน Frontend)
app.use((err, req, res, next) => {
  console.error('🔴 Centralized Error:', err.stack);
  res.status(500).json({
    error: "เกิดข้อผิดพลาดภายในระบบหลังบ้าน กรุณาแจ้งผู้ดูแลระบบ",
    developerMessage: err.message // ส่งข้อความบั๊กให้เพื่อน Dev เอาไปแก้ต่อได้ง่ายขึ้น
  });
});

<<<<<<< HEAD
app.post('/api/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) return res.status(401).json({ error: 'ไม่พบอีเมลนี้ในระบบ' });
    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) return res.status(401).json({ error: 'รหัสผ่านไม่ถูกต้อง' });
    const token = jwt.sign({ userId: user.id, role: user.role }, 'my_secret_key', { expiresIn: '1d' });
    res.json({ message: 'เข้าสู่ระบบสำเร็จ!', token, user: { id: user.id, name: user.name, email: user.email, role: user.role } });
  } catch (error) { res.status(500).json({ error: 'เกิดข้อผิดพลาด' }); }
});

app.post('/api/rooms', async (req, res) => {
  try {
    const { name, description, capacity } = req.body;
    const newRoom = await prisma.room.create({ data: { name, description, capacity } });
    res.status(201).json({ message: 'สร้างห้องสำเร็จ!', room: newRoom });
  } catch (error) { res.status(500).json({ error: 'เกิดข้อผิดพลาด' }); }
});

app.get('/api/rooms', async (req, res) => {
  try { const rooms = await prisma.room.findMany(); res.json(rooms); } 
  catch (error) { res.status(500).json({ error: 'เกิดข้อผิดพลาด' }); }
});

app.get('/api/bookings', authenticateToken, async (req, res) => {
  try {
    const bookings = await prisma.booking.findMany({
      include: { user: { select: { name: true, email: true } }, room: { select: { name: true } } }
    });
    res.json(bookings);
  } catch (error) { res.status(500).json({ error: 'เกิดข้อผิดพลาด' }); }
});

// 📅 API จองห้อง (อัปเกรดป้องกันการจองซ้อน!)
app.post('/api/bookings', authenticateToken, async (req, res) => {
  try {
    const { roomId, startTime, endTime } = req.body; 
    const userId = req.user.userId; 

    // แปลงเวลาที่ส่งมาให้เป็นรูปแบบวันที่ของระบบ
    const newStartTime = new Date(startTime);
    const newEndTime = new Date(endTime);

    // 🕵️‍♂️ ค้นหาว่ามีใครจองห้องนี้ ในเวลาที่ทับซ้อนกันหรือไม่
    const existingBooking = await prisma.booking.findFirst({
      where: {
        roomId: parseInt(roomId),
        // สูตรเช็กเวลาทับซ้อน: เวลาเริ่มของคนเก่าต้อง "น้อยกว่า" เวลาจบของเรา และ เวลาจบของคนเก่าต้อง "มากกว่า" เวลาเริ่มของเรา
        startTime: { lt: newEndTime },
        endTime: { gt: newStartTime }
      }
    });

    // ถ้าเจอว่ามีคนจองแล้ว (ทับซ้อน) ให้เด้งกลับเลย!
    if (existingBooking) {
      return res.status(400).json({ 
        error: 'เสียใจด้วยครับ ห้องประชุมนี้มีคนจองในช่วงเวลาดังกล่าวแล้ว 😭',
        conflictingBookingId: existingBooking.id
      });
    }

    // ถ้าว่างรอดมาได้ ก็บันทึกการจองตามปกติ
    const newBooking = await prisma.booking.create({
      data: {
        userId: userId,
        roomId: parseInt(roomId),
        startTime: newStartTime,
        endTime: newEndTime
      }
    });
    res.status(201).json({ message: 'จองห้องประชุมสำเร็จ! 🎉', booking: newBooking });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'เกิดข้อผิดพลาดในการจองห้องประชุม' });
  }
});

// 🗑️ API ยกเลิกการจอง (ลบข้อมูล)
app.delete('/api/bookings/:id', authenticateToken, async (req, res) => {
  try {
    const bookingId = parseInt(req.params.id); // รับ ID ของการจองจาก URL
    const userId = req.user.userId; // รับ ID ของผู้ใช้ที่ล็อกอินอยู่จากคีย์การ์ด (Token)

    // 1. ค้นหาว่ามีการจองนี้ในระบบไหม
    const existingBooking = await prisma.booking.findUnique({
      where: { id: bookingId }
    });

    if (!existingBooking) {
      return res.status(404).json({ error: 'ไม่พบข้อมูลการจองนี้ในระบบ' });
    }

    // 2. เช็กว่าใช่เจ้าของคิวจองจริงๆ หรือไม่
    if (existingBooking.userId !== userId) {
      return res.status(403).json({ error: 'หยุดนะ! คุณไม่มีสิทธิ์ยกเลิกการจองของคนอื่น 😠' });
    }

    // 3. ถ้าผ่านด่านทั้งหมด ก็สั่งลบได้เลย
    await prisma.booking.delete({
      where: { id: bookingId }
    });

    res.json({ message: 'ยกเลิกการจองสำเร็จเรียบร้อยครับ! 🗑️' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'เกิดข้อผิดพลาดในการยกเลิกการจอง' });
  }
});

// 🔍 API ค้นหาห้องว่างตามช่วงเวลา
app.post('/api/rooms/available', authenticateToken, async (req, res) => {
  try {
    const { startTime, endTime } = req.body;
    
    // แปลงเวลาที่ส่งมาให้ระบบเข้าใจ
    const searchStartTime = new Date(startTime);
    const searchEndTime = new Date(endTime);

    // ใช้คำสั่ง Prisma ค้นหาห้องที่ "ไม่มี" (NOT) การจองที่เวลาทับซ้อนกัน
    const availableRooms = await prisma.room.findMany({
      where: {
        NOT: {
          bookings: {
            some: {
              startTime: { lt: searchEndTime },
              endTime: { gt: searchStartTime }
            }
          }
        }
      }
    });

    res.json({ 
      message: `ค้นพบห้องว่าง ${availableRooms.length} ห้อง`, 
      rooms: availableRooms 
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'เกิดข้อผิดพลาดในการค้นหาห้อง' });
  }
});

app.listen(port, () => {
  console.log(`✅ Server is running on http://localhost:${port}`);
=======
const PORT = 3000;
app.listen(PORT, () => {
  console.log(`🚀 Clean Server is running on http://localhost:${PORT}`);
  console.log(`📖 เปิดดูคู่มือ API ได้ที่ http://localhost:${PORT}/api-docs`);
>>>>>>> main
});