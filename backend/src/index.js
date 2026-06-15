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

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`🚀 Clean Server is running on http://localhost:${PORT}`);
  console.log(`📖 เปิดดูคู่มือ API ได้ที่ http://localhost:${PORT}/api-docs`);
});