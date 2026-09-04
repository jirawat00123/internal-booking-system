const multer = require('multer');
const path = require('path');
const fs = require('fs');

// 1. Storage Config (Root Upload Directory)
// 💡 ชี้ไปที่ root attachments ให้ตรงกับ Express Static และ Docker Volume
const candidatePaths = [
  process.env.UPLOAD_DIR,
  path.normalize('C:/Internal Booking System/Internal Booking System/attachments'),
  path.normalize('/Internal Booking System/Internal Booking System/attachments'),
  path.resolve(__dirname, '../../../attachments'),
  path.join(process.cwd(), '../attachments'),
  path.join(process.cwd(), 'attachments')
].filter(Boolean);

let uploadDir = null;

for (const candidate of candidatePaths) {
  if (candidate.includes('uploads') || (candidate.includes('backend') && !candidate.endsWith('attachments'))) {
    continue;
  }
  try {
    if (fs.existsSync(candidate)) {
      fs.accessSync(candidate, fs.constants.R_OK | fs.constants.W_OK);
      uploadDir = candidate;
      break;
    }
  } catch (err) {}
}

if (!uploadDir) {
  uploadDir = path.resolve(__dirname, '../../../attachments');
}

if (!fs.existsSync(uploadDir)) {
  try {
    fs.mkdirSync(uploadDir, { recursive: true, mode: 0o777 });
    console.log(`[UploadMiddleware] 📁 Auto-created directory at: ${uploadDir}`);
  } catch (error) {
    console.error(`[UploadMiddleware] ❌ Cannot create directory at ${uploadDir}:`, error.message);
  }
}

