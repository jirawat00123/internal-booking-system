const { authenticateToken, requireRole } = require('../middlewares/auth'); // 🟢 เพิ่ม requireRole
const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const uploadMiddleware = require('../middlewares/uploadMiddleware');

// 🟢 นำเข้า Controller สำหรับจัดการการจองรถยนต์
const vehicleBookingController = require('../controllers/vehicleBookingController');
const { 
  releaseVehicle, 
  completeVehicleBooking,
  approveVehicleBooking,
  rejectVehicleBooking,
  requestEarlyRelease,
  respondEarlyRelease,
  requestEarlyReturn,
  respondEarlyReturn
} = vehicleBookingController || {};

// Helper ป้องกัน Server Crash กรณี Controller ฟังก์ชันใดฟังก์ชันหนึ่งเป็น undefined
const safeHandler = (fn, name) => typeof fn === 'function' ? fn : (req, res) => res.status(501).json({ success: false, error: `Function ${name} is not implemented` });

// Helper Function: สำหรับลบไฟล์ขยะ (Garbage Collection)
const deleteGarbageFile = (fileOrFiles) => {
  if (!fileOrFiles) return;
  const files = Array.isArray(fileOrFiles) ? fileOrFiles : [fileOrFiles];
  files.forEach(file => {
    const filePath = typeof file === 'string' ? file : file.path;
    if (filePath && fs.existsSync(filePath)) {
      try {
        fs.unlinkSync(filePath);
        console.log(`🗑️ Deleted garbage file: ${filePath}`);
      } catch (e) {
        console.error(`⚠️ Failed to delete garbage file: ${filePath}`, e);
      }
    }
  });
};

