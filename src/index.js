require('dotenv').config();
const express = require('express');
const path = require('path');
const cors = require('cors');
const { PrismaClient } = require('@prisma/client'); // ✅ แก้บั๊ก: นำเข้า PrismaClient สำหรับจัดการห้องประชุม

// นำเข้า Routes ต่างๆ
const authRoutes = require('./routes/auth');
const bookingRoutes = require('./routes/bookings');
const resourceRoutes = require('./routes/resources');
const roomRoutes = require('./routes/roomRouter');
const employeeRoutes = require('./routes/employees');
const vehicleRoutes = require('./routes/vehicles');
const vehicleBookingsRouter = require('./routes/vehicleBookings');

// 📖 นำเข้า Swagger
const swaggerUi = require('swagger-ui-express');

const app = express();
const prisma = new PrismaClient(); // ✅ แก้บั๊ก: สร้าง Instance สำหรับเชื่อมต่อ PostgreSQL

// ==========================================
// 🛠️ ตั้งค่า Middleware พื้นฐาน
// ==========================================
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ==========================================
// 📁 เปิดสิทธิ์การอ่านไฟล์ภาพ (Serve Static Files)
// ==========================================
// อนุญาตให้ Frontend ดึงรูปภาพจากโฟลเดอร์ uploads ผ่าน URL /uploads/...
// ใช้ process.cwd() เพื่อให้อ้างอิงไปยังโฟลเดอร์หลักของโปรเจกต์ได้อย่างปลอดภัยและเสถียรที่สุด
app.use('/uploads', express.static(path.join(process.cwd(), 'uploads')));

