// mobile_app/lib/Dashboard/dashboard_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth_service.dart';

class DashboardService {
  final String baseUrl;
  final FlutterSecureStorage _storage;

  DashboardService({String? baseUrl, FlutterSecureStorage? storage})
    : baseUrl = baseUrl ?? '${AuthService.baseUrl}/api',
      _storage = storage ?? const FlutterSecureStorage();

  Future<String?> _getToken() async {
    // ค้นหา Token จาก Key ที่เป็นไปได้ทั้งหมด
    String? token = await _storage.read(key: 'jwt_token');
    token ??= await _storage.read(key: 'token');
    token ??= await _storage.read(key: 'auth_token');
    token ??= await _storage.read(key: 'accessToken');

    // สำรอง: อ่านจาก SharedPreferences (รองรับกรณี Web Browser / SharedPreferences)
    if (token == null || token.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        token =
            prefs.getString('token') ??
            prefs.getString('jwt_token') ??
            prefs.getString('auth_token') ??
            prefs.getString('accessToken');
      } catch (_) {}
    }

    // Clean Token ป้องกันเครื่องหมายอัญประกาศและช่องว่างส่วนเกิน
    if (token != null) {
      token = token.replaceAll('"', '').trim();
    }

    if (kDebugMode) {
      if (token != null && token.isNotEmpty) {
        print(
          '🔑 [DashboardService] พบ Token: ${token.substring(0, token.length > 15 ? 15 : token.length)}...',
        );
      } else {
        print('🚨 [DashboardService] ไม่พบ Token ใน Storage (ค่าเป็น NULL)!');
      }
    }
    return token;
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (token != null && token.isNotEmpty) {
      final authHeader = token.startsWith('Bearer ') ? token : 'Bearer $token';
      headers['Authorization'] = authHeader;
    }

    return headers;
  }

  /// เรียก API Admin Dashboard
  Future<Map<String, dynamic>> fetchAdminDashboard() async {
    return _get('/reports/dashboard/admin');
  }

  /// เรียก API User Dashboard
  Future<Map<String, dynamic>> fetchUserDashboard() async {
    return _get('/reports/dashboard/user');
  }

  /// เรียก API Security Dashboard
  Future<Map<String, dynamic>> fetchSecurityDashboard() async {
    return _get('/reports/dashboard/security');
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final headers = await _getHeaders();
    final url = Uri.parse('$baseUrl$path');

    if (kDebugMode) {
      print('🌐 [DashboardService] Requesting GET: $url');
      print('📋 [DashboardService] Headers Sent: $headers');
    }

    final response = await http.get(url, headers: headers);
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (kDebugMode) {
      print('📩 [DashboardService] Response Code: ${response.statusCode}');
    }

    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      body = {'error': response.body};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body is Map<String, dynamic> ? body : {'data': body};
    } else {
      final errorMsg = (body is Map && body['error'] != null)
          ? body['error']
          : (body is Map && body['message'] != null)
          ? body['message']
          : 'เกิดข้อผิดพลาดในการดึงข้อมูล (${response.statusCode})';
      throw Exception(errorMsg);
    }
  }
}
