require('dotenv').config();
const express = require('express');
const path = require('path');
const fs = require('fs');
const cors = require('cors');
const { PrismaClient } = require('@prisma/client'); 

// นำเข้า Routes ต่างๆ
const authRoutes = require('./routes/auth');
const bookingRoutes = require('./routes/bookings');
const resourceRoutes = require('./routes/resources');
const roomRoutes = require('./routes/rooms');
const employeeRoutes = require('./routes/employees');
const vehicleRoutes = require('./routes/vehicles');
const vehicleBookingsRouter = require('./routes/vehicleBookings');
const securityRoutes = require('./routes/security');
const attachmentRoutes = require('./routes/attachments');
const calendarRoutes = require('./routes/calendar');
const notificationRoutes = require('./routes/notifications');

// 🚀 นำเข้า Route จัดการ User และ Monitor
const userRoutes = require('./routes/users');
const monitorRoutes = require('./routes/monitor');
const reportRoutes = require('./routes/reports');

const app = express();
const prisma = new PrismaClient(); 

// ==========================================
// 🛠️ ตั้งค่า Middleware พื้นฐาน (ต้องอยู่ก่อน Routes เสมอ)
// ==========================================
app.use(cors({
  origin: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
  credentials: true
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 📝 บันทึก Log ของ Request ที่วิ่งเข้ามาใน Terminal ทุกคำขอ
app.use((req, res, next) => {
  console.log(`[${new Date().toLocaleTimeString()}] ${req.method} ${req.originalUrl} - IP: ${req.ip || req.socket.remoteAddress}`);
  next();
});

// 📖 นำเข้า Swagger
const swaggerUi = require('swagger-ui-express');
// ==========================================
// 🛡️ ดักจับ Error ระดับ Process (ป้องกันเซิร์ฟเวอร์ดับเงียบ)
// ==========================================
process.on('uncaughtException', (err) => {
  console.error('🔴 [Uncaught Exception] พบข้อผิดพลาดร้ายแรงที่ไม่ถูกจัดการ:', err);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('🔴 [Unhandled Rejection] Promise ไม่ถูกจัดการ:', reason);
});

// ==========================================
// 📁 เปิดสิทธิ์การอ่านไฟล์ภาพ (Serve Static Files)
// ==========================================
// ล็อก Path ให้ชี้ตรงไปที่ uploads ของ Container (/app/uploads)
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

// 🟢 เพิ่ม Mapping ตรงสำหรับรููปภาพห้องประชุม (/uploads/rooms) ให้ดึงไฟล์จากโฟลเดอร์ attachments/rooms/images แทน
app.use('/uploads/rooms', express.static(path.normalize('/Internal Booking System/Internal Booking System/attachments/rooms/images')));
app.use('/uploads/rooms', express.static(path.resolve(__dirname, '../attachments/rooms/images')));
app.use('/uploads/rooms', express.static(path.resolve(__dirname, '../../attachments/rooms/images')));

// 🟢 Fallback รองรับ Path เก่า (/uploads/vehicles) ให้ชี้ไปที่โฟลเดอร์จัดเก็บรูปภาพจริง
app.use('/uploads/vehicles', express.static(path.normalize('/Internal Booking System/Internal Booking System/attachments/vehicles/images')));
app.use('/uploads/vehicles', express.static(path.resolve(__dirname, '../attachments/vehicles/images')));
app.use('/uploads/vehicles', express.static(path.resolve(__dirname, '../../attachments/vehicles/images')));

// 🟢 Middleware ตรวจสอบไฟล์ใน /attachments (ย้ายขึ้นมาทำงานก่อน static route เพื่อแก้ไฟล์ภาษาไทยและค้นหารูปภาพ/ใบขับขี่/เอกสาร)
app.use('/attachments', (req, res, next) => {
  const candidateRoots = [
    process.env.UPLOAD_DIR,
    path.normalize('/Internal Booking System/Internal Booking System/attachments'),
    path.normalize('C:/Internal Booking System/Internal Booking System/attachments'),
    path.resolve(__dirname, '../../attachments'),
    path.resolve(__dirname, '../attachments'),
    path.resolve(__dirname, '../../../attachments'),
    path.resolve(__dirname, '../uploads'),
    path.join(process.cwd(), 'attachments'),
    path.join(process.cwd(), 'Internal Booking System/Internal Booking System/attachments'),
    path.join(process.cwd(), 'Internal Booking System/attachments'),
    path.join(process.cwd(), '../attachments'),
  ].filter(Boolean);

  const rawPath = req.path;
  let decodedPath = rawPath;
  try {
    decodedPath = decodeURIComponent(rawPath);
  } catch (e) {}

  for (const rootDir of candidateRoots) {
    const filePathsToTry = [
      path.join(rootDir, decodedPath),
      path.join(rootDir, rawPath),
      path.join(rootDir, decodedPath.replace('/vehicles/documents/', '/vehicles/images/')),
      path.join(rootDir, decodedPath.replace('/vehicles/images/', '/vehicles/documents/')),
      path.join(rootDir, 'vehicles/documents', path.basename(decodedPath)),
      path.join(rootDir, 'vehicles/images', path.basename(decodedPath))
    ];

    for (const filePath of filePathsToTry) {
      if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
        console.log(`[File Found Check] ✅ พบไฟล์จริงที่ Path: ${filePath}`);
        return res.sendFile(path.resolve(filePath));
      }
    }
  }

  console.log(`[File Found Check] ❌ ไม่พบไฟล์สำหรับ URL: ${decodedPath}`);
  next();
});

// 🟢 เพิ่ม Mapping ตรงสำหรับรูปภาพรถยนต์ (/attachments/vehicles/images) พร้อม Fallback ค้นหาใน uploads
app.use('/attachments/vehicles/images', express.static(path.normalize('/Internal Booking System/Internal Booking System/attachments/vehicles/images')));
app.use('/attachments/vehicles/images', express.static(path.join(__dirname, '../attachments/vehicles/images')));
app.use('/attachments/vehicles/images', express.static(path.join(__dirname, '../../attachments/vehicles/images')));
app.use('/attachments/vehicles/images', express.static(path.join(__dirname, '../uploads/vehicles')));
app.use('/attachments/vehicles/images', express.static(path.join(__dirname, '../uploads')));

// 🟢 เพิ่ม Mapping สำหรับเอกสาร พรบ. / ทะเบียน (/attachments/vehicles/documents)
app.use('/attachments/vehicles/documents', express.static(path.normalize('/Internal Booking System/Internal Booking System/attachments/vehicles/documents')));
app.use('/attachments/vehicles/documents', express.static(path.resolve(__dirname, '../../attachments/vehicles/documents')));
app.use('/attachments/vehicles/documents', express.static(path.resolve(__dirname, '../attachments/vehicles/documents')));
app.use('/attachments/vehicles/documents', express.static(path.join(process.cwd(), '../attachments/vehicles/documents')));
app.use('/attachments/vehicles/documents', express.static(path.join(process.cwd(), 'attachments/vehicles/documents')));

// 🟢 เพิ่ม Mapping สำหรับเอกสารใบขับขี่ (/attachments/vehicles/license_driver)
app.use('/attachments/vehicles/license_driver', express.static(path.normalize('/Internal Booking System/Internal Booking System/attachments/vehicles/license_driver')));
app.use('/attachments/vehicles/license_driver', express.static(path.join(__dirname, '../attachments/vehicles/license_driver')));
app.use('/attachments/vehicles/license_driver', express.static(path.join(__dirname, '../../attachments/vehicles/license_driver')));

// 🟢 เพิ่ม Mapping สำหรับรูปการตรวจรับ/ปล่อยรถ (/attachments/vehicles/inspections)
app.use('/attachments/vehicles/inspections', express.static(path.normalize('/Internal Booking System/Internal Booking System/attachments/vehicles/inspections')));
app.use('/attachments/vehicles/inspections', express.static(path.resolve(__dirname, '../../attachments/vehicles/inspections')));
app.use('/attachments/vehicles/inspections', express.static(path.resolve(__dirname, '../attachments/vehicles/inspections')));
app.use('/attachments/vehicles/inspections', express.static(path.join(process.cwd(), '../attachments/vehicles/inspections')));
app.use('/attachments/vehicles/inspections', express.static(path.join(process.cwd(), 'attachments/vehicles/inspections')));

// 🟢 ผูก Path ให้ชี้ตรงไปที่ attachments ของ Container และโฟลเดอร์บน NAS (Absolute Path)
if (process.env.UPLOAD_DIR) {
  app.use('/attachments', express.static(process.env.UPLOAD_DIR));
}
app.use('/attachments', express.static(path.normalize('/Internal Booking System/Internal Booking System/attachments')));
app.use('/attachments', express.static(path.resolve(__dirname, '../../attachments')));
app.use('/attachments', express.static(path.resolve(__dirname, '../attachments')));
app.use('/attachments', express.static(path.join(process.cwd(), '../attachments')));
app.use('/attachments', express.static(path.join(process.cwd(), 'attachments')));
app.use('/documents', express.static(path.join(__dirname, '../documents')));
// ==========================================
// 📑 ตั้งค่าหน้าปกคู่มือ API (Swagger)
// ==========================================
const swaggerDocument = {
  openapi: '3.0.0',
  info: { 
    title: '🏢 Internal Booking API', 
    version: '1.2.0', 
    description: 'คู่มือสำหรับทีม Frontend (อัปเดตระบบ Meeting Room & Vehicle Booking Module พร้อม Audit Logs - รองรับสิทธิ์ USER, ADMIN, GUARD)' 
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
    '/api/rooms': {
      get: { 
        summary: 'ดึงรายชื่อห้องประชุมทั้งหมด (Room List)', 
        security: [],
        responses: { 200: { description: 'สำเร็จ' } } 
      },
      post: {
        summary: 'สร้างห้องประชุมใหม่',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                properties: {
                  roomName: { type: 'string', example: 'ห้องประชุมใหญ่' },
                  capacity: { type: 'integer', example: 20 },
                  location: { type: 'string', example: 'ชั้น 1' }
                },
                required: ['roomName']
              }
            }
          }
        },
        responses: { 201: { description: 'สร้างสำเร็จ' } }
      }
    },
    '/api/rooms/{id}': {
      put: {
        summary: 'แก้ไขข้อมูลห้องประชุม (Edit Room)',
        parameters: [
          { name: 'id', in: 'path', required: true, description: 'ID ของห้องประชุม', schema: { type: 'integer' } }
        ],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                properties: {
                  roomName: { type: 'string', example: 'ห้องประชุม A (อัปเดต)' },
                  capacity: { type: 'integer', example: 30 },
                  location: { type: 'string', example: 'ชั้น 2' },
                  status: { type: 'string', example: 'ว่างพร้อมใช้งาน' }
                }
              }
            }
          }
        },
        responses: {
          200: { description: 'อัปเดตสำเร็จ' },
          404: { description: 'ไม่พบห้องประชุม' },
          500: { description: 'ระบบขัดข้อง' }
        }
      },
      delete: {
        summary: 'ลบห้องประชุม (Delete Room)',
        parameters: [
          { name: 'id', in: 'path', required: true, description: 'ID ของห้องประชุม', schema: { type: 'integer' } }
        ],
        responses: {
          200: { description: 'ลบสำเร็จ' },
          404: { description: 'ไม่พบห้องประชุม' },
          500: { description: 'ระบบขัดข้อง หรือมีรายการจองค้างอยู่' }
        }
      }
    },
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
                  startDatetime: { type: 'string', example: '10:00:00' },
                  endDatetime: { type: 'string', example: '12:00:00' },
                  title: { type: 'string', example: 'ประชุมทีมประจำสัปดาห์' },
                  participants: { type: 'integer', example: 10 }
                },
                required: ['room_id', 'user_id', 'booking_date', 'startDatetime', 'endDatetime', 'title']
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
    '/api/resources/rooms': {
      get: { summary: 'ดึงรายชื่อห้องประชุม (ข้อมูลดิบ)', responses: { 200: { description: 'สำเร็จ' } } }
    },
    '/api/resources/vehicles': {
      get: { summary: 'ดึงรายชื่อรถยนต์บริษัท (ข้อมูลดิบ)', responses: { 200: { description: 'สำเร็จ' } } }
    },
    '/api/vehicles/available': {
      get: {
        summary: 'ดึงข้อมูลรถยนต์ที่ "ว่าง" และพร้อมใช้งาน (Get Available Vehicles)',
        description: '🔒 ต้องใส่ Token - ดึงรายการรถยนต์ที่สถานะเป็น AVAILABLE และไม่ถูกลบออกจากระบบ',
        responses: {
          200: { description: 'ดึงข้อมูลสำเร็จ' }
        }
      }
    },
    '/api/vehicle-bookings/book': {
      post: {
        summary: 'ส่งคำขอจองรถยนต์ (Create Vehicle Booking)',
        description: '🔒 ต้องใส่ Token - ทำการจองรถยนต์ พร้อมระบบ Collision Check ป้องกันการจองช่วงเวลาทับซ้อน',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                properties: {
                  vehicleId: { type: 'integer', example: 1 },
                  userId: { type: 'integer', example: 2 },
                  startDate: { type: 'string', format: 'date-time', example: '2026-07-02T09:00:00Z' },
                  endDate: { type: 'string', format: 'date-time', example: '2026-07-02T15:00:00Z' },
                  purpose: { type: 'string', example: 'ไปพบลูกค้าที่ชลบุรี' },
                  destination: { type: 'string', example: 'ชลบุรี' },
                  passengers: { type: 'integer', example: 3 }
                },
                required: ['vehicleId', 'userId', 'startDate', 'endDate', 'purpose']
              }
            }
          }
        },
        responses: {
          201: { description: 'จองรถยนต์สำเร็จ' },
          409: { description: 'มีการจองรถยนต์คันนี้ในช่วงเวลาดังกล่าวแล้ว' }
        }
      }
    },
    '/api/vehicle-logs': {
      get: {
        summary: 'ดึงบันทึกประวัติรถยนต์ (Audit Logs)',
        description: '🔒 ต้องใส่ Token (ADMIN/GUARD) - ดูประวัติการใช้งานรถ การเข้า-ออก',
        responses: {
          200: { description: 'ดึงประวัติสำเร็จ' }
        }
      }
    },
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
        description: '🔒 ต้องใส่ Token (เฉพาะ ADMIN) - รองรับการอัปโหลดไฟล์รูปภาพ จำกัดขนาดไม่เกิน 5MB',
        responses: {
          201: { description: 'เพิ่มรถยนต์สำเร็จเรียบร้อย' }
        }
      }
    }
  }
};