// ==========================================
// 📑 ตั้งค่าหน้าปกคู่มือ API (Swagger)
// ==========================================
const swaggerDocument = {
  openapi: '3.0.0',
  info: { 
    title: '🏢 Internal Booking API', 
    version: '1.0.0', 
    description: 'คู่มือสำหรับทีม Frontend (อัปเดตระบบ Meeting Room & Vehicle Booking Module ครบถ้วน - รองรับสิทธิ์ USER, ADMIN, GUARD)' 
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
    // 🔑 เส้นทาง: ล็อกอินเข้าสู่ระบบ (Login)
    '/api/login': {
      post: {
        summary: 'เข้าสู่ระบบ (Login)',
        description: '💡 ใช้รหัสพนักงาน (employeeCode) ในการเข้าระบบ เช่น EMP001 (ADMIN), EMP002 (USER), EMP003 (GUARD)',
        security: [], 
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
          401: { description: 'รหัสผิด' },
          404: { description: 'ไม่พบรหัสพนักงานนี้ในระบบ' },
          500: { description: 'ระบบหลังบ้านขัดข้อง' }
        }
      }
    },
    // 🔑 เส้นทาง: เมนู Login PIN (แยกเฉพาะ Admin & Security)
    '/api/login-pin': {
      post: {
        summary: 'เข้าสู่ระบบด้วย PIN (Admin & Security)',
        description: '💡 ใช้รหัส PIN 6 หลัก \n\n**รหัสที่รองรับ:** \n- 741963 (Admin HR)\n- 852000 (Admin IT)\n- 001122 (Security)',
        security: [],
        requestBody: {
          required: true,
          content: { 
            'application/json': { 
              schema: { 
                type: 'object', 
                properties: { 
                  pin: { type: 'string', example: '741963' } 
                }, 
                required: ['pin'] 
              } 
            } 
          }
        },
        responses: { 
          200: { description: 'สำเร็จ' }, 
          401: { description: 'รหัสผิด' } 
        }
      }
    },
    // 👤 เส้นทาง: เช็กโปรไฟล์ตัวเอง
    '/api/me': {
      get: {
        summary: 'เช็กโปรไฟล์ของผู้ใช้งานปัจจุบัน (/me)',
        description: '🔒 ต้องใส่ Token ที่รูปแม่กุญแจก่อน',
        responses: {
          200: { description: 'ดึงข้อมูลสำเร็จ คืนค่าข้อมูลพนักงาน ตำแหน่ง และสิทธิ์ใช้งาน' },
          441: { description: 'ไม่ได้แนบ Token หรือ Token หมดอายุ' },
          404: { description: 'ไม่พบข้อมูลผู้ใช้งานนี้' },
          500: { description: 'ระบบไม่สามารถตรวจสอบ Token ได้' }
        }
      }
    },
    // 🏢 เส้นทาง: รายการห้องประชุม
    '/api/rooms': {
      get: { 
        summary: 'ดึงรายชื่อห้องประชุมทั้งหมด (Room List)', 
        security: [],
        responses: { 200: { description: 'สำเร็จ' } } 
      }
    },
    // 📅 เส้นทาง: จัดการการจอง (Booking)
    '/api/bookings': {
      get: { 
        summary: 'ดึงประวัติการจองทั้งหมด (Booking History)', 
        description: '🔒 ต้องใส่ Token - ดึงรายการจองเรียงตามวันล่าสุด พร้อมข้อมูลห้องและผู้จอง',
        responses: { 200: { description: 'สำเร็จ' } } 
      },
      post: {
        summary: 'สร้างรายการจองห้องประชุม (Create Booking)',
        description: '🔒 ต้องใส่ Token - บันทึกการจองและตรวจสอบเวลาซ้ำอัตโนมัติ',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                properties: {
                  room_id: { type: 'integer', example: 1 },
                  user_id: { type: 'integer', example: 1 },
                  booking_date: { type: 'string', format: 'date', example: '2026-06-30' },
                  start_time: { type: 'string', example: '10:00:00' },
                  end_time: { type: 'string', example: '12:00:00' },
                  title: { type: 'string', example: 'ประชุมทีมประจำสัปดาห์' },
                  participants: { type: 'integer', example: 10 }
                },
                required: ['room_id', 'user_id', 'booking_date', 'start_time', 'end_time', 'title']
              }
            }
          }
        },
        responses: {
          201: { description: 'สร้างการจองสำเร็จ' },
          400: { description: 'ข้อมูลไม่ครบถ้วน' },
          409: { description: 'เวลาทับซ้อน (จองไม่ได้)' }
        }
      }
    },
    // 🔍 เส้นทาง: เช็คเวลาว่าง
    '/api/bookings/check-availability': {
      post: {
        summary: 'ตรวจสอบเวลาว่างของห้องประชุม (Availability Check)',
        description: '🔒 ต้องใส่ Token - ตรวจสอบว่าห้องประชุมว่างในช่วงเวลาที่ต้องการหรือไม่',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                properties: {
                  room_id: { type: 'integer', example: 1 },
                  booking_date: { type: 'string', format: 'date', example: '2026-06-30' },
                  start_time: { type: 'string', example: '10:00:00' },
                  end_time: { type: 'string', example: '12:00:00' }
                },
                required: ['room_id', 'booking_date', 'start_time', 'end_time']
              }
            }
          }
        },
        responses: {
          200: { description: 'ช่วงเวลาว่าง สามารถจองได้' },
          409: { description: 'ช่วงเวลาถูกจองแล้ว' }
        }
      }
    },
    // ❌ เส้นทาง: ยกเลิกการจอง
    '/api/bookings/{id}/cancel': {
      patch: {
        summary: 'ยกเลิกการจอง (Cancel Booking - Soft Delete)',
        description: '🔒 ต้องใส่ Token - เปลี่ยนสถานะการจองเป็น Cancelled และคืนห้องให้กลับมาว่าง',
        parameters: [
          {
            name: 'id',
            in: 'path',
            required: true,
            description: 'ID ของรายการจองที่ต้องการยกเลิก',
            schema: { type: 'integer' }
          }
        ],
        responses: {
          200: { description: 'ยกเลิกการจองสำเร็จ' },
          404: { description: 'ไม่พบรายการจองนี้' }
        }
      }
    },
    // 🚗 เส้นทางทรัพยากรอื่นๆ ของระบบ
    '/api/resources/rooms': {
      get: { summary: 'ดึงรายชื่อห้องประชุม (ข้อมูลดิบ)', responses: { 200: { description: 'สำเร็จ' } } }
    },
    '/api/resources/vehicles': {
      get: { summary: 'ดึงรายชื่อรถยนต์บริษัท', responses: { 200: { description: 'สำเร็จ' } } }
    },
    
    // ==========================================
    // 🚗 เส้นทางระบบจัดการรถยนต์ (Vehicles Module) - เพิ่มใหม่
    // ==========================================
    '/api/vehicles': {
      get: {
        summary: 'ดึงข้อมูลรถยนต์ทั้งหมด (Vehicle List)',
        description: '🔒 ต้องใส่ Token - ดึงรายการรถยนต์ทั้งหมดที่ยังไม่ถูกลบ (isDeleted: false) เรียงจากใหม่ไปเก่า',
        responses: {
          200: { description: 'ดึงข้อมูลสำเร็จ คืนค่าอาร์เรย์รายการรถยนต์ทั้งหมด' },
          500: { description: 'ระบบขัดข้องในการดึงข้อมูลรถ' }
        }
      },
      post: {
        summary: 'เพิ่มข้อมูลรถยนต์ใหม่ พร้อมอัปโหลดรูปภาพ (Create Vehicle)',
        description: '🔒 ต้องใส่ Token (เฉพาะ ADMIN) - รองรับการอัปโหลดไฟล์รูปภาพ (.png, .jpg, .jpeg) จำกัดขนาดไม่เกิน 5MB โดยระบบจะตรวจสอบป้ายทะเบียนซ้ำอัตโนมัติ',
        requestBody: {
          required: true,
          content: {
            'multipart/form-data': {
              schema: {
                type: 'object',
                properties: {
                  plateNumber: { type: 'string', example: 'นข-9999', description: 'ป้ายทะเบียนรถยนต์ (ห้ามว่าง, ห้ามซ้ำ)' },
                  brand: { type: 'string', example: 'Toyota', description: 'ยี่ห้อรถยนต์ (ห้ามว่าง)' },
                  model: { type: 'string', example: 'Camry', description: 'รุ่นรถยนต์ (ห้ามว่าง)' },
                  seats: { type: 'integer', example: 4, description: 'จำนวนที่นั่ง (ต้องมากกว่า 0, Default เป็น 4)' },
                  status: { type: 'string', example: 'AVAILABLE', description: 'สถานะของรถ (AVAILABLE, MAINTENANCE, INACTIVE)' },
                  image: { type: 'string', format: 'binary', description: 'ไฟล์รูปภาพรถยนต์ที่ต้องการอัปโหลด' }
                },
                required: ['plateNumber', 'brand', 'model']
              }
            }
          }
        },
        responses: {
          201: { description: 'เพิ่มรถยนต์สำเร็จเรียบร้อย' },
          400: { description: 'ข้อมูลไม่ครบถ้วน / จำนวนที่นั่งไม่ถูกต้อง / ป้ายทะเบียนมีในระบบแล้ว' },
          500: { description: 'ไม่สามารถเพิ่มข้อมูลรถได้ / ไฟล์ไม่ใช่รูปภาพ' }
        }
      }
    },
    '/api/vehicles/{id}': {
      get: {
        summary: 'ดึงข้อมูลรถยนต์ 1 คันตาม ID (Get Vehicle By ID)',
        description: '🔒 ต้องใส่ Token - ดึงข้อมูลรถยนต์แบบระบุคัน หากรถถูก Soft Delete หรือไม่มี ID นั้นจะส่ง 404 กลับไป',
        parameters: [
          {
            name: 'id',
            in: 'path',
            required: true,
            description: 'ID ของรถยนต์ที่ต้องการดูข้อมูล',
            schema: { type: 'integer', example: 1 }
          }
        ],
        responses: {
          200: { description: 'ดึงข้อมูลรถคันที่ระบุสำเร็จ' },
          404: { description: 'ไม่พบข้อมูลรถยนต์ในระบบ' },
          500: { description: 'ระบบขัดข้องในการดึงข้อมูลรถ' }
        }
      },
      put: {
        summary: 'แก้ไขข้อมูลรถยนต์ตาม ID (Update Vehicle)',
        description: '🔒 ต้องใส่ Token (เฉพาะ ADMIN) - แก้ไขข้อมูลและสามารถอัปโหลดรูปภาพใหม่เพื่อแทนที่รูปเดิมได้ (ระบบจะลบรูปเก่าออกจาก Server อัตโนมัติ)',
        parameters: [
          {
            name: 'id',
            in: 'path',
            required: true,
            description: 'ID ของรถยนต์ที่ต้องการแก้ไข',
            schema: { type: 'integer', example: 1 }
          }
        ],
        requestBody: {
          required: true,
          content: {
            'multipart/form-data': {
              schema: {
                type: 'object',
                properties: {
                  plateNumber: { type: 'string', example: 'นข-9999', description: 'ป้ายทะเบียนรถยนต์ใหม่' },
                  brand: { type: 'string', example: 'Toyota', description: 'ยี่ห้อรถยนต์' },
                  model: { type: 'string', example: 'Alphard', description: 'รุ่นรถยนต์' },
                  seats: { type: 'integer', example: 7, description: 'จำนวนที่นั่ง' },
                  status: { type: 'string', example: 'AVAILABLE', description: 'สถานะของรถ' },
                  image: { type: 'string', format: 'binary', description: 'ไฟล์รูปภาพใหม่หากต้องการเปลี่ยน' }
                }
              }
            }
          }
        },
        responses: {
          200: { description: 'แก้ไขข้อมูลรถสำเร็จ' },
          400: { description: 'ป้ายทะเบียนใหม่ไปซ้ำกับคันอื่นในระบบ' },
          404: { description: 'ไม่พบข้อมูลรถยนต์ที่ต้องการแก้ไข' },
          500: { description: 'ไม่สามารถแก้ไขข้อมูลรถได้' }
        }
      },
      delete: {
        summary: 'ลบข้อมูลรถแบบ Soft Delete (Delete Vehicle)',
        description: '🔒 ต้องใส่ Token (เฉพาะ ADMIN) - เปลี่ยนสถานะรถเป็น INACTIVE และเซ็ต `isDeleted: true` เพื่อเก็บประวัติการจองในอดีตไว้ **ระบบจะไม่อนุญาตให้ลบหากรถมีคิวจองที่รอใช้งานในอนาคต**',
        parameters: [
          {
            name: 'id',
            in: 'path',
            required: true,
            description: 'ID ของรถยนต์ที่ต้องการลบ',
            schema: { type: 'integer', example: 1 }
          }
        ],
        responses: {
          200: { description: 'ลบข้อมูลรถออกจากระบบสำเร็จ (Soft Delete)' },
          400: { description: 'ไม่สามารถลบรถได้ เนื่องจากมีคิวจองใช้งานในอนาคต' },
          404: { description: 'ไม่พบข้อมูลรถ หรือรถถูกลบไปแล้ว' },
          500: { description: 'ไม่สามารถลบข้อมูลรถได้' }
        }
      }
    }
  }
};

