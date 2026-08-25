import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
// นำเข้า AuthService เดิมเพื่อ Reuse การจัดการ Token
import '../auth_service.dart';

class NotificationService {
  // กำหนด Base URL ตาม Platform ให้รองรับทั้ง Web และ Emulator
  final String _baseUrl = kIsWeb
      ? 'https://192.168.88.25:3002'
      : 'https://192.168.88.25:3002';

  /// สร้าง Header พร้อมแนบ JWT Token เสมอ
  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.instance
        .getToken(); // เรียกผ่าน Instance Singleton
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// GET /api/notifications?page={page}&limit={limit}
  /// ดึงรายการ Notification ตาม Pagination
  Future<http.Response> getNotifications({int page = 1, int limit = 20}) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse(
        '$_baseUrl/api/notifications?page=$page&limit=$limit',
      );
      return await http.get(url, headers: headers);
    } catch (e) {
      throw Exception('Failed to load notifications: $e');
    }
  }

  /// GET /api/notifications/unread-count
  /// ดึงจำนวนแจ้งเตือนที่ยังไม่ได้อ่าน
  Future<http.Response> getUnreadCount() async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$_baseUrl/api/notifications/unread-count');
      return await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw Exception('Failed to load unread count: $e');
    }
  }

  /// PATCH /api/notifications/:id/read
  /// อัปเดตสถานะการอ่านราย Item
  Future<http.Response> markAsRead(String id) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$_baseUrl/api/notifications/$id/read');
      return await http
          .patch(url, headers: headers)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  /// PATCH /api/notifications/read-all
  /// อัปเดตสถานะการอ่านทั้งหมด (Mark all as read)
  Future<http.Response> markAllAsRead() async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$_baseUrl/api/notifications/read-all');
      return await http
          .patch(url, headers: headers)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw Exception('Failed to mark all as read: $e');
    }
  }

  /// POST /api/notifications/:id/respond
  /// ส่งคำตอบรับ/ปฏิเสธ การแจ้งเตือน (เช่น ยินยอมให้ปล่อยรถก่อนเวลา)
  Future<http.Response> respondToNotification(String id, String action) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$_baseUrl/api/notifications/$id/respond');
      return await http
          .post(url, headers: headers, body: jsonEncode({'action': action}))
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw Exception('Failed to respond to notification: $e');
    }
  }
}
