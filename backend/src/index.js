const express = require('express');
const cors = require('cors');
const authRoutes = require('./routes/auth');
const bookingRoutes = require('./routes/bookings');
const resourceRoutes = require('./routes/resources');

// 📖 นำเข้า Swagger
const swaggerUi = require('swagger-ui-express');

const app = express();
app.get('/', (req, res) => {
    res.send("SERVER OK");
});
app.use(cors());
app.use(express.json());

// 📑 ตั้งค่าหน้าปกคู่มือ API 
const swaggerDocument = {
  openapi: '3.0.0',
  info: { 
    title: '🏢 Internal Booking API', 
    version: '1.0.0', 
    description: 'คู่มือสำหรับทีม Frontend (รองรับสิทธิ์ USER, ADMIN, GUARD)' 
  },
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
  security: [{ BearerAuth: [] }], 
  paths: {
    '/api/login': {
      post: {
        summary: 'เข้าสู่ระบบ (Login)',
        description: '💡 ใช้รหัสพนักงาน เช่น EMP001 (ADMIN), EMP002 (USER)',
        security: [], 
        requestBody: {
          required: true,
          content: { 'application/json': { schema: { type: 'object', properties: { employeeCode: { type: 'string', example: 'EMP001' } }, required: ['employeeCode'] } } }
        },
        responses: { 200: { description: 'สำเร็จ' }, 404: { description: 'ไม่พบรหัสพนักงาน' } }
      }
    },
    // 🔑 กลับมาแล้ว! เมนู Login PIN
    '/api/login-pin': {
      post: {
        summary: 'เข้าสู่ระบบด้วย PIN (Admin & Security)',
        description: '💡 ใช้รหัส PIN 6 หลัก \n\n**รหัสที่รองรับ:** \n- 741963 (Admin HR)\n- 852000 (Admin IT)\n- 001122 (Security)',
        security: [],
        requestBody: {
          required: true,
          content: { 'application/json': { schema: { type: 'object', properties: { pin: { type: 'string', example: '741963' } }, required: ['pin'] } } }
        },
        responses: { 200: { description: 'สำเร็จ' }, 401: { description: 'รหัสผิด' } }
      }
    },
    '/api/me': {
      get: { summary: 'เช็กโปรไฟล์ของผู้ใช้งานปัจจุบัน (/me)', responses: { 200: { description: 'สำเร็จ' } } }
    },
    // 📖 กลับมาแล้ว! เมนู Bookings
    '/api/bookings': {
      get: { summary: 'ดึงข้อมูลการจองทั้งหมด', responses: { 200: { description: 'สำเร็จ' } } }
    },
    '/api/resources/rooms': {
      get: { summary: 'ดึงรายชื่อห้องประชุม', responses: { 200: { description: 'สำเร็จ' } } }
    },
    '/api/resources/vehicles': {
      get: { summary: 'ดึงรายชื่อรถยนต์บริษัท', responses: { 200: { description: 'สำเร็จ' } } }
    }
  }
};

app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument));

// 🔌 เชื่อมต่อโมดูลเส้นทาง
app.use('/api', authRoutes);              
app.use('/api/bookings', bookingRoutes);  
app.use('/api/resources', resourceRoutes); 

app.use((err, req, res, next) => {
  console.error('🔴 Centralized Error:', err.stack);
  res.status(500).json({ error: "เกิดข้อผิดพลาดภายในระบบหลังบ้าน", developerMessage: err.message });
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`🚀 Clean Server is running on http://localhost:${PORT}`);
  console.log(`📖 เปิดดูคู่มือ API ได้ที่ http://localhost:${PORT}/api-docs`);
});