// ==========================================
// 🟢 สเตปที่ 1: สร้างการจอง อัปโหลดไฟล์ และ The Brain (เช็กรถ + เช็กคนขับ)
// ==========================================
// 💡 เพิ่ม authenticateToken เพื่อยืนยันตัวตนผู้จองเสมอ
router.post('/', authenticateToken, uploadMiddleware.any(), async (req, res) => {
  const requestFiles = req.files || (req.file ? [req.file] : []);

  try {
    const { vehicleId, destination, passengerCount, passengers, startDatetime, endDatetime, returnDate, purpose, driverType, driverLicenseUrl } = req.body;
    
    // 💡 รองรับทั้ง key แบบเก่า (endDatetime) และแบบใหม่ (returnDate) จาก Frontend
    const finalReturnDate = returnDate || endDatetime;

    const licenseFile = Array.isArray(requestFiles) && requestFiles.length > 0
      ? (requestFiles.find(f => ['driverLicenseUrl', 'driverLicense', 'licenseImage', 'license', 'image', 'file', 'attachment', 'attachments'].includes(f.fieldname)) || requestFiles[0]) 
      : null;

    const normalizeLicensePath = (filePath) => {
      if (!filePath) return null;
      const clean = String(filePath).replace(/\\/g, '/');
      const idx = clean.indexOf('uploads/');
      return idx !== -1 ? '/' + clean.substring(idx) : (clean.startsWith('/') ? clean : '/' + clean);
    };

    const finalDriverLicenseUrl = licenseFile ? normalizeLicensePath(licenseFile.path) : (driverLicenseUrl || null);

// 🛑 1. ตรวจสอบข้อมูลเบื้องต้น
    if (!vehicleId || !startDatetime || !finalReturnDate) {
      deleteGarbageFile(requestFiles);
      return res.status(400).json({
        success: false,
        error: "กรุณากรอกข้อมูลให้ครบถ้วน (รหัสรถ, วันเวลาเริ่มและวันที่สิ้นสุด)"
      });
    }

    const parsedVehicleId = parseInt(vehicleId, 10);
    if (isNaN(parsedVehicleId)) {
      deleteGarbageFile(requestFiles);
      return res.status(400).json({ success: false, error: "รหัสรถยนต์ไม่ถูกต้อง" });
    }

    const startInput = new Date(startDatetime);
    const returnInput = new Date(finalReturnDate);

    if (isNaN(startInput.getTime()) || isNaN(returnInput.getTime())) {
      deleteGarbageFile(requestFiles);
      return res.status(400).json({ success: false, error: "รูปแบบวันที่และเวลาไม่ถูกต้อง" });
    }

    if (returnInput < startInput) {
      deleteGarbageFile(requestFiles);
      return res.status(400).json({
        success: false,
        error: "วันที่และเวลาคืนรถต้องไม่น้อยกว่าวันเวลาเริ่มใช้งาน กรุณาตรวจสอบอีกครั้ง"
      });
    }

    // 🌟 Business Rule: ปรับ Expected Return Date ให้เป็นเวลาสิ้นวัน (23:59:59.999) 
    // เพื่อครอบคลุมการจองตลอดทั้งวันที่ผู้ใช้เลือก (ระบบชนวัน ไม่ใช่ชนเวลา)
    const expectedReturnDate = new Date(returnInput);
    expectedReturnDate.setHours(23, 59, 59, 999);

    // 🛑 1.1 ตรวจสอบความถูกต้องของวันเวลา
    if (expectedReturnDate <= startInput) {
      deleteGarbageFile(requestFiles);
      return res.status(400).json({
        success: false,
        error: "วันที่คืนรถต้องมากกว่าหรือเป็นวันเดียวกับวันที่เริ่มใช้งาน กรุณาตรวจสอบอีกครั้ง"
      });
    }

    // 💡 รองรับทั้ง key แบบเก่าและใหม่ที่ Flutter ส่งมา
    let parsedPassengers = parseInt(passengers || passengerCount || 1, 10);

    // 👥 แปลงข้อมูลผู้โดยสาร (รองรับทั้ง Array และ JSON String)
    let passengerList = [];
    
    // ดักจับ Key ที่เป็นไปได้ทั้งหมดจาก Flutter รวมถึง FormData
    const targetKeys = ['passengers', 'passengerNames', 'passengerDetails', 'vehicleBookingPassengers'];
    targetKeys.forEach(key => {
      const val = req.body[key];
      if (val) {
        if (typeof val === 'string') {
          try {
            const parsed = JSON.parse(val);
            if (Array.isArray(parsed)) passengerList.push(...parsed);
            else if (isNaN(val)) passengerList.push(val);
          } catch (e) {
            if (val.includes(',')) passengerList.push(...val.split(','));
            else if (isNaN(val)) passengerList.push(val);
          }
        } else if (Array.isArray(val)) {
          passengerList.push(...val);
        }
      }
    });

    // ดักจับกรณีส่งมาเป็น Array index ผ่าน FormData (เช่น passengers[0])
    const formDataKeys = Object.keys(req.body).filter(k => 
      k.startsWith('passengers[') || k === 'passengers[]' ||
      k.startsWith('passengerNames[') || k === 'passengerNames[]' ||
      k.startsWith('passengerDetails[') || k === 'passengerDetails[]' ||
      k.startsWith('vehicleBookingPassengers[') || k === 'vehicleBookingPassengers[]'
    );
    if (formDataKeys.length > 0) {
      formDataKeys.forEach(k => {
        const val = req.body[k];
        if (Array.isArray(val)) passengerList.push(...val);
        else passengerList.push(val);
      });
    }

    // ปรับจำนวนผู้โดยสารให้สอดคล้องกับรายชื่อที่จับได้จริง ป้องกัน Error หากตัวเลขน้อยกว่า
    if (passengerList.length > parsedPassengers) {
      parsedPassengers = passengerList.length;
    }
    
    // 👤 2. ดึง User ID จาก Token ที่ผ่านการตรวจสอบแล้ว (มั่นใจได้ว่าถูกคน 100%)
    const finalUserId = parseInt(req.user.userId || req.user.id, 10); // 💡 รองรับทั้ง userId และ id ป้องกัน Token ผิดรูปแบบ

    if (!finalUserId || isNaN(finalUserId)) {
      deleteGarbageFile(requestFiles);
      return res.status(401).json({ success: false, error: "ไม่พบสิทธิ์ผู้ใช้งาน กรุณาล็อกอินใหม่" });
    }

    // 🧠 3. The Brain & Transaction (รวมการเช็กคิวและล็อกสถานะรถเข้าด้วยกัน)
    const newBooking = await prisma.$transaction(async (tx) => {
      
      // 3.1 ตรวจสอบรถยนต์ว่ามีในระบบ และไม่อยู่ในสถานะงดใช้งาน/ส่งซ่อม
      const vehicle = await tx.vehicle.findFirst({
        where: { id: parsedVehicleId, isDeleted: false }
      });

      if (!vehicle) throw new Error('NOT_FOUND');
      if (['MAINTENANCE', 'UNAVAILABLE', 'DISABLED'].includes(vehicle.status)) throw new Error('NOT_AVAILABLE');

      // 3.2 ตรวจสอบคิวรถทับซ้อน (Collision Detection: ยึดเวลาสิ้นวันเป็นหลัก)
      const overlappingVehicle = await tx.vehicleBooking.findFirst({
        where: {
          vehicleId: parsedVehicleId,
          status: { notIn: ["CANCELLED", "COMPLETED", "REJECTED"] },
          startDatetime: { lt: expectedReturnDate },
          endDatetime: { gt: startInput }
        }
      });

      if (overlappingVehicle) throw new Error('OVERLAP');
      
      const createdBooking = await tx.vehicleBooking.create({
        data: {
          vehicleId: parsedVehicleId,
          userId: finalUserId,
          destination: destination || 'ไม่ระบุเป้าหมาย',
          passengers: parsedPassengers,
          startDatetime: startInput,
          endDatetime: expectedReturnDate, // บันทึกเวลาที่ปัดเป็น 23:59:59 ลง Database
          purpose: purpose || 'ใช้งานรถยนต์ของบริษัท',
          driverType: driverType || 'ขับขี่เอง',
          driverLicenseUrl: finalDriverLicenseUrl,
          status: 'PENDING'
        }
      });

      // 👥 บันทึกรายชื่อผู้โดยสารลงตาราง vehicle_booking_passengers
      if (Array.isArray(passengerList) && passengerList.length > 0) {
        const passengerData = passengerList.map(p => {
          if (typeof p === 'object' && p !== null) {
            return {
              bookingId: createdBooking.id,
              fullName: p.fullName || p.passengerName || p.name || 'ไม่ระบุชื่อ',
              employeeId: p.employeeId ? parseInt(p.employeeId, 10) : null
            };
          }
          return {
            bookingId: createdBooking.id,
            fullName: String(p).trim(),
            employeeId: null
          };
        }).filter(p => p.fullName.length > 0);

        if (passengerData.length > 0) {
          await tx.vehicleBookingPassenger.createMany({
            data: passengerData
          });
        }
      }

      return createdBooking;
    });

    // 📎 4. บันทึกข้อมูลไฟล์แนบ (ถ้ามีการอัปโหลด)
    const uploadedFile = licenseFile || (requestFiles.length > 0 ? requestFiles[0] : null);
    if (uploadedFile) {
      try {
        const userObj = await prisma.user.findUnique({
          where: { id: finalUserId },
          include: { employee: true }
        });
        const rawUserName = req.user?.username || req.user?.name || userObj?.employee?.fullName || `user_${finalUserId}`;
        const cleanUserName = String(rawUserName).replace(/[^a-zA-Z0-9_\u0E00-\u0E7F]/g, '_');
        const fileExt = path.extname(uploadedFile.originalname || '').toLowerCase() || '.png';
        const timestamp = Math.floor(Date.now() / 1000);
        const newFileName = `booking_${newBooking.id}_${cleanUserName}_${timestamp}${fileExt}`;

        const uploadBaseDir = process.env.UPLOAD_DIR || path.resolve(__dirname, '../../../attachments');
        const licenseDir = path.join(uploadBaseDir, 'vehicles/license_driver');

        if (!fs.existsSync(licenseDir)) {
          fs.mkdirSync(licenseDir, { recursive: true, mode: 0o777 });
        }

        const destPath = path.join(licenseDir, newFileName);
        fs.copyFileSync(uploadedFile.path, destPath);
        try { fs.chmodSync(destPath, 0o777); } catch (e) {}

        const relativePath = `/attachments/vehicles/license_driver/${newFileName}`;

        await prisma.vehicleBooking.update({
          where: { id: newBooking.id },
          data: { driverLicenseUrl: relativePath }
        });
        newBooking.driverLicenseUrl = relativePath;

        await prisma.attachment.create({
          data: {
            entityType: "VEHICLE_BOOKING",
            entityId: newBooking.id,
            fileName: newFileName,
            filePath: relativePath,
            fileType: uploadedFile.mimetype,
            uploadedBy: { connect: { id: finalUserId } },
            bookingVehicle: { connect: { id: newBooking.id } }
          }
        });
      } catch (attachError) {
        console.error("⚠️ Attachment saving warning:", attachError);
      }
    }

    return res.status(201).json({
      success: true,
      message: "บันทึกคำขอจองรถยนต์และล็อกคิวรถเรียบร้อยแล้ว รอการอนุมัติ",
      data: newBooking
    });

  } catch (error) {
    deleteGarbageFile(requestFiles);
    console.error("🔴 Create Vehicle Booking Error:", error);
    
    if (error.message === 'OVERLAP') return res.status(409).json({ success: false, error: "รถคันนี้มีการจองในช่วงเวลาดังกล่าวแล้ว กรุณาเลือกช่วงเวลาอื่น" });
    if (error.message === 'NOT_FOUND') return res.status(404).json({ success: false, error: "ไม่พบข้อมูลรถยนต์ในระบบ" });
    if (error.message === 'NOT_AVAILABLE') return res.status(400).json({ success: false, error: "รถคันนี้ไม่ว่างพร้อมใช้งาน (อาจถูกล็อกคิวไปแล้ว)" });

    return res.status(500).json({ success: false, error: "เกิดข้อผิดพลาดในการประมวลผล", developerMessage: error.message });
  }
});

