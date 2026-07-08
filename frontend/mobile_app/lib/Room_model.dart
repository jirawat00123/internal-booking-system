// Room_model.dart
import 'package:flutter/material.dart';

String globalToken = '';

// 💡 1. คลาสโมเดลสำหรับเก็บข้อมูลห้องประชุม
class MeetingRoom {
  final String id;
  final String roomName;
  final String location;
  final int capacity;
  final String? imagePath;
  final String status;

  MeetingRoom({
    required this.id,
    required this.roomName,
    required this.location,
    required this.capacity,
    this.imagePath,
    this.status = 'AVAILABLE',
  });

  // ฟังก์ชันสําหรับก๊อปปี้ข้อมูลและเปลี่ยนบางค่า (มีประโยชน์มากเวลาทำระบบแก้ไขข้อมูล)
  MeetingRoom copyWith({
    String? id,
    String? roomName,
    String? location,
    int? capacity,
    String? imagePath,
    String? status,
  }) {
    return MeetingRoom(
      id: id ?? this.id,
      roomName: roomName ?? this.roomName,
      location: location ?? this.location,
      capacity: capacity ?? this.capacity,
      imagePath: imagePath ?? this.imagePath,
      status: status ?? this.status,
    );
  }

  factory MeetingRoom.fromJson(Map<String, dynamic> json) {
    return MeetingRoom(
      id: json['id'].toString(),
      roomName: json['roomName'] ?? '',
      location: json['location'] ?? '',
      capacity: json['capacity'] ?? 0,
      imagePath: json['uploadUrl'] ?? json['upload_url'] ?? '',
      status: json['status'] ?? 'AVAILABLE',
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_name': roomName,
      'location': location,
      'capacity': capacity,
      'upload_url': imagePath,
      'status': status,
    };
  }
}

// 1. คลาสสำหรับเก็บโครงสร้างข้อมูลการจอง
class BookingHistory {
  final String roomId;
  final String title;
  final String date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int participantCount;
  final String type;
  final String bookedBy;
  final int? id; // 💡 เพิ่มตัวแปร id สำหรับใช้ในการยกเลิกการจอง
  String?
  status; // 💡 เปลี่ยนเป็นแบบไม่บังคับ (Optional) หรือตั้งเป็น String status;

  BookingHistory({
    this.id, // 💡 รับค่า id (ไม่บังคับ)
    required this.roomId,
    required this.title,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.participantCount,
    required this.type,
    required this.bookedBy,
    this.status, // 💡 เพิ่มเข้ามาตรงนี้
  });

  // 🔥 ฟังก์ชันอัจฉริยะ: เช็คสถานะตามเวลาจริงอัตโนมัติ
  // 💡 ให้แก้ไขฟังก์ชัน get currentStatus ในไฟล์ Room_model.dart เป็นแบบนี้ครับ
  String get currentStatus {
    // 1. ถ้ามีการกดยกเลิกหรือเปลี่ยนสเตตัสโดยตรงจากปุ่ม ให้ใช้ค่านั้นทันที
    if (status != null) {
      switch (status) {
        case 'AVAILABLE':
          return 'ว่าง';

        case 'RESERVED':
          return 'จองแล้ว';

        case 'IN_USE':
          return 'กำลังใช้งาน';

        default:
          return status!;
      }
    }

    try {
      // 2. แปลงสตริงวันที่จอง (เช่น "27/05/2026") แยกส่วน วัน/เดือน/ปี
      List<String> dateParts = date.split('/');
      int day = int.parse(dateParts[0]);
      int month = int.parse(dateParts[1]);
      int year = int.parse(dateParts[2]);

      // 3. สร้าง DateTime ของจุดเริ่มต้นและจุดสิ้นสุดของการจองนั้น ๆ
      final now = DateTime.now();
      final startBooking = DateTime(
        year,
        month,
        day,
        startTime.hour,
        startTime.minute,
      );
      final endBooking = DateTime(
        year,
        month,
        day,
        endTime.hour,
        endTime.minute,
      );

      // 4. 🔥 โลจิกเปรียบเทียบกับเวลาจริงของเครื่องคอมพิวเตอร์/มือถือ
      if (now.isBefore(startBooking)) {
        return 'จองแล้ว'; // ยังไม่ถึงเวลา
      } else if (now.isAfter(startBooking) && now.isBefore(endBooking)) {
        return 'กำลังใช้งาน'; // อยู่ในช่วงเวลาที่จองพอดี
      } else if (now.isAfter(endBooking)) {
        return 'เสร็จสิ้น'; // เลยเวลาจองไปแล้ว
      }
    } catch (e) {
      debugPrint("Error calculating currentStatus: $e");
    }

    return 'จองแล้ว'; // คืนค่าเริ่มต้นหากเกิดข้อผิดพลาด
  }
}

String globalCurrentUserName = "MMK";

final ValueNotifier<List<BookingHistory>> globalBookingHistory =
    ValueNotifier<List<BookingHistory>>([]);

final ValueNotifier<List<MeetingRoom>> globalMeetingRooms =
    ValueNotifier<List<MeetingRoom>>([]);
