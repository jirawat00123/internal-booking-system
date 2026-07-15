const multer = require('multer');
const path = require('path');
const crypto = require('crypto');
const fs = require('fs');

// 1. Storage Config (UUID File Name + Destination)
const uploadDir = path.join(__dirname, '../../../uploads/');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true }); // recursive: true ช่วยสร้างโฟลเดอร์ย่อยทั้งหมดที่ขาดหายไป
  console.log(`[UploadMiddleware] 📁 Auto-created missing directory at: ${uploadDir}`);
}

// 1. Storage Config (UUID File Name + Destination)
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    // ➕ 3. เปลี่ยนมาเรียกใช้ตัวแปร uploadDir แทน เพื่อให้ตรงกับจุดที่เราสร้างโฟลเดอร์ไว้
    cb(null, uploadDir); 
  },
  filename: (req, file, cb) => {
    const extension = path.extname(file.originalname).toLowerCase();
    const uuidFileName = crypto.randomUUID() + extension;
    cb(null, uuidFileName);
  }
});

// 2. Extension & Mime Validation Config
const fileFilter = (req, file, cb) => {
  // Allowed extensions & mime types (Production Standard)
  const allowedMimeTypes = ['image/jpeg', 'image/png', 'application/pdf'];
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
  limits: {
    fileSize: 5 * 1024 * 1024 // File Size Validation: 5MB Limit
  }
});

module.exports = uploadMiddleware;