// 📖 เปิดหน้าคู่มือ API
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument));

// ==========================================
// 🏠 หน้าแรกของ Server (Health Check)
// ==========================================
app.get('/', (req, res) => {
  res.status(200).json({
    status: 'success',
    message: 'Welcome to Internal Booking API',
    docs: '/api-docs'
  });
});

// ==========================================
// 🏢 Custom API overrides (ประกาศก่อน app.use Routers เพื่อป้องกัน Route Conflict)
// ==========================================
const { authenticateToken, isAdmin, requireRole } = require('./middlewares/auth');

// [GET] รถยนต์ว่าง (บังคับใช้ Token)
app.get('/api/vehicles/available', authenticateToken, async (req, res) => {
  try {
    const availableVehicles = await prisma.vehicle.findMany({
      where: { 
        status: 'AVAILABLE',
        isDeleted: false 
      },
      include: {
        documents: {
          include: {
            documentType: true
          }
        }
      },
      orderBy: { id: 'desc' }
    });

    const formattedVehicles = availableVehicles.map(vehicle => {
      const computedName = vehicle.vehicleName || [vehicle.brand, vehicle.model].filter(Boolean).join(' ') || vehicle.plateNumber || 'ไม่ระบุรุ่น';
      const plate = vehicle.plateNumber || vehicle.plate_number || vehicle.licensePlate || 'ไม่ระบุทะเบียน';
      const seatVal = vehicle.capacity || vehicle.seats || vehicle.seatCapacity || 4;

      return {
        ...vehicle,
        name: computedName,
        vehicleName: computedName,
        title: computedName,
        plateNumber: plate,
        plate_number: plate,
        licensePlate: plate,
        capacity: seatVal,
        seats: seatVal,
        seatCapacity: seatVal,
        status: vehicle.status
      };
    });

    return res.status(200).json(formattedVehicles);
  } catch (error) {
    console.error('Error fetching available vehicles:', error);
    return res.status(500).json({ message: 'เกิดข้อผิดพลาดในการดึงข้อมูลรถยนต์ที่ว่าง' });
  }
});