// 📖 เปิดหน้าคู่มือ API
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument));

// ==========================================
// 🔌 เชื่อมต่อ Routes ต่างๆ
// ==========================================

// 🏠 หน้าแรกของ Server (Health Check)
app.get('/', (req, res) => {
  res.status(200).json({
    status: 'success',
    message: 'Welcome to Internal Booking API',
    docs: '/api-docs'
  });
});

app.use('/api', authRoutes);              
app.use('/api/bookings', bookingRoutes);  
app.use('/api/resources', resourceRoutes); 
app.use('/api/rooms', roomRoutes);
app.use('/api', employeeRoutes); 
app.use('/api/vehicles', vehicleRoutes);
app.use('/api/vehicle-bookings', vehicleBookingsRouter);

// ==========================================
// 🏢 Custom API ส่วนขยายจัดการห้องประชุม (Latest Update)
// ==========================================

/**
 * 7. GET /api/rooms
 * สำหรับให้หน้าบ้านดึงรายชื่อห้องประชุมทั้งหมดไปโชว์
 */
app.get('/api/rooms', async (req, res) => {
  try {
    const rooms = await prisma.room.findMany({
      orderBy: { roomName: 'asc' },
    });
    return res.status(200).json(rooms);
  } catch (error) {
    console.error('Error fetching rooms:', error);
    return res.status(500).json({ message: 'เกิดข้อผิดพลาดในการดึงข้อมูลห้องประชุม' });
  }
});