// ==========================================
// 🕒 ดึงประวัติการจองของตนเอง (GET /history)
// ==========================================
router.get('/history', async (req, res) => {
  try {
    const userId = parseInt(req.query.userId, 10);

    if (!userId || isNaN(userId)) {
      return res.status(400).json({ success: false, error: "กรุณาระบุ userId ที่ถูกต้อง" });
    }

    const historyBookings = await prisma.vehicleBooking.findMany({
      where: { userId: userId },
      include: {
        vehicle: {
          include: {
            documents: {
              include: {
                documentType: true
              }
            }
          }
        },
        user: { include: { employee: true } },
        passengerDetails: true,
        attachments: true
      },
      orderBy: { id: 'desc' }
    });

    // 🟢 Map ส่งกลับไปทั้งสองคีย์ พร้อมสกัด URL เอกสาร พ.ร.บ. และรายชื่อผู้โดยสาร ส่งให้ Frontend
    const mappedHistoryBookings = historyBookings.map(booking => {
      const actDoc = booking.vehicle?.documents?.find(doc => {
        const docTypeId = doc.documentTypeId || doc.document_type_id;
        const docTypeName = doc.documentType?.name || doc.name || doc.title || '';
        const docTypeKey = doc.documentType?.key || doc.type || '';
        return docTypeId === 1 || 
               docTypeName.includes('พ.ร.บ') || 
               docTypeName.includes('พรบ') || 
               docTypeName.toUpperCase().includes('ACT') ||
               docTypeKey.toUpperCase().includes('ACT');
      });
      let actUrl = actDoc ? (actDoc.uploadUrl || actDoc.upload_url || actDoc.filePath || actDoc.file_path || actDoc.url || null) : null;
      if (actUrl && (actUrl.startsWith('/uploads/') || actUrl.startsWith('/attachments/'))) {
        if (!actUrl.startsWith('/attachments/vehicles/documents/')) {
          actUrl = '/attachments/vehicles/documents/' + path.basename(actUrl);
        }
      }

      const vehicleWithAct = booking.vehicle ? {
        ...booking.vehicle,
        actUploadUrl: actUrl,
        act_upload_url: actUrl,
        actUrl: actUrl,
        act_url: actUrl,
        actFilePath: actUrl,
        act_file_path: actUrl,
        pororborUrl: actUrl
      } : booking.vehicle;

      const passengerNames = (booking.passengerDetails || [])
        .map(p => typeof p === 'object' && p !== null ? (p.fullName || p.passengerName || p.name || '') : String(p))
        .filter(name => name.trim().length > 0);

      return {
        ...booking,
        userName: booking.user?.employee?.fullName || booking.user?.username || '-',
        vehicle: vehicleWithAct,
        actUploadUrl: actUrl,
        act_upload_url: actUrl,
        actUrl: actUrl,
        act_url: actUrl,
        actFilePath: actUrl,
        act_file_path: actUrl,
        pororborUrl: actUrl,
        passengerNames: passengerNames.length > 0 ? passengerNames : (booking.passengerNames || []),
        endDatetime: booking.endDatetime,
        returnDate: booking.endDatetime
      };
    });

    return res.status(200).json({
      success: true,
      count: mappedHistoryBookings.length,
      data: mappedHistoryBookings
    });
  } catch (error) {
    console.error("🔴 Get History Error:", error);
    return res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลประวัติการจองได้" });
  }
});