// [POST] จองรถยนต์ (อัปเดตสอดคล้องกับ Enum ใหม่) (บังคับใช้ Token)
app.post('/api/vehicle-bookings/book', authenticateToken, async (req, res) => {
  const { vehicleId, userId, startDate, endDate, purpose, destination, passengers } = req.body;

  if (!vehicleId || !userId || !startDate || !endDate || !purpose) {
    return res.status(400).json({ message: 'ข้อมูลการจองไม่ครบถ้วน กรุณาตรวจสอบอีกครั้ง' });
  }

  try {
    const parsedVehicleId = parseInt(vehicleId, 10);
    const parsedUserId = parseInt(userId, 10);

    if (isNaN(parsedVehicleId) || isNaN(parsedUserId)) {
      return res.status(400).json({ message: 'รูปแบบ vehicleId หรือ userId ไม่ถูกต้อง (ต้องเป็นตัวเลขเท่านั้น)' });
    }

    // 1. ตรวจสอบว่ามีรถยนต์คันนี้ในระบบจริงไหม
    const vehicleExists = await prisma.vehicle.findUnique({
      where: { id: parsedVehicleId }
    });
    if (!vehicleExists) {
      return res.status(404).json({ message: `ไม่พบรถยนต์รหัส ${parsedVehicleId} ในระบบ (คุณอาจใส่ vehicleId ผิด)` });
    }

    // 🔒 เช็กเพิ่มเติม: รถต้องสถานะ ว่าง (AVAILABLE) เท่านั้นถึงจะจองได้
    if (vehicleExists.status !== 'AVAILABLE') {
      return res.status(400).json({ message: 'รถคันนี้ไม่ว่างพร้อมใช้งาน (อาจถูกล็อกคิวไปแล้ว)' });
    }

    // 2. ตรวจสอบว่าผู้ใช้งานมีตัวตนจริงไหม
    const userExists = await prisma.user.findUnique({
      where: { id: parsedUserId }
    });
    if (!userExists) {
      return res.status(404).json({ message: `ไม่พบผู้ใช้งานรหัส ${parsedUserId} ในระบบ (คุณอาจใส่ userId ผิด)` });
    }

    const start = new Date(startDate);
    const end = new Date(endDate);

    // 3. ตรวจสอบคิวรถทับซ้อน (Collision Check)
    const overlappingBooking = await prisma.vehicleBooking.findFirst({
      where: {
        vehicleId: parsedVehicleId,
        status: { notIn: ['CANCELLED', 'REJECTED'] }, 
        OR: [
          { startDatetime: { lt: end }, endDatetime: { gt: start } }
        ]
      },
      select: { id: true } 
    });

    if (overlappingBooking) {
      return res.status(409).json({ 
        message: 'ไม่สามารถจองได้ เนื่องจากรถยนต์คันนี้ถูกจองในช่วงเวลาดังกล่าวแล้ว',
        conflictBookingId: overlappingBooking.id
      });
    }

    // 4. บันทึกใบจองลงตาราง VehicleBooking (ใช้ Enum PENDING ตัวพิมพ์ใหญ่)
    const booking = await prisma.vehicleBooking.create({
      data: {
        vehicleId: parsedVehicleId,
        userId: parsedUserId,
        startDatetime: start,
        endDatetime: end,    
        purpose: purpose.trim(),
        destination: destination ? destination.trim() : purpose.trim(), 
        passengers: passengers ? parseInt(passengers, 10) : 1,
        status: 'PENDING'
      }
    });

    return res.status(201).json({ 
      success: true, 
      message: 'ส่งคำขอจองรถยนต์สำเร็จเรียบร้อยแล้ว', 
      booking: booking 
    });

  } catch (error) {
    console.error('Error creating vehicle booking:', error);
    return res.status(500).json({ message: 'ระบบหลังบ้านขัดข้อง ไม่สามารถบันทึกการจองรถได้', error: error.message });
  }
});

