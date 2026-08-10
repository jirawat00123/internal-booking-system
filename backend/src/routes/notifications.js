const express = require('express');
const router = express.Router();
const notificationController = require('../controllers/notificationController');
const { authenticateToken } = require('../middlewares/auth');

// ต้องผ่าน JWT Authentication ทั้งหมด
router.use(authenticateToken);

// GET /api/notifications (รองรับ ?page=1&limit=20&filter=UNREAD)
router.get('/', notificationController.getNotifications);

// PATCH /api/notifications/read-all (ต้องวางก่อน /:id/read)
router.patch('/read-all', notificationController.markAllAsRead);

// PATCH /api/notifications/:id/read
router.patch('/:id/read', notificationController.markAsRead);

// DELETE /api/notifications/:id
router.delete('/:id', notificationController.deleteNotification);

module.exports = router;