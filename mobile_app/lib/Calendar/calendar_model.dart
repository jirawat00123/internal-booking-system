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

  // แปลงค่า HEX String (เช่น #42BCA4) เป็นออบเจกต์ Color ของ Flutter เพื่อใช้วาด UI
  Color get color {
    String hexStr = colorHex.replaceAll('#', '');
    if (hexStr.length == 6) {
      hexStr = 'FF$hexStr'; // ใส่ Opacity 100% (FF) เข้าไปด้านหน้า
    }
    return Color(
      int.tryParse(hexStr, radix: 16) ?? 0xFF000000,
    ); // ถ้าแปลงผิดพลาดให้แสดงสีดำ
  }
}
