import 'package:flutter/material.dart';

class CalendarEvent {
  final String eventId;
  final int originalId;
  final String type;
  final String title;
  final String bookerName;
  final DateTime start;
  final DateTime end;
  final String colorHex;
  final String status;

  CalendarEvent({
    required this.eventId,
    required this.originalId,
    required this.type,
    required this.title,
    required this.bookerName,
    required this.start,
    required this.end,
    required this.colorHex,
    required this.status,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      eventId: json['eventId'] ?? '',
      originalId: json['originalId'] ?? 0,
      type: json['type'] ?? '',
      title: json['title'] ?? 'ไม่มีชื่อ',
      bookerName: json['bookerName'] ?? 'ไม่ระบุชื่อผู้จอง',
      // แปลง ISO 8601 string จาก Backend ให้เป็น DateTime ของ Local Timezone เครื่อง
      start: DateTime.parse(json['start']).toLocal(),
      end: DateTime.parse(
        json['end'] ?? json['endDatetime'] ?? json['returnDate'],
      ).toLocal(),
      colorHex: json['color'] ?? '#42BCA4',
      status: json['status'] ?? 'UNKNOWN',
    );
  }

  // กำหนดสีของการจองตาม Booking Status
  Color get color {
    switch (status.toUpperCase()) {
      case 'RESERVED':
      case 'PENDING':
        return const Color(0xFFF59E0B); // สีเหลืองส้ม (#F59E0B)
      case 'APPROVED':
        return const Color(0xFF2EC4B6); // สีเขียวมิ้นต์
      case 'IN_USE':
        return const Color(0xFF004381); // สีน้ำเงินเข้ม
      case 'COMPLETED':
        return const Color(0xFF9E9E9E); // สีเทา
      case 'EXPIRED':
        return const Color(0xFFE11D48); // สีแดง
      default:
        return const Color(0xFF00A8CC); // สีตั้งต้น
    }
  }
}
