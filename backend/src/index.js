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

// 📑 ตั้งค่าหน้าปกคู่มือ API (อัปเกรดระบบใส่ Token และเส้นทางทดสอบ)
const swaggerDocument = {
  openapi: '3.0.0',
  info: { 
    title: '🏢 Internal Booking API', 
    version: '1.0.0', 
    description: 'คู่มือสำหรับทีม Frontend (มีระบบใส่ตั๋วทดสอบ API และระบบล็อกอินแยกสิทธิ์)' 
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
  // 🔓 2. เปิดใช้งานระบบล็อกให้ทุกเส้นทางในคู่มือ (ยกเว้นเส้นทางที่เราปลดล็อกแยกต่างหาก)
  security: [{ BearerAuth: [] }], 
  paths: {
    // 🔑 เส้นทางที่ 1: ล็อกอินเข้าสู่ระบบ (Login)
    '/api/login': {
      post: {
        summary: 'เข้าสู่ระบบ (Login)',
        description: '💡 เงื่อนไขสิทธิ์: พนักงานทั่วไปกรอกแค่ employeeId | ส่วน ADMIN และ GUARD ต้องกรอก password ด้วย',
        security: [], // 🔓 ปลดล็อกแม่กุญแจสำหรับหน้านี้ เพื่อให้กดเทสต์ส่งข้อมูลได้เลย
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                properties: {
                  employeeId: { type: 'string', example: 'MC-WK0006', description: 'รหัสพนักงาน' },
                  password: { type: 'string', example: '1234', description: 'รหัสผ่าน (ใส่เฉพาะสิทธิ์ ADMIN หรือ GUARD)' }
                },
                required: ['employeeId']
              }
            }
          }
        },
        responses: {
          200: { description: 'เข้าสู่ระบบสำเร็จ (จะได้รับ JWT Token คืนกลับไป)' },
          400: { description: 'ข้อมูลไม่ครบถ้วน / กรุณากรอกรหัสพนักงาน' },
          401: { description: 'รหัสผ่านไม่ถูกต้อง (สำหรับ ADMIN/GUARD)' },
          404: { description: 'ไม่พบรหัสพนักงานนี้ในระบบ' },
          500: { description: 'ระบบหลังบ้านขัดข้อง' }
        }
      }
    },
    // 👤 เส้นทางที่ 2: เช็กโปรไฟล์ตัวเอง (ดึงข้อมูลพนักงานจาก Token)
    '/api/me': {
      get: {
        summary: 'เช็กโปรไฟล์ของผู้ใช้งานปัจจุบัน (/me)',
        description: '🔒 ต้องเอา Token ที่ได้จากหน้า Login ไปแปะที่ปุ่ม Authorize (รูปแม่กุญแจด้านบนสุดของเว็บ) ก่อน ถึงจะกดเทสต์หน้านี้ผ่าน',
        responses: {
          200: { description: 'ดึงข้อมูลสำเร็จ คืนค่าข้อมูลพนักงาน ตำแหน่ง และสิทธิ์ใช้งาน' },
          404: { description: 'ไม่พบข้อมูลผู้ใช้งานนี้' },
          500: { description: 'ระบบไม่สามารถตรวจสอบ Token ได้' }
        }
      }
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

// 📖 เปิดหน้าคู่มือ API ให้ Frontend เข้ามาดูและทดสอบ
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument));

// 🔌 เชื่อมต่อโมดูลเส้นทาง (Routing Middleware)
app.use('/api', authRoutes);              // ดูแลคิว /api/login, /api/me
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