require('dotenv').config();
const express = require('express');
const path = require('path');
const cors = require('cors');
const { PrismaClient } = require('@prisma/client'); 

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
const prisma = new PrismaClient(); 

// ==========================================
// 🛠️ ตั้งค่า Middleware พื้นฐาน
// ==========================================
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ==========================================
// 📁 เปิดสิทธิ์การอ่านไฟล์ภาพ (Serve Static Files)
// ==========================================
app.use('/uploads', express.static(path.join(process.cwd(), 'uploads')));

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

// [GET] ดึงข้อมูลห้องประชุม
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

// [POST] สร้างห้องประชุม
app.post('/api/rooms', async (req, res) => {
  const { roomName, capacity, location } = req.body;

  if (!roomName) {
    return res.status(400).json({ message: 'กรุณากรอกชื่อห้องประชุม' });
  }

  try {
    const newRoom = await prisma.room.create({
      data: {
        roomName: roomName.trim(),
        capacity: parseInt(capacity, 10) || 0,
        location: location ? location.trim() : '',
      }
    });
    return res.status(201).json({ success: true, message: 'สร้างห้องประชุมสำเร็จ', room: newRoom });
  } catch (error) {
    console.error('Error creating room:', error);
    return res.status(500).json({ message: 'ไม่สามารถบันทึกห้องประชุมลงฐานข้อมูลได้' });
  }
});

// ✨ [PUT] อัปเดต/แก้ไขห้องประชุม (เพิ่มใหม่)
app.put('/api/rooms/:id', async (req, res) => {
  const roomId = parseInt(req.params.id, 10);
  const { roomName, capacity, location, status } = req.body;

  if (isNaN(roomId)) {
    return res.status(400).json({ message: 'ID ห้องประชุมไม่ถูกต้อง' });
  }

  try {
    // เตรียมข้อมูลที่จะอัปเดต (ถ้าไม่ได้ส่งค่ามา จะใช้ค่าเดิม)
    const updateData = {};
    if (roomName !== undefined) updateData.roomName = roomName.trim();
    if (capacity !== undefined) updateData.capacity = parseInt(capacity, 10) || 0;
    if (location !== undefined) updateData.location = location.trim();
    if (status !== undefined) updateData.status = status.trim();

    const updatedRoom = await prisma.room.update({
      where: { id: roomId },
      data: updateData,
    });

    return res.status(200).json({ success: true, message: 'อัปเดตห้องประชุมสำเร็จ', room: updatedRoom });
  } catch (error) {
    console.error('Error updating room:', error);
    // รหัส P2025 ของ Prisma คือ Record to update not found.
    if (error.code === 'P2025') {
      return res.status(404).json({ message: 'ไม่พบห้องประชุมที่ต้องการแก้ไข' });
    }
    return res.status(500).json({ message: 'เกิดข้อผิดพลาดในการแก้ไขห้องประชุม' });
  }
});

// ✨ [DELETE] ลบห้องประชุม (เพิ่มใหม่)
app.delete('/api/rooms/:id', async (req, res) => {
  const roomId = parseInt(req.params.id, 10);

  if (isNaN(roomId)) {
    return res.status(400).json({ message: 'ID ห้องประชุมไม่ถูกต้อง' });
  }

  try {
    await prisma.room.delete({
      where: { id: roomId },
    });
    return res.status(200).json({ success: true, message: 'ลบห้องประชุมสำเร็จ' });
  } catch (error) {
    console.error('Error deleting room:', error);
    if (error.code === 'P2025') {
      return res.status(404).json({ message: 'ไม่พบห้องประชุมที่ต้องการลบ' });
    }
    // ดัก Error กรณีที่ห้องถูกนำไปใช้ใน Booking แล้วลบไม่ได้ (Foreign Key Constraint)
    if (error.code === 'P2003') {
      return res.status(400).json({ message: 'ไม่สามารถลบได้ เนื่องจากห้องนี้มีประวัติการจองอยู่' });
    }
    return res.status(500).json({ message: 'เกิดข้อผิดพลาดในการลบห้องประชุม' });
  }
});