// [GET] ประวัติใช้งานรถยนต์ (เฉพาะ ADMIN และ GUARD)
app.get('/api/vehicle-logs', authenticateToken, requireRole(['ADMIN', 'GUARD']), async (req, res) => {
  try {
    const logs = await prisma.vehicleLog.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100 
    });
    return res.status(200).json(logs);
  } catch (error) {
    console.error('Error fetching vehicle logs:', error);
    return res.status(500).json({ message: 'เกิดข้อผิดพลาดในการดึงข้อมูลประวัติรถยนต์' });
  }
});

// ==========================================
// 🔌 เชื่อมต่อ Routes (เรียงจาก Specific Routes ไปยัง Generic Routes)
// ==========================================
app.use('/api/vehicles', vehicleRoutes);
app.use('/api/vehicle-bookings', vehicleBookingsRouter);
app.use('/api/bookings', bookingRoutes);  
app.use('/api/resources', resourceRoutes); 
app.use('/api/rooms', roomRoutes);
app.use('/api/security', securityRoutes);
app.use('/api/attachments', attachmentRoutes);
app.use('/api/calendar', calendarRoutes);

// 🚀 ผูก Route สำหรับ Users และ Monitor Mode
app.use('/api/users', userRoutes);
app.use('/api/admin/users', userRoutes); // รองรับทั้ง /api/users และ /api/admin/users
app.use('/api/monitor', monitorRoutes);
app.use('/api/reports', reportRoutes);
app.use('/api/notifications', notificationRoutes);

