const multer = require('multer');
const path = require('path');
const fs = require('fs');

// 1. Storage Config (Root Upload Directory)
// 💡 ชี้ไปที่ root attachments ให้ตรงกับ Express Static และ Docker Volume
const uploadDir = path.join(__dirname, '../../../attachments');

if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
  console.log(`[UploadMiddleware] 📁 Auto-created missing directory at: ${uploadDir}`);
}

// 1. Storage Config (Dynamic Path & File Name)
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const url = req.baseUrl || req.originalUrl || '';

    // กำหนดโฟลเดอร์ปลายทางตาม Route ที่เรียกใช้ (Single Source of Truth)
    let subFolder = 'attachments';

    if (url.includes('/rooms')) {
      subFolder = 'rooms/images';
    } else if (url.includes('/vehicles')) {
      subFolder = 'vehicles/images';
    }

    const dest = path.join(uploadDir, subFolder);

    // ตรวจสอบและสร้าง Sub-folder หากยังไม่มี
    if (!fs.existsSync(dest)) {
      fs.mkdirSync(dest, { recursive: true });
    }

    cb(null, dest);
  },
  filename: (req, file, cb) => {
    const url = req.baseUrl || req.originalUrl || '';

    // กำหนด Prefix ตามประเภทของข้อมูล
    let prefix = 'file_';

    if (url.includes('/rooms')) {
      prefix = 'room_';
    } else if (url.includes('/vehicles')) {
      prefix = 'vehicle_';
    }

    const extension = path.extname(file.originalname).toLowerCase();
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);

    cb(null, `${prefix}${uniqueSuffix}${extension}`);
  }
});

// 2. Extension & Mime Validation Config
const fileFilter = (req, file, cb) => {

  console.log('[UploadMiddleware Debug] File received:', file.originalname);
  console.log('[UploadMiddleware Debug] MIME Type:', file.mimetype);
// Allowed extensions & mime types (Production Standard)
  const allowedMimeTypes = ['image/jpeg', 'image/png', 'image/jpg', 'application/pdf', 'application/octet-stream'];
  const allowedExtensions = ['.jpg', '.jpeg', '.png', '.pdf'];
  
  const ext = path.extname(file.originalname).toLowerCase();
  
  const isMimeValid = allowedMimeTypes.includes(file.mimetype);
  const isExtValid = allowedExtensions.includes(ext);

  if (isMimeValid && isExtValid) {
    cb(null, true);
  } else {
    // ปฏิเสธไฟล์ทันทีหากไม่ผ่าน Validation
    cb(new Error('INVALID_FILE_TYPE'), false);
  }
};

// 3. Upload Middleware Instance
const uploadMiddleware = multer({
  storage: storage,
  fileFilter: fileFilter,
});

module.exports = uploadMiddleware;