const express = require('express');
const router = express.Router();
const reportController = require('../controllers/reportController');
const { authenticateToken, requireRole } = require('../middlewares/auth');

// ... (Routes รายงานเดิมที่มีอยู่) ...

// ==========================================
// Phase 7: Dashboard & Reports Aggregated API
// ==========================================

// Dashboard สำหรับ Admin (ต้องมี Role ADMIN)
router.get(
  '/dashboard/admin',
  authenticateToken,
  requireRole(['ADMIN']),
  reportController.getAdminDashboard
);

// Summary & Overview Stats สำหรับ Dashboard
router.get(
  '/dashboard-stats',
  authenticateToken,
  requireRole(['ADMIN']),
  reportController.getDashboardStats
);

// Dashboard สำหรับ User ทั่วไป (ใช้สิทธิ์ Token ของตนเอง)
router.get(
  '/dashboard/user',
  authenticateToken,
  reportController.getUserDashboard
);

// Dashboard สำหรับ Security / เจ้าหน้าที่ยานพาหนะ ( SECURITY หรือ ADMIN)
router.get(
  '/dashboard/security',
  authenticateToken,
  requireRole(['SECURITY', 'GUARD', 'ADMIN']),
  reportController.getSecurityDashboard
);

// Export Report สรุปผลการจอง + บันทึก AuditLog
router.get(
  '/export',
  authenticateToken,
  requireRole(['ADMIN']),
  reportController.exportReport
);

// ==========================================
// Phase 8: Aggregated Search API
// ==========================================
// API สำหรับค้นหาการจองแบบข้าม Resource (Room/Vehicle) และ Pagination
router.get(
  '/bookings',
  authenticateToken,
  reportController.getAggregatedBookings
);

module.exports = router;