// ⚠️ Generic Routes ดักจับภายหลัง (ลงทะเบียน /api ท้ายสุดเพื่อป้องกัน Route Shadowing)
app.use('/api', authRoutes);              
app.use('/api', employeeRoutes);

// ==========================================
// 🚨 Error Handlers
// ==========================================
app.use((req, res, next) => {
  res.status(404).json({
    error: 'Not Found',
    message: `ไม่พบเส้นทาง ${req.originalUrl} ในระบบ กรุณาตรวจสอบ URL อีกครั้ง`
  });
});

app.use((err, req, res, next) => {
  console.error('\n===== [ERROR] Centralized Error Handler Caught Something! =====');
  console.error('Error Message:', err.message);
  console.error('Stack Trace:', err.stack);
  console.error('=============================================================\n');

  if (res.headersSent) {
    return next(err);
  }

  res.status(err.status || 500).json({
    error: "เกิดข้อผิดพลาดภายในระบบหลังบ้าน กรุณาแจ้งผู้ดูแลระบบ",
    developerMessage: err.message
  });
});
// ==========================================
// 🚀 เริ่มต้นทำงาน Server พร้อมจัดการสถานะพอร์ต
// ==========================================
const PORT = process.env.PORT || 3001;
const server = app.listen(PORT, () => {
  console.log(`🚀 Clean Server is running on http://localhost:${PORT}`);
  console.log(`📖 เปิดดูคู่มือ API ได้ที่ http://localhost:${PORT}/api-docs`);
});

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`🔴 เกิดข้อผิดพลาด: พอร์ต ${PORT} กำลังถูกใช้งานโดยโปรแกรมอื่น!`);
    console.error(`💡 วิธีแก้: ให้เปลี่ยนพอร์ตในไฟล์ .env หรือปิดโปรแกรมที่ใช้พอร์ต ${PORT} อยู่`);
  } else {
    console.error('🔴 เซิร์ฟเวอร์ดับเนื่องจาก:', err.message);
  }
  process.exit(1);
});

// ==========================================
// 🛑 จัดการ Graceful Shutdown (ปิดการเชื่อมต่อ Database อย่างปลอดภัย)
// ==========================================
const shutdown = async () => {
  console.log('🛑 กำลังปิดเซิร์ฟเวอร์อย่างปลอดภัย...');
  await prisma.$disconnect();
  server.close(() => {
    console.log('✅ ปิดการทำงานเซิร์ฟเวอร์และการเชื่อมต่อฐานข้อมูลสำเร็จ');
    process.exit(0);
  });
};

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);