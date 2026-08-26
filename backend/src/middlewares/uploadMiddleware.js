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
    try {
      // รวม URL ทุกช่องทางและแปลงเป็นตัวพิมพ์เล็กเพื่อการตรวจสอบที่ครอบคลุม
      const url = `${req.originalUrl || ''} ${req.baseUrl || ''} ${req.url || ''}`.toLowerCase();

      // กำหนดโฟลเดอร์ปลายทางตาม Route ที่เรียกใช้ (Single Source of Truth)
      let subFolder = '';

      if (url.includes('/rooms')) {
        subFolder = 'rooms/images';
      } else if (url.includes('/vehicle-bookings') || url.includes('/inspections') || url.includes('/security')) {
        const idMatch = url.match(/\/(?:vehicle-bookings|inspections|security)\/(\d+)/i) || url.match(/\/(\d+)\/(?:release|return|complete|out|in|checkout|checkin|check-out)/i);
        const bookingId = req.params?.id || req.params?.bookingId || (idMatch ? idMatch[1] : 'temp');
        
        let type = 'general';
        if (/\/(release|checkout|check-out|out)(?:\/|\?|\s|$)/i.test(url)) {
          type = 'release';
        } else if (/\/(return|complete|checkin|check-in|in)(?:\/|\?|\s|$)/i.test(url)) {
          type = 'return';
        }
        
        subFolder = `vehicles/inspections/${bookingId}/${type}`;
      } else if (url.includes('/vehicles')) {
        subFolder = 'vehicles/images';
      } else {
        subFolder = 'general';
      }

      // จะจัดเก็บเข้าไปใน .../attachments/vehicles/inspections/{bookingId}/{type}
      const dest = path.join(uploadDir, subFolder);

      // ตรวจสอบและสร้าง Sub-folder หากยังไม่มี
      if (!fs.existsSync(dest)) {
        fs.mkdirSync(dest, { recursive: true });
      }

      cb(null, dest);
    } catch (err) {
      cb(err, null);
    }
  },
  filename: (req, file, cb) => {
    const url = `${req.originalUrl || ''} ${req.baseUrl || ''} ${req.url || ''}`.toLowerCase();
    const extension = path.extname(file.originalname).toLowerCase();

    if (url.includes('/vehicle-bookings') || url.includes('/inspections') || url.includes('/security')) {
      let standardName = file.fieldname;
      const fn = file.fieldname.toLowerCase();
      if (['frontimage', 'front', 'frontphoto', 'checkoutfrontphoto', 'returnfrontphoto', 'checkout_front_photo', 'return_front_photo'].includes(fn)) {
        standardName = 'front';
      } else if (['backimage', 'back', 'backphoto', 'checkoutbackphoto', 'returnbackphoto', 'checkout_back_photo', 'return_back_photo'].includes(fn)) {
        standardName = 'back';
      } else if (['mileageimage', 'mileage', 'mileagephoto', 'checkoutmileagephoto', 'returnmileagephoto', 'checkout_mileage_photo', 'return_mileage_photo', 'dashboardimage', 'plateimage'].includes(fn)) {
        standardName = 'mileage';
      }
      // เพิ่ม Unique Suffix ป้องกันปัญหา Cache รูปภาพเดิมค้างบน Browser ของผู้ใช้
      const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
      cb(null, `${standardName}-${uniqueSuffix}${extension}`);
    } else {
      // กำหนด Prefix ตามประเภทของข้อมูล
      let prefix = 'file_';

      if (url.includes('/rooms')) {
        prefix = 'room_';
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