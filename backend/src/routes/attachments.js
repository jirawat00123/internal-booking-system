const express = require('express');
const router = express.Router();

// Middlewares
// (สมมติว่าไฟล์ auth.js export middleware function ออกมาโดยตรง หรือต้อง destructure ตามของเดิมที่คุณมี)
const { authenticateToken } = require('../middlewares/auth');
const uploadMiddleware = require('../middlewares/uploadMiddleware');

// Controller
const attachmentController = require('../controllers/attachmentController');

/**
 * @route   POST /api/attachments/upload
 * @desc    Upload a new file with strict validation
 * @access  Private (JWT Required)
 */
// ตัวอย่างสมมติว่าฟังก์ชันในระบบของคุณชื่อ verifyToken
const { verifyToken } = require('../middlewares/auth'); 

// ...

router.post(
  '/upload',
  authenticateToken,                // <--- เปลี่ยนเป็น Function ที่ดึงมา
  uploadMiddleware.single('file'),  
  attachmentController.uploadFile   
);

/**
 * @route   GET /api/attachments/:id
 * @desc    Securely stream file content with Ownership/Role validation
 * @access  Private (JWT Required)
 */
router.get(
  '/:id',
  authenticateToken,                // <--- เปลี่ยนเป็น Function ที่ดึงมา
  attachmentController.downloadFile 
);

module.exports = router;