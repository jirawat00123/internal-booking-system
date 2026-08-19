import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'calendar_model.dart';

class CalendarService {
  // TODO: ปรับ Base URL ให้ตรงกับไฟล์ config หรือ auth_service.dart ที่โปรเจกต์ของคุณใช้งาน
  static const String baseUrl = 'http://192.168.88.25:3001/api';

  Future<List<CalendarEvent>> fetchUnifiedEvents(
    DateTime startDate,
    DateTime endDate, {
    String? status,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token =
          prefs.getString('token') ??
          ''; // ตรวจสอบ key ที่ใช้เก็บ Token ในโปรเจกต์ของคุณ (ปกติจะเป็น 'token' หรือ 'auth_token')

      // แปลงวันที่เป็นรูปแบบ ISO 8601 เพื่อส่งให้ Backend
      final startIso = startDate.toIso8601String();
      final endIso = endDate.toIso8601String();

      // สร้าง URL พร้อม Query Parameters
      String url = '$baseUrl/calendar/all?startDate=$startIso&endDate=$endIso';
      if (status != null && status.isNotEmpty) {
        url += '&status=$status';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          final List<dynamic> data = decoded['data'];
          return data.map((item) => CalendarEvent.fromJson(item)).toList();
        } else {
          throw Exception(
            decoded['message'] ?? 'เกิดข้อผิดพลาดในการดึงข้อมูลปฏิทิน',
          );
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception(
          'เซสชันหมดอายุ หรือไม่มีสิทธิ์เข้าถึง (ถูกระงับ) กรุณาเข้าสู่ระบบใหม่',
        );
      } else {
        throw Exception(
          'ดึงข้อมูลปฏิทินล้มเหลว (Status: ${response.statusCode})',
        );
      }
    } catch (e) {
      throw Exception('ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้: $e');
    }
  }
}
