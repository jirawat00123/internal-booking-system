const express = require('express');
const router = express.Router();

// Middlewares
const { authenticateToken } = require('../middlewares/auth');
const uploadMiddleware = require('../middlewares/uploadMiddleware');

// Controller
const attachmentController = require('../controllers/attachmentController');

/**
 * @route   POST /api/attachments/upload
 * @desc    Upload a new file with strict validation
 * @access  Private (JWT Required)
 */

router.post(
  '/upload',
  authenticateToken,
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
  authenticateToken,
  attachmentController.downloadFile
);

/**
 * @route   GET /api/attachments/entity/:entityType/:entityId
 * @desc    Get list of attachments by booking entity
 * @access  Private
 */
router.get(
  '/entity/:entityType/:entityId',
  authenticateToken,                            // 1. ตรวจสอบ JWT
  attachmentController.getAttachmentsByEntity   // 2. เรียก Controller
);

/**
 * @route   DELETE /api/attachments/:id
 * @desc    Delete attachment (DB + Physical File) with ownership validation
 * @access  Private
 */
router.delete(
  '/:id',
  authenticateToken,                            // 1. ตรวจสอบ JWT
  attachmentController.deleteFile               // 2. เรียก Controller 
);

module.exports = router;