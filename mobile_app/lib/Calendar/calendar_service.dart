import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'calendar_model.dart';

class CalendarService {
  // TODO: ปรับ Base URL ให้ตรงกับไฟล์ config หรือ auth_service.dart ที่โปรเจกต์ของคุณใช้งาน
  static const String baseUrl = 'https://192.168.88.25:3002/api';

  Future<List<CalendarEvent>> fetchRoomEvents(
    DateTime startDate,
    DateTime endDate, {
    int? roomId,
    String? status,
    String? location,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token =
          prefs.getString('token') ?? prefs.getString('jwt_token') ?? '';

      final startIso = startDate.toIso8601String();
      final endIso = endDate.toIso8601String();

      String url =
          '$baseUrl/calendar/rooms?startDate=$startIso&endDate=$endIso';
      if (roomId != null && roomId > 0) {
        url += '&roomId=$roomId';
      }
      if (location != null && location.isNotEmpty) {
        url += '&location=$location';
      }
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
          final now = DateTime.now();
          final List<CalendarEvent> events = [];

          for (var item in data) {
            String rawStatus = item['status']?.toString().toUpperCase() ?? '';
            // กรองให้แสดงเฉพาะสถานะ PENDING, APPROVED และ IN_USE
            if (rawStatus != 'PENDING' &&
                rawStatus != 'APPROVED' &&
                rawStatus != 'IN_USE') {
              continue;
            }

            final start = DateTime.parse(item['startDatetime']);
            final end = DateTime.parse(item['endDatetime']);
            final now = DateTime.now();

            // เช็คเวลาปัจจุบัน ถ้าถึงเวลาเริ่มใช้งานแล้ว ให้ปรับสถานะเป็น IN_USE อัตโนมัติ
            if ((rawStatus == 'APPROVED' || rawStatus == 'PENDING') &&
                (now.isAfter(start) || now.isAtSameMomentAs(start))) {
              rawStatus = 'IN_USE';
            }

            // บังคับให้ PENDING และ APPROVED แสดงผลเป็น RESERVED
            String displayStatus =
                (rawStatus == 'PENDING' || rawStatus == 'APPROVED')
                ? 'RESERVED'
                : rawStatus;
            String colorHex = '#F59E0B'; // 🟡 ค่าเริ่มต้น RESERVED

            if (displayStatus == 'IN_USE') {
              colorHex = '#004381'; // 🔵 เปลี่ยนสีเป็นน้ำเงินเมื่อกำลังใช้งาน
            }

            if (displayStatus == 'IN_USE') {
              colorHex = '#004381'; // 🔵 IN_USE
            }

            events.add(
              CalendarEvent.fromJson({
                'eventId': 'ROOM-${item['id']}',
                'originalId': item['id'],
                'type': 'ROOM',
                'title': item['room']?['roomName'] ?? 'ไม่ระบุห้อง',
                'bookerName':
                    item['user']?['employee']?['fullName'] ??
                    'ไม่ระบุชื่อผู้จอง',
                'start': item['startDatetime'],
                'end': item['endDatetime'],
                'color': colorHex,
                'status': displayStatus,
                'purpose': item['purpose'] ?? 'ไม่ระบุวัตถุประสงค์',
                'employeeCode':
                    item['user']?['employee']?['employeeCode'] ?? '-',
                'roomInfo': item['room'], // ส่งต่อ roomInfo
              }),
            );
          }
          return events;
        } else {
          throw Exception(
            decoded['message'] ?? 'เกิดข้อผิดพลาดในการดึงข้อมูลปฏิทิน',
          );
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception(
          'เซสชันหมดอายุ หรือไม่มีสิทธิ์เข้าถึง กรุณาเข้าสู่ระบบใหม่',
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

  Future<List<CalendarEvent>> fetchVehicleEvents(
    DateTime startDate,
    DateTime endDate, {
    int? vehicleId,
    String? status,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token =
          prefs.getString('token') ?? prefs.getString('jwt_token') ?? '';

      final startIso = startDate.toIso8601String();
      final endIso = endDate.toIso8601String();

      String url =
          '$baseUrl/calendar/vehicles?startDate=$startIso&endDate=$endIso';
      if (vehicleId != null && vehicleId > 0) {
        url += '&vehicleId=$vehicleId';
      }
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
          final now = DateTime.now();
          final List<CalendarEvent> events = [];

          for (var item in data) {
            String rawStatus = item['status']?.toString().toUpperCase() ?? '';
            // กรองให้แสดงเฉพาะสถานะ PENDING, APPROVED และ IN_USE
            if (rawStatus != 'PENDING' &&
                rawStatus != 'APPROVED' &&
                rawStatus != 'IN_USE') {
              continue;
            }

            final start = DateTime.parse(item['startDatetime']);
            final end = DateTime.parse(item['endDatetime']);
            final now = DateTime.now();

            // เช็คเวลาปัจจุบัน ถ้าถึงเวลาเริ่มใช้งานแล้ว ให้ปรับสถานะเป็น IN_USE อัตโนมัติ
            if ((rawStatus == 'APPROVED' || rawStatus == 'PENDING') &&
                (now.isAfter(start) || now.isAtSameMomentAs(start))) {
              rawStatus = 'IN_USE';
            }

            // บังคับให้ PENDING และ APPROVED แสดงผลเป็น RESERVED
            String displayStatus =
                (rawStatus == 'PENDING' || rawStatus == 'APPROVED')
                ? 'RESERVED'
                : rawStatus;
            String colorHex = '#F59E0B'; // 🟡 RESERVED

            if (displayStatus == 'IN_USE') {
              colorHex = '#004381'; // 🔵 เปลี่ยนสีเป็นน้ำเงินเมื่อกำลังใช้งาน
            }

            if (displayStatus == 'IN_USE') {
              colorHex = '#004381';
            }

            events.add(
              CalendarEvent.fromJson({
                'eventId': 'VEHICLE-${item['id']}',
                'originalId': item['id'],
                'type': 'VEHICLE',
                'title':
                    '${item['vehicle']?['brand'] ?? ''} ${item['vehicle']?['model'] ?? ''} (${item['vehicle']?['plateNumber'] ?? ''})'
                        .trim(),
                'bookerName':
                    item['user']?['employee']?['fullName'] ??
                    'ไม่ระบุชื่อผู้จอง',
                'start': item['startDatetime'],
                'end': item['endDatetime'],
                'color': colorHex,
                'status': displayStatus,
                'purpose': item['purpose'] ?? 'ไม่ระบุวัตถุประสงค์',
                'employeeCode':
                    item['user']?['employee']?['employeeCode'] ?? '-',
                'vehicleInfo': item['vehicle'],
              }),
            );
          }
          return events;
        } else {
          throw Exception(
            decoded['message'] ?? 'เกิดข้อผิดพลาดในการดึงข้อมูลปฏิทิน',
          );
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception(
          'เซสชันหมดอายุ หรือไม่มีสิทธิ์เข้าถึง กรุณาเข้าสู่ระบบใหม่',
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

  Future<List<CalendarEvent>> fetchUnifiedEvents(
    DateTime startDate,
    DateTime endDate, {
    String? status,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token =
          prefs.getString('token') ?? prefs.getString('jwt_token') ?? '';

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
          final now = DateTime.now();
          final List<CalendarEvent> events = [];

          for (var item in data) {
            String rawStatus = item['status']?.toString().toUpperCase() ?? '';

            // กรองให้แสดงเฉพาะสถานะ PENDING, APPROVED และ IN_USE
            if (rawStatus != 'PENDING' &&
                rawStatus != 'APPROVED' &&
                rawStatus != 'IN_USE') {
              continue;
            }

            final start = DateTime.parse(item['start']);
            final end = DateTime.parse(item['end']);
            final now = DateTime.now();

            // เช็คเวลาปัจจุบัน ถ้าถึงเวลาเริ่มใช้งานแล้ว ให้ปรับสถานะเป็น IN_USE อัตโนมัติ
            if ((rawStatus == 'APPROVED' || rawStatus == 'PENDING') &&
                (now.isAfter(start) || now.isAtSameMomentAs(start))) {
              rawStatus = 'IN_USE';
            }

            // บังคับให้ PENDING และ APPROVED แสดงผลเป็น RESERVED
            String displayStatus =
                (rawStatus == 'PENDING' || rawStatus == 'APPROVED')
                ? 'RESERVED'
                : rawStatus;
            String colorHex = '#F59E0B'; // 🟡 ค่าเริ่มต้น RESERVED

            if (displayStatus == 'IN_USE') {
              colorHex = '#004381';
            } else if (item['color'] != null &&
                rawStatus != 'PENDING' &&
                rawStatus != 'APPROVED') {
              colorHex =
                  item['color']; // คงสีเดิมจาก Backend ถ้ามีและไม่ใช่สถานะข้างต้น
            }

            Map<String, dynamic> updatedItem = Map<String, dynamic>.from(item);
            updatedItem['status'] = displayStatus;
            updatedItem['color'] = colorHex;

            events.add(CalendarEvent.fromJson(updatedItem));
          }
          return events;
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