// ==========================================
// 🔍 ดึงรายละเอียดการจองรายตัว (GET /:id)
// ==========================================
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const bookingId = parseInt(req.params.id, 10);
    if (isNaN(bookingId)) {
      return res.status(400).json({ success: false, error: "รหัสการจองไม่ถูกต้อง" });
    }

    const booking = await prisma.vehicleBooking.findUnique({
      where: { id: bookingId },
      include: {
        vehicle: {
          include: {
            documents: {
              include: {
                documentType: true
              }
            }
          }
        },
        user: { include: { employee: true } },
        passengerDetails: true,
        attachments: true
      }
    });

    if (!booking) {
      return res.status(404).json({ success: false, error: "ไม่พบข้อมูลการจองนี้" });
    }

    // 🟢 ค้นหาสถานะการขอรับรถก่อนเวลาล่าสุดจาก AuditLog
    const latestEarlyRequest = await prisma.auditLog.findFirst({
      where: {
        module: 'VEHICLE_BOOKING',
        entityId: bookingId,
        action: { in: ['EARLY_RELEASE_REQUESTED', 'EARLY_RELEASE_CONSENT_GRANTED', 'EARLY_RELEASE_CONSENT_DENIED'] }
      },
      orderBy: { createdAt: 'desc' }
    });

    // 🟢 ค้นหาสถานะการขอคืนรถก่อนเวลาล่าสุดจาก AuditLog
    const latestEarlyReturnRequest = await prisma.auditLog.findFirst({
      where: {
        module: 'VEHICLE_BOOKING',
        entityId: bookingId,
        action: { in: ['EARLY_RETURN_REQUESTED', 'EARLY_RETURN_CONSENT_GRANTED', 'EARLY_RETURN_CONSENT_DENIED'] }
      },
      orderBy: { createdAt: 'desc' }
    });

    // 🟢 สกัดไฟล์ พ.ร.บ. จาก vehicle.documents
    const actDoc = booking.vehicle?.documents?.find(doc => {
      const docTypeId = doc.documentTypeId || doc.document_type_id;
      const docTypeName = doc.documentType?.name || doc.name || doc.title || '';
      const docTypeKey = doc.documentType?.key || doc.type || '';
      return docTypeId === 1 || 
             docTypeName.includes('พ.ร.บ') || 
             docTypeName.includes('พรบ') || 
             docTypeName.toUpperCase().includes('ACT') ||
             docTypeKey.toUpperCase().includes('ACT');
    });
    let actUrl = actDoc ? (actDoc.uploadUrl || actDoc.upload_url || actDoc.filePath || actDoc.file_path || actDoc.url || null) : null;
    if (actUrl && (actUrl.startsWith('/uploads/') || actUrl.startsWith('/attachments/'))) {
      if (!actUrl.startsWith('/attachments/vehicles/documents/')) {
        actUrl = '/attachments/vehicles/documents/' + path.basename(actUrl);
      }
    }

    const vehicleWithAct = booking.vehicle ? {
      ...booking.vehicle,
      actUploadUrl: actUrl,
      act_upload_url: actUrl,
      actUrl: actUrl,
      act_url: actUrl,
      actFilePath: actUrl,
      act_file_path: actUrl,
      pororborUrl: actUrl
    } : booking.vehicle;

    const passengerNames = (booking.passengerDetails || [])
      .map(p => typeof p === 'object' && p !== null ? (p.fullName || p.passengerName || p.name || '') : String(p))
      .filter(name => name.trim().length > 0);

    // 🟢 Map ส่งกลับไปทั้งสองคีย์ เพื่อให้ Frontend เก่าและใหม่ทำงานได้ปกติ พร้อมแนบสถานะ Early Release และ Early Return
    const mappedBooking = {
      ...booking,
      userName: booking.user?.employee?.fullName || booking.user?.username || '-',
      vehicle: vehicleWithAct,
      actUploadUrl: actUrl,
      act_upload_url: actUrl,
      actUrl: actUrl,
      act_url: actUrl,
      actFilePath: actUrl,
      act_file_path: actUrl,
      pororborUrl: actUrl,
      passengerNames: passengerNames.length > 0 ? passengerNames : (booking.passengerNames || []),
      endDatetime: booking.endDatetime,
      returnDate: booking.endDatetime,
      earlyReleaseStatus: latestEarlyRequest ? latestEarlyRequest.action : null,
      isEarlyReleaseRequested: latestEarlyRequest?.action === 'EARLY_RELEASE_REQUESTED',
      earlyReturnStatus: latestEarlyReturnRequest ? latestEarlyReturnRequest.action : null,
      isEarlyReturnRequested: latestEarlyReturnRequest?.action === 'EARLY_RETURN_REQUESTED'
    };

    return res.status(200).json({
      success: true,
      data: mappedBooking
    });
  } catch (error) {
    console.error("🔴 Get Booking By ID Error:", error);
    return res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลรายละเอียดการจองได้" });
  }
});

