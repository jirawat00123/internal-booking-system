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

// 📑 ตั้งค่าหน้าปกคู่มือ API (อัปเดตให้ตรงกับ Database ปัจจุบัน)
const swaggerDocument = {
  openapi: '3.0.0',
  info: { 
    title: '🏢 Internal Booking API', 
    version: '1.0.0', 
    description: 'คู่มือสำหรับทีม Frontend (อัปเดตตามโครงสร้าง Database ปัจจุบัน - รองรับสิทธิ์ USER, ADMIN, GUARD)' 
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
    // 🔑 เส้นทางที่ 1: ล็อกอินเข้าสู่ระบบ (Login)
    '/api/login': {
      post: {
        summary: 'เข้าสู่ระบบ (Login)',
        description: '💡 ใช้รหัสพนักงาน (employeeCode) ในการเข้าระบบ เช่น EMP001 (ADMIN), EMP002 (USER), EMP003 (GUARD)',
        security: [], // 🔓 ปลดล็อกแม่กุญแจให้เทสต์ได้
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                properties: {
                  employeeCode: { type: 'string', example: 'SEC001', description: 'รหัสพนักงาน (เช่น SEC001 สำหรับ Guard)' },
                  pin: { type: 'string', example: '998877', description: 'รหัส PIN 6 หลัก (ใส่เฉพาะ ADMIN และ GUARD, ถ้า USER ไม่ต้องใส่)' }
                },
                required: ['employeeCode']
              }
            }
          }
        },
        responses: {
          200: { description: 'เข้าสู่ระบบสำเร็จ (จะได้รับ JWT Token คืนกลับไป)' },
          400: { description: 'ข้อมูลไม่ครบถ้วน / กรุณากรอกรหัสพนักงาน' },
          404: { description: 'ไม่พบรหัสพนักงานนี้ในระบบ' },
          500: { description: 'ระบบหลังบ้านขัดข้อง' }
        }
      }
    },
    // 🔑 เส้นทางที่ 1.5: เมนู Login PIN (แยกเฉพาะ Admin & Security)
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
    // 👤 เส้นทางที่ 2: เช็กโปรไฟล์ตัวเอง
    '/api/me': {
      get: {
        summary: 'เช็กโปรไฟล์ของผู้ใช้งานปัจจุบัน (/me)',
        description: '🔒 ต้องใส่ Token ที่รูปแม่กุญแจก่อน',
        responses: {
          200: { description: 'ดึงข้อมูลสำเร็จ คืนค่าข้อมูลพนักงาน ตำแหน่ง และสิทธิ์ใช้งาน' },
          404: { description: 'ไม่พบข้อมูลผู้ใช้งานนี้' },
          500: { description: 'ระบบไม่สามารถตรวจสอบ Token ได้' }
        }
      }
    },
    // 📖 เส้นทางที่ 3: เมนู Bookings
    '/api/bookings': {
      get: { summary: 'ดึงข้อมูลการจองทั้งหมด', responses: { 200: { description: 'สำเร็จ' } } }
    },
    // 🚗 เส้นทางทรัพยากรต่างๆ ของระบบ
    '/api/resources/rooms': {
      get: { summary: 'ดึงรายชื่อห้องประชุม', responses: { 200: { description: 'สำเร็จ' } } }
    },
    '/api/resources/vehicles': {
      get: { summary: 'ดึงรายชื่อรถยนต์บริษัท', responses: { 200: { description: 'สำเร็จ' } } }
    }
  }
};

// 📖 เปิดหน้าคู่มือ API
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument));

// 🔌 เชื่อมต่อโมดูลเส้นทาง
app.use('/api', authRoutes);              // ดึงมาจาก routes/auth.js
app.use('/api/bookings', bookingRoutes);  // ดึงมาจาก routes/bookings.js
app.use('/api/resources', resourceRoutes); // ดึงมาจาก routes/resources.js

// 🛡️ Middleware ดักจับ Error ส่วนกลาง
app.use((err, req, res, next) => {
  console.error('🔴 Centralized Error:', err.stack);
  res.status(500).json({
    error: "เกิดข้อผิดพลาดภายในระบบหลังบ้าน กรุณาแจ้งผู้ดูแลระบบ",
    developerMessage: err.message
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Clean Server is running on http://localhost:${PORT}`);
  console.log(`📖 เปิดดูคู่มือ API ได้ที่ http://localhost:${PORT}/api-docs`);
});