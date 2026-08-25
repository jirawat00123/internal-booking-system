// lib/Notification/notification_repository.dart

import 'dart:convert';
import 'notification_service.dart';
import 'notification_model.dart';

class NotificationRepository {
  // เรียกใช้ Service ที่เราสร้างไว้ในไฟล์ก่อนหน้า
  final NotificationService _service = NotificationService();

  // State Guard & Cache Variable
  bool _isFetchingNotifications = false;
  List<NotificationModel> _notificationCache = [];
  bool _isFetchingUnreadCount = false;
  int _unreadCountCache = 0;

  /// ดึงรายการ Notification และแปลงเป็น List<NotificationModel>
  Future<List<NotificationModel>> getNotifications({
    int page = 1,
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    if (_isFetchingNotifications) return _notificationCache;
    if (!forceRefresh && _notificationCache.isNotEmpty && page == 1) {
      return _notificationCache;
    }

    _isFetchingNotifications = true;
    try {
      final response = await _service.getNotifications(
        page: page,
        limit: limit,
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        // รองรับ Response จาก Express ที่มักจะห่อด้วย key "data" หรือเป็น Array ตรงๆ
        final List<dynamic> data = decoded['data'] ?? decoded;

        final result = data
            .map((json) => NotificationModel.fromJson(json))
            .toList();
        if (page == 1) {
          _notificationCache = result;
        }
        return result;
      } else {
        throw Exception(
          'Failed to fetch notifications. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Repository Error (getNotifications): $e');
    } finally {
      _isFetchingNotifications = false;
    }
  }

  /// ดึงจำนวนแจ้งเตือนที่ยังไม่ได้อ่าน กลับไปเป็นตัวเลข (int)
  Future<int> getUnreadCount({bool forceRefresh = false}) async {
    if (_isFetchingUnreadCount) return _unreadCountCache;
    if (!forceRefresh && _unreadCountCache > 0) return _unreadCountCache;

    _isFetchingUnreadCount = true;
    try {
      final response = await _service.getUnreadCount();

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        // รองรับ Format จาก Backend เช่น { "unreadCount": 5 } หรือ { "count": 5 }
        _unreadCountCache = decoded['unreadCount'] ?? decoded['count'] ?? 0;
        return _unreadCountCache;
      } else {
        throw Exception(
          'Failed to fetch unread count. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Repository Error (getUnreadCount): $e');
    } finally {
      _isFetchingUnreadCount = false;
    }
  }

  /// อัปเดตสถานะการอ่านราย Item (คืนค่าเป็น bool เพื่อให้ UI รู้ว่าสำเร็จไหม)
  Future<bool> markAsRead(String id) async {
    try {
      final response = await _service.markAsRead(id);
      // รองรับทั้ง 200 OK และ 201 Created/Updated หรือ 204 No Content
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false; // กลืน Error แล้วบอก UI ว่าไม่สำเร็จ (สามารถเปลี่ยนเป็น throw ได้ถ้าต้องการจัดการที่ UI)
    }
  }

  /// อัปเดตสถานะการอ่านทั้งหมด (Mark all as read)
  Future<bool> markAllAsRead() async {
    try {
      final response = await _service.markAllAsRead();
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }
}