// ==========================================
// 🚗 ดึงรายการประวัติการจองรถยนต์ทั้งหมด (GET /)
// ==========================================
router.get('/', authenticateToken, async (req, res) => {
  try {
    const bookings = await prisma.vehicleBooking.findMany({
      include: {
        vehicle: {
          include: {
            documents: {
              include: {
                documentType: true
              }
            }
          }
        },
        user: { include: { employee: true } },
        passengerDetails: true
      },
      orderBy: { id: 'desc' },
      take: 100
    });

    // 🟢 Map ส่งกลับไปทั้งสองคีย์ พร้อมสกัด URL เอกสาร พ.ร.บ. และรายชื่อผู้โดยสาร ส่งให้ Frontend
    const mappedBookings = bookings.map(booking => {
      const actDoc = booking.vehicle?.documents?.find(doc => {
        const docTypeId = doc.documentTypeId || doc.document_type_id;
        const docTypeName = doc.documentType?.name || doc.name || doc.title || '';
        const docTypeKey = doc.documentType?.key || doc.type || '';
        return docTypeId === 1 || 
               docTypeName.includes('พ.ร.บ') || 
               docTypeName.includes('พรบ') || 
               docTypeName.toUpperCase().includes('ACT') ||
               docTypeKey.toUpperCase().includes('ACT');
      });
      let actUrl = actDoc ? (actDoc.uploadUrl || actDoc.upload_url || actDoc.filePath || actDoc.file_path || actDoc.url || null) : null;
      if (actUrl && (actUrl.startsWith('/uploads/') || actUrl.startsWith('/attachments/'))) {
        if (!actUrl.startsWith('/attachments/vehicles/documents/')) {
          actUrl = '/attachments/vehicles/documents/' + path.basename(actUrl);
        }
      }

      const vehicleWithAct = booking.vehicle ? {
        ...booking.vehicle,
        actUploadUrl: actUrl,
        act_upload_url: actUrl,
        actUrl: actUrl,
        act_url: actUrl,
        actFilePath: actUrl,
        act_file_path: actUrl,
        pororborUrl: actUrl
      } : booking.vehicle;

      const passengerNames = (booking.passengerDetails || [])
        .map(p => typeof p === 'object' && p !== null ? (p.fullName || p.passengerName || p.name || '') : String(p))
        .filter(name => name.trim().length > 0);

      return {
        ...booking,
        userName: booking.user?.employee?.fullName || booking.user?.username || '-',
        vehicle: vehicleWithAct,
        actUploadUrl: actUrl,
        act_upload_url: actUrl,
        actUrl: actUrl,
        act_url: actUrl,
        actFilePath: actUrl,
        act_file_path: actUrl,
        pororborUrl: actUrl,
        passengerNames: passengerNames.length > 0 ? passengerNames : (booking.passengerNames || []),
        endDatetime: booking.endDatetime,
        returnDate: booking.endDatetime
      };
    });

    return res.status(200).json({
      success: true,
      count: mappedBookings.length,
      data: mappedBookings
    });
  } catch (error) {
    console.error("🔴 Get Vehicle Bookings Error:", error);
    return res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลรายการจองรถยนต์ได้" });
  }
});