/**
 * 8. POST /api/rooms
 * สำหรับรับข้อมูลจากหน้าบ้าน มาบันทึกลงฐานข้อมูล PostgreSQL ของจริง
 */
app.post('/api/rooms', async (req, res) => {
  const { roomName, capacity, location } = req.body;

  if (!roomName) {
    return res.status(400).json({ message: 'กรุณากรอกชื่อห้องประชุม' });
  }

  try {
    const newRoom = await prisma.room.create({
      data: {
        roomName: roomName,
        capacity: parseInt(capacity, 10) || 0,
        location: location || '',
      }
    });
    return res.status(201).json({ success: true, message: 'สร้างห้องประชุมสำเร็จ', room: newRoom });
  } catch (error) {
    console.error('Error creating room:', error);
    return res.status(500).json({ message: 'ไม่สามารถบันทึกห้องประชุมลงฐานข้อมูลได้' });
  }
});

// ==========================================
// 🚨 Error Handlers
// ==========================================

// Middleware ดักจับ Route ที่ไม่มีในระบบ (404 Not Found)
app.use((req, res, next) => {
  res.status(404).json({
    error: 'Not Found',
    message: `ไม่พบเส้นทาง ${req.originalUrl} ในระบบ กรุณาตรวจสอบ URL อีกครั้ง`
  });
});

// 🛡️ Middleware ดักจับ Error ส่วนกลาง (Centralized Error Handler)
app.use((err, req, res, next) => {
  console.error('🔴 Centralized Error:', err.stack);
  res.status(err.status || 500).json({
    error: "เกิดข้อผิดพลาดภายในระบบหลังบ้าน กรุณาแจ้งผู้ดูแลระบบ",
    developerMessage: err.message
  });
});

// ==========================================
// 🚀 เริ่มต้นทำงาน Server
// ==========================================
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Clean Server is running on http://localhost:${PORT}`);
  console.log(`📖 เปิดดูคู่มือ API ได้ที่ http://localhost:${PORT}/api-docs`);
});