// 1. Storage Config (Dynamic Path & File Name)
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    try {
      // รวม URL ทุกช่องทางและแปลงเป็นตัวพิมพ์เล็กเพื่อการตรวจสอบที่ครอบคลุม
      const url = `${req.originalUrl || ''} ${req.baseUrl || ''} ${req.url || ''}`.toLowerCase();
      const fn = (file.fieldname || '').toLowerCase();
      const ext = path.extname(file.originalname || '').toLowerCase();
      const isImageExt = ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.svg', '.heic'].includes(ext);

      // ตรวจสอบว่าเป็นเอกสารหรือ พ.ร.บ. หรือไม่ (จาก URL หรือ Fieldname เพิ่มการตรวจสอบ prb, insurance, compulsory, policy)
      const isDocOrAct = 
        url.includes('/documents') || 
        url.includes('act') || 
        url.includes('pororbor') || 
        url.includes('prb') || 
        url.includes('insurance') || 
        url.includes('compulsory') || 
        fn.includes('act') || 
        fn.includes('pororbor') || 
        fn.includes('prb') || 
        fn.includes('doc') || 
        fn.includes('insurance') || 
        fn.includes('compulsory') || 
        fn.includes('policy') || 
        ['act_file', 'actfile', 'actdocument', 'act_document', 'act', 'act_upload_url', 'act_image', 'act_photo', 'actimage', 'actphoto', 'document', 'doc', 'pororbor', 'pororborfile', 'pororbor_file', 'actfilepath', 'act_file_path', 'actdocumenturl', 'acturl', 'pororborurl', 'prb', 'prb_file', 'compulsory', 'insurance'].includes(fn);

      // กำหนดโฟลเดอร์ปลายทางตาม Route หรือชื่อ Field ที่เรียกใช้ (Single Source of Truth)
      let subFolder = '';

      // ลำดับที่ 0.1: ดักจับไฟล์ พ.ร.บ. / เอกสาร หรือไฟล์ที่ไม่ใช่รูปภาพใน Route /vehicles ลง vehicles/documents
      if (isDocOrAct || (url.includes('/vehicles') && !isImageExt)) {
        subFolder = 'vehicles/documents';
      }
      // ลำดับที่ 0.2: ตรวจสอบไฟล์ใบขับขี่สำหรับการจอง ให้เก็บลงโฟลเดอร์พักไฟล์ temp
      else if (['driverlicenseurl', 'driverlicense', 'licenseimage', 'license', 'attachments'].includes(fn)) {
        subFolder = 'temp';
      }
      // ลำดับที่ 1: ตรวจสอบ Route ของ Inspection/Security/Vehicle-Bookings
      else if (url.includes('/vehicle-bookings') || url.includes('/inspections') || url.includes('/security')) {
        const idMatch = url.match(/\/(?:vehicle-bookings|inspections|security)\/(\d+)/i) || 
                        url.match(/\/(\d+)\/(?:release|return|complete|out|in|checkout|checkin|check-out)/i) ||
                        url.match(/\/(\d+)(?:\/|\?|\s|$)/);
        const bookingId = req.params?.id || req.params?.bookingId || req.query?.bookingId || req.query?.id || req.body?.bookingId || req.body?.id || (idMatch ? idMatch[1] : 'temp');
        
        let type = 'general';
        if (/\/(release|checkout|check-out|out)(?:\/|\?|\s|$)/i.test(url)) {
          type = 'release';
        } else if (/\/(return|complete|checkin|check-in|in)(?:\/|\?|\s|$)/i.test(url)) {
          type = 'return';
        }
        
        subFolder = `vehicles/inspections/${bookingId}/${type}`;
      } else if (url.includes('/rooms')) {
        subFolder = 'rooms/images';
      } else if (url.includes('/vehicles')) {
        subFolder = 'vehicles/images';
      } else {
        subFolder = 'general';
      }

      // จะจัดเก็บเข้าไปใน .../attachments/<subFolder>
      const dest = path.join(uploadDir, subFolder);

      console.log(`[Upload Path Check] 📌 uploadDir ที่เลือกใช้: ${uploadDir}`);
      console.log(`[Upload Path Check] 📁 Destination ปลายทาง: ${dest}`);

      // ตรวจสอบและสร้าง Sub-folder หากยังไม่มีอยู่อัตโนมัติแบบ Recursive
      if (!fs.existsSync(dest)) {
        fs.mkdirSync(dest, { recursive: true, mode: 0o777 });
      }

      cb(null, dest);
    } catch (err) {
      cb(err, null);
    }
  },
  filename: (req, file, cb) => {
    const url = `${req.originalUrl || ''} ${req.baseUrl || ''} ${req.url || ''}`.toLowerCase();
    const fn = (file.fieldname || '').toLowerCase();
    let extension = path.extname(file.originalname || '').toLowerCase();

    // 🟢 ดักจับกรณีอัปโหลดจากกล้อง/มือถือ (Blob) แล้วไม่มีนามสกุลไฟล์แนบมาด้วย
    if (!extension) {
      if (file.mimetype === 'image/png') extension = '.png';
      else if (file.mimetype === 'image/webp') extension = '.webp';
      else if (file.mimetype === 'image/gif') extension = '.gif';
      else if (file.mimetype === 'application/pdf') extension = '.pdf';
      else if (file.mimetype.includes('word') || file.mimetype.includes('officedocument.wordprocessingml')) extension = '.docx';
      else if (file.mimetype.includes('excel') || file.mimetype.includes('officedocument.spreadsheetml')) extension = '.xlsx';
      else extension = '.jpg'; // Default กลับไปเป็น .jpg สำหรับรูปภาพทั่วไป
    }

    if (url.includes('/vehicle-bookings') || url.includes('/inspections') || url.includes('/security')) {
      let standardName = file.fieldname;
      if (['frontimage', 'front', 'frontphoto', 'frontfile', 'checkoutfrontphoto', 'returnfrontphoto', 'returnfrontimage', 'returnfrontfile', 'checkout_front_photo', 'return_front_photo', 'checkout_front_image', 'return_front_image'].includes(fn)) {
        standardName = 'front';
      } else if (['backimage', 'back', 'backphoto', 'backfile', 'checkoutbackphoto', 'returnbackphoto', 'returnbackimage', 'returnbackfile', 'checkout_back_photo', 'return_back_photo', 'checkout_back_image', 'return_back_image'].includes(fn)) {
        standardName = 'back';
      } else if (['mileageimage', 'mileage', 'mileagephoto', 'mileagefile', 'checkoutmileagephoto', 'returnmileagephoto', 'returnmileageimage', 'returnmileagefile', 'checkout_mileage_photo', 'return_mileage_photo', 'checkout_mileage_image', 'return_mileage_image', 'dashboardimage', 'plateimage'].includes(fn)) {
        standardName = 'mileage';
      } else if (['driverlicenseurl', 'driverlicense', 'licenseimage', 'license', 'image', 'file', 'attachment', 'attachments'].includes(fn)) {
        standardName = 'license';
      }
      // เพิ่ม Unique Suffix ป้องกันปัญหา Cache รูปภาพเดิมค้างบน Browser ของผู้ใช้
      const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
      cb(null, `${standardName}-${uniqueSuffix}${extension}`);
    } else {
      // กำหนด Prefix ตามประเภทของข้อมูล
      let prefix = 'file_';

      const isDocOrAct = 
        url.includes('/documents') || 
        url.includes('act') || 
        url.includes('pororbor') || 
        url.includes('prb') || 
        url.includes('insurance') || 
        url.includes('compulsory') || 
        fn.includes('act') || 
        fn.includes('pororbor') || 
        fn.includes('prb') || 
        fn.includes('doc') || 
        fn.includes('insurance') || 
        fn.includes('compulsory') || 
        fn.includes('policy') || 
        ['act_file', 'actfile', 'actdocument', 'act_document', 'act', 'act_upload_url', 'act_image', 'act_photo', 'actimage', 'actphoto', 'document', 'doc', 'pororbor', 'pororborfile', 'pororbor_file', 'actfilepath', 'act_file_path', 'actdocumenturl', 'acturl', 'pororborurl', 'prb', 'prb_file', 'compulsory', 'insurance'].includes(fn);

      if (url.includes('/rooms')) {
        prefix = 'room_';
      } else if (isDocOrAct) {
        prefix = 'act_';
      } else if (url.includes('/vehicles')) {
        prefix = 'vehicle_';
      }

      const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
      cb(null, `${prefix}${uniqueSuffix}${extension}`);
    }
  }
});

// 2. Extension & Mime Validation Config
const fileFilter = (req, file, cb) => {

  console.log('[UploadMiddleware Debug] File received:', file.originalname);
  console.log('[UploadMiddleware Debug] MIME Type:', file.mimetype);

  // อนุญาตให้รองรับทุกนามสกุลและทุกประเภทไฟล์
  cb(null, true);
};

// 3. Upload Middleware Instance
const uploadMiddleware = multer({
  storage: storage,
  fileFilter: fileFilter,
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB
    fieldSize: 10 * 1024 * 1024  // 10MB
  }
});

module.exports = uploadMiddleware;