// ==========================================
// 🟡 ยกเลิกการจองรถยนต์ (PATCH /:id/cancel)
// ==========================================
router.patch('/:id/cancel', authenticateToken, async (req, res) => {
  try {
    const bookingId = parseInt(req.params.id, 10);
    if (isNaN(bookingId)) {
      return res.status(400).json({ success: false, error: "รหัสการจองไม่ถูกต้อง" });
    }

    const bookingExists = await prisma.vehicleBooking.findUnique({
      where: { id: bookingId }
    });

    if (!bookingExists) {
      return res.status(404).json({ success: false, error: `ไม่พบรายการจองรหัส #${bookingId} ในระบบ` });
    }

    // 🛡️ เช็กสิทธิ์ข้อ 1: GUARD และ SECURITY ดูประวัติรถได้อย่างเดียว ไม่มีสิทธิ์ยกเลิก
    if (req.user.role === 'GUARD' || req.user.role === 'SECURITY') {
      return res.status(403).json({ success: false, error: "คุณไม่มีสิทธิ์ยกเลิกการจอง" });
    }

    // 🛡️ เช็กสิทธิ์ข้อ 2: พนักงานทั่วไป (USER) ยกเลิกได้เฉพาะรายการที่ตัวเองเป็นคนจองเท่านั้น
    // (ADMIN จะหลุดรอดเงื่อนไขนี้ไป ทำให้ยกเลิกของใครก็ได้ตาม Requirement)
    const currentUserId = parseInt(req.user.userId || req.user.id, 10);
    if (req.user.role === 'USER' && bookingExists.userId !== currentUserId) {
      return res.status(403).json({ success: false, error: "คุณไม่มีสิทธิ์ยกเลิกการจองของผู้อื่น" });
    }

    if (bookingExists.status === "CANCELLED" || bookingExists.status === "Cancelled") {
      return res.status(400).json({ success: false, error: "รายการนี้ถูกยกเลิกไปแล้ว" });
    }

    const updatedBooking = await prisma.vehicleBooking.update({
      where: { id: bookingId },
      data: { status: "CANCELLED" }
    });

    return res.status(200).json({
      success: true,
      message: "ยกเลิกการจองเรียบร้อยแล้ว",
      data: updatedBooking
    });

  } catch (error) {
    console.error("🔴 Cancel Vehicle Booking Error:", error);
    return res.status(500).json({ success: false, error: "เกิดข้อผิดพลาดในการยกเลิกรายการจอง" });
  }
});