// [GET] รถยนต์ว่าง
app.get('/api/vehicles/available', async (req, res) => {
  try {
    const availableVehicles = await prisma.vehicle.findMany({
      where: { 
        status: 'AVAILABLE',
        isDeleted: false 
      },
      orderBy: { id: 'desc' }
    });
    return res.status(200).json(availableVehicles);
  } catch (error) {
    console.error('Error fetching available vehicles:', error);
    return res.status(500).json({ message: 'เกิดข้อผิดพลาดในการดึงข้อมูลรถยนต์ที่ว่าง' });
  }
});

// [POST] จองรถยนต์
app.post('/api/vehicle-bookings/book', async (req, res) => {
  const { vehicleId, userId, startDate, endDate, purpose, destination, passengers } = req.body;

  if (!vehicleId || !userId || !startDate || !endDate || !purpose) {
    return res.status(400).json({ message: 'ข้อมูลการจองไม่ครบถ้วน กรุณาตรวจสอบอีกครั้ง' });
  }

  try {
    const parsedVehicleId = parseInt(vehicleId, 10);
    const parsedUserId = parseInt(userId, 10);

    // ✨ เพิ่มด่านสกัด: ตรวจสอบว่า Vehicle มีอยู่จริงไหม (แก้บั๊ก P2003 Foreign Key Constraint)
    const vehicleExists = await prisma.vehicle.findUnique({
      where: { id: parsedVehicleId }
    });
    if (!vehicleExists) {
      return res.status(404).json({ message: `ไม่พบรถยนต์รหัส ${parsedVehicleId} ในระบบ (คุณอาจใส่ vehicleId ผิด)` });
    }

    // ✨ เพิ่มด่านสกัด: ตรวจสอบว่า User มีอยู่จริงไหม 
    const userExists = await prisma.user.findUnique({
      where: { id: parsedUserId }
    });
    if (!userExists) {
      return res.status(404).json({ message: `ไม่พบผู้ใช้งานรหัส ${parsedUserId} ในระบบ (คุณอาจใส่ userId ผิด)` });
    }

    const start = new Date(startDate);
    const end = new Date(endDate);

    // 🛡️ ตรวจสอบการทับซ้อนของเวลา (Collision Check)
    const overlappingBooking = await prisma.vehicleBooking.findFirst({
      where: {
        vehicleId: parsedVehicleId,
        status: { notIn: ['CANCELLED', 'REJECTED', 'Cancelled', 'Rejected'] }, 
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

    // 💾 บันทึกการจองลงฐานข้อมูล
    const newBooking = await prisma.vehicleBooking.create({
      data: {
        vehicleId: parsedVehicleId,
        userId: parsedUserId,
        startDatetime: start,
        endDatetime: end,    
        purpose: purpose.trim(),
        destination: destination ? destination.trim() : purpose.trim(), 
        passengers: passengers ? parseInt(passengers, 10) : 1,
        status: 'Pending'
      }
    });

    return res.status(201).json({ success: true, message: 'ส่งคำขอจองรถยนต์สำเร็จ', booking: newBooking });
  } catch (error) {
    console.error('Error creating vehicle booking:', error);
    return res.status(500).json({ message: 'ระบบหลังบ้านขัดข้อง ไม่สามารถบันทึกการจองรถได้', error: error.message });
  }
});

// [GET] ประวัติใช้งานรถยนต์
app.get('/api/vehicle-logs', async (req, res) => {
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
// 🔌 เชื่อมต่อ Routes กลุ่มเดิมที่เหลือ
// ==========================================
app.use('/api', authRoutes);              
app.use('/api/bookings', bookingRoutes);  
app.use('/api/resources', resourceRoutes); 
app.use('/api/rooms', roomRoutes);
app.use('/api', employeeRoutes); 
app.use('/api/vehicles', vehicleRoutes);
app.use('/api/vehicle-bookings', vehicleBookingsRouter);

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
  console.error('🔴 Centralized Error:', err.stack);
  res.status(err.status || 500).json({
    error: "เกิดข้อผิดพลาดภายในระบบหลังบ้าน กรุณาแจ้งผู้ดูแลระบบ",
    developerMessage: err.message
  });
});

// ==========================================
// 🚀 เริ่มต้นทำงาน Server
// ==========================================
const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`🚀 Clean Server is running on http://localhost:${PORT}`);
  console.log(`📖 เปิดดูคู่มือ API ได้ที่ http://localhost:${PORT}/api-docs`);
});