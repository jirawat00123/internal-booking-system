const express = require('express');
const cors = require('cors');
const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const prisma = new PrismaClient();
const app = express();
const port = 3000;

app.use(cors());
app.use(express.json());

// 🛡️ คุณ รปภ. (Middleware)
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'หยุดนะ! กรุณาเข้าสู่ระบบก่อน (ไม่พบ Token)' });

  jwt.verify(token, 'my_secret_key', (err, user) => {
    if (err) return res.status(403).json({ error: 'บัตรผ่านหมดอายุ หรือปลอมแปลง!' });
    req.user = user; 
    next();
  });
};

app.get('/api/test', (req, res) => { res.json({ message: 'Hello from Backend!', status: 'success' }); });

app.post('/api/register', async (req, res) => {
  try {
    const { email, name, password } = req.body;
    const existingUser = await prisma.user.findUnique({ where: { email } });
    if (existingUser) return res.status(400).json({ error: 'อีเมลนี้ถูกใช้งานแล้ว' });
    const hashedPassword = await bcrypt.hash(password, 10);
    const newUser = await prisma.user.create({ data: { email, name, password: hashedPassword } });
    res.status(201).json({ message: 'สมัครสมาชิกสำเร็จ!', user: { id: newUser.id, email: newUser.email, name: newUser.name } });
  } catch (error) { res.status(500).json({ error: 'เกิดข้อผิดพลาด' }); }
});

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
});