// ==========================================
// 🚙 บันทึกการปล่อยรถออก (PUT /:id/release) - รปภ. ถ่ายรูปหน้ารถและเลขไมล์
// ==========================================
router.put('/:id/release', authenticateToken, requireRole(['ADMIN', 'GUARD', 'SECURITY']), uploadMiddleware.any(), safeHandler(releaseVehicle, 'releaseVehicle'));

router.post('/:id/release', authenticateToken, requireRole(['ADMIN', 'GUARD', 'SECURITY']), uploadMiddleware.any(), safeHandler(releaseVehicle, 'releaseVehicle'));

// ==========================================
// 🏁 บันทึกการเสร็จสิ้นการใช้งานรถ (PUT /:id/complete)
// ==========================================
router.put('/:id/complete', authenticateToken, uploadMiddleware.any(), safeHandler(completeVehicleBooking, 'completeVehicleBooking'));

// ==========================================
// 🔄 บันทึกการรับรถคืน (PUT /:id/return) - รองรับรูปถ่ายตอนคืนรถและปรับสถานะรถว่าง
// ==========================================
router.put('/:id/return', authenticateToken, uploadMiddleware.any(), safeHandler(completeVehicleBooking, 'completeVehicleBooking'));

router.post('/:id/return', authenticateToken, uploadMiddleware.any(), safeHandler(completeVehicleBooking, 'completeVehicleBooking'));

