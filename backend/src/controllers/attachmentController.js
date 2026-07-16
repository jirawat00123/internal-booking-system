const path = require('path');
const attachmentService = require('../services/attachmentService');

/**
 * Handle File Upload
 */
const uploadFile = async (req, res) => {
  try {
    // 1. Validate Middleware Input
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded or invalid file type' });
    }

    const { entityType, entityId } = req.body;
    if (!entityType || !entityId) {
      return res.status(400).json({ error: 'entityType and entityId are required' });
    }

    // 2. Get User from JWT (Assumption: req.user was set by auth middleware)
    const userId = req.user.userId;

    // 3. Forward to Core Service
    const attachment = await attachmentService.createAttachmentRecord(
      req.file,
      entityType,
      entityId,
      userId
    );

    return res.status(201).json({
      message: 'File uploaded successfully',
      data: attachment
    });

  } catch (error) {
    console.error('[AttachmentController] Upload Error:', error);
    return res.status(500).json({ error: error.message || 'Internal server error' });
  }
};

/**
 * Handle Secure File Streaming (No express.static)
 */
const downloadFile = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.userId;
    const roleId = req.user.roleId;

    // 1. Get DB Record & IDOR Check via Service
    const attachment = await attachmentService.getAttachmentById(id, userId, roleId);

    // 2. Path Traversal Protection
    const baseUploadDir = path.join(__dirname, '../../../uploads/');
    const absolutePath = path.resolve(baseUploadDir, attachment.filePath);

    // Zero Trust: ตรวจสอบอีกครั้งว่า Path ปลายทางยังคงอยู่ภายใต้ uploads/ (ป้องกัน UUID Injection หรือ ../)
    if (!absolutePath.startsWith(path.resolve(baseUploadDir))) {
      return res.status(403).json({ error: 'Forbidden file access (Path Error)' });
    }

    // 3. File Delivery (Streaming)
    res.setHeader('Content-Type', attachment.fileType);
    res.setHeader('Content-Disposition', `inline; filename="${encodeURIComponent(attachment.fileName)}"`);
    
    return res.sendFile(absolutePath, (err) => {
      if (err) {
        console.error('[AttachmentController] File Stream Error:', err);
        // เช็คว่า Headers ส่งไปหรือยัง ป้องกัน Error ซ้ำซ้อนเวลาไฟล์ถูกลบไปแล้วแต่ DB ยังอยู่
        if (!res.headersSent) {
          res.status(404).json({ error: 'Physical file not found on disk' });
        }
      }
    });

  } catch (error) {
    console.error('[AttachmentController] Download Error:', error);
    if (error.message === 'ATTACHMENT_NOT_FOUND') {
      return res.status(404).json({ error: 'Attachment not found' });
    }
    if (error.message === 'FORBIDDEN_ACCESS') {
      return res.status(403).json({ error: 'You do not have permission to access this file' });
    }
    return res.status(500).json({ error: 'Internal server error' });
  }
};

/**
 * Handle Get Attachments By Entity (Room/Vehicle)
 */
const getAttachmentsByEntity = async (req, res) => {
  try {
    const { entityType, entityId } = req.params;
    
    // ไม่มี Business Logic เรียกใช้ Service ทันที
    const attachments = await attachmentService.getAttachmentsByEntity(entityType, entityId);
    
    return res.status(200).json({
      success: true,
      data: attachments
    });
  } catch (error) {
    console.error('[AttachmentController] Get By Entity Error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

/**
 * Handle Delete Attachment (Hard Delete: DB + Physical)
 */
const deleteFile = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.userId; // ใช้ userId ตามที่แก้ไว้
    const roleId = req.user.roleId;

    await attachmentService.deleteAttachmentById(id, userId, roleId);

    return res.status(200).json({
      success: true,
      message: 'Attachment deleted successfully'
    });
  } catch (error) {
    console.error('[AttachmentController] Delete Error:', error);
    
    if (error.message === 'ATTACHMENT_NOT_FOUND') {
      return res.status(404).json({ error: 'Attachment not found' });
    }
    if (error.message === 'FORBIDDEN_ACCESS') {
      return res.status(403).json({ error: 'You do not have permission to delete this file' });
    }
    
    return res.status(500).json({ error: 'Internal server error' });
  }
};

module.exports = {
  uploadFile,
  downloadFile,
  getAttachmentsByEntity, // ➕ Export เพิ่ม
  deleteFile              // ➕ Export เพิ่ม
};