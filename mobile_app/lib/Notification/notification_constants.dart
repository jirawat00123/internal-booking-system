// lib/Notification/notification_constants.dart

/// คลาสสำหรับเก็บค่าคงที่ (Constants) ของระบบ Notification เพื่อป้องกันการพิมพ์ผิด (Magic Strings)
class NotificationConstants {
  // ป้องกันการสร้าง Instance ของคลาสนี้
  NotificationConstants._();

  // ==========================================
  // Entity Types (อ้างอิงจาก Backend)
  // ใช้สำหรับแยกประเภทและกำหนด Navigation Route
  // ==========================================
  static const String entityRoom = 'ROOM_BOOKING';
  static const String entityVehicle = 'VEHICLE_BOOKING';
  static const String entitySystem = 'SYSTEM';

  // ==========================================
  // Notification Types / Actions (อ้างอิงจาก Backend)
  // ใช้สำหรับแสดงผล Icon หรือ สีให้เหมาะสม
  // ==========================================
  static const String actionApproval = 'APPROVAL_REQUIRED';
  static const String actionReminder = 'REMINDER';
  static const String actionStatusUpdate = 'STATUS_UPDATE';
  static const String actionDocument = 'DOCUMENT_UPDATE';

  // ==========================================
  // UI Constants
  // ==========================================
  static const int maxBadgeCount = 99;
  static const String badgePlusText = '99+';

  // ==========================================
  // Route Name Definitions
  // (ชื่อ Route เหล่านี้ต้องถูกกำหนดไว้ใน MaterialApp ของ main.dart)
  // ==========================================
  static const String routeBookHistory = '/manage';

  /// Helper ฟังก์ชันเพื่อแปลง Entity Type เป็น Route ที่ถูกต้อง
  /// *Flutter ทำหน้าที่แค่ Map เส้นทาง ไม่ได้คำนวณ Logic*
  static String getRouteForEntity(String entityType) {
    switch (entityType.toUpperCase()) {
      case entityRoom:
      case entityVehicle:
        return routeBookHistory; // ส่งไปหน้า /manage ที่เปิดใช้งานอยู่จริงใน main.dart
      default:
        return routeBookHistory;
    }
  }
}