// ==========================================
// 🟢 อนุมัติการจองรถยนต์ (POST /:id/approve)
// ==========================================
router.post('/:id/approve', authenticateToken, requireRole(['ADMIN']), safeHandler(approveVehicleBooking, 'approveVehicleBooking'));

// ==========================================
// 🔴 ปฏิเสธการจองรถยนต์ (POST /:id/reject)
// ==========================================
router.post('/:id/reject', authenticateToken, requireRole(['ADMIN']), safeHandler(rejectVehicleBooking, 'rejectVehicleBooking'));

// ==========================================
// 🟢 ส่งคำขอรับรถก่อนเวลาให้ผู้จอง (POST /:id/early-request)
// ==========================================
router.post('/:id/early-request', authenticateToken, safeHandler(requestEarlyRelease || vehicleBookingController.requestEarlyRelease, 'requestEarlyRelease'));

// ==========================================
// 🟢 ผู้จองตอบรับหรือปฏิเสธคำขอรับรถก่อนเวลา (POST /:id/early-respond)
// ==========================================
router.post('/:id/early-respond', authenticateToken, safeHandler(respondEarlyRelease || vehicleBookingController.respondEarlyRelease, 'respondEarlyRelease'));

// ==========================================
// 🟢 ส่งคำขอคืนรถก่อนเวลาให้ผู้จอง (POST /:id/early-return-request)
// ==========================================
router.post('/:id/early-return-request', authenticateToken, safeHandler(requestEarlyReturn || vehicleBookingController.requestEarlyReturn, 'requestEarlyReturn'));

// ==========================================
// 🟢 ผู้จองตอบรับหรือปฏิเสธคำขอคืนรถก่อนเวลา (POST /:id/early-return-respond)
// ==========================================
router.post('/:id/early-return-respond', authenticateToken, safeHandler(respondEarlyReturn || vehicleBookingController.respondEarlyReturn, 'respondEarlyReturn'));

module.exports = router;