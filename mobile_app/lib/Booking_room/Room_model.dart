import 'package:flutter/material.dart';

// 💡 1. คลาสโมเดลสำหรับเก็บข้อมูลห้องประชุม
class MeetingRoom {
  final String id; // ไอดีห้อง (เช่น A, B, C)
  final int location; // ชั้น (เช่น 1, 2, 3)
  final String side; // ฝั่ง (เช่น A, B, นอร์ธ)
  final int capacity; // จำนวนผู้เข้าร่วมสูงสุด
  final String? imagePath; // ที่อยู่รูปภาพ (Path ไฟล์ หรือ URL)
  final String status; // สถานะห้อง (เช่น 'ว่างพร้อมใช้งาน', 'กำลังใช้งาน')

  MeetingRoom({
    required this.id,
    required this.location,
    required this.side,
    required this.capacity,
    this.imagePath,
    this.status = 'ว่างพร้อมใช้งาน', // ค่าเริ่มต้นกำหนดให้เป็นห้องว่าง
  });

  // 💡 ฟังก์ชันแปลงข้อมูล JSON จาก API ของ Prisma ให้กลายเป็น Object
  factory MeetingRoom.fromJson(Map<String, dynamic> json) {
    return MeetingRoom(
      id: json['id'].toString(),
    side: json['side'] ?? '', // ลองดูว่า json['side'] ได้ค่าอะไรมา
    location: int.tryParse(json['floor']?.toString() ?? '') ?? 0,
      // 💡 แปลงค่าให้เป็น Int เสมอ ป้องกันแอปเด้ง
      capacity: int.tryParse(json['capacity'].toString()) ?? 0, 
      imagePath: json['uploadUrl'] != null 
          ? 'http://localhost:3001/${json['uploadUrl']}' 
          : null,
      status: json['status'] == 'AVAILABLE' ? 'ว่างพร้อมใช้งาน' : 'ไม่ว่าง',
    );
  }

  // ฟังก์ชันสําหรับก๊อปปี้ข้อมูลและเปลี่ยนบางค่า
  MeetingRoom copyWith({
    String? id,
    int? location,
    String? side,
    int? capacity,
    String? imagePath,
    String? status,
  }) {
    return MeetingRoom(
      id: id ?? this.id,
      location: location ?? this.location,
      side: side ?? this.side,
      capacity: capacity ?? this.capacity,
      imagePath: imagePath ?? this.imagePath,
      status: status ?? this.status,
    );
  }
}

// 2. คลาสสำหรับเก็บโครงสร้างข้อมูลการจอง (เอาไว้ใช้กับประวัติการจอง)
class BookingHistory{
  final String roomId;
  final String title;
  final String date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int participantCount;
  final String type; 
  final String bookedBy;
  String? status; 

  BookingHistory({
    required this.roomId,
    required this.title,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.participantCount,
    required this.type,
    required this.bookedBy,
    this.status,
  });

  String get currentStatus {
    if (status != null) return status!;

    try {
      List<String> dateParts = date.split('/');
      int day = int.parse(dateParts[0]);
      int month = int.parse(dateParts[1]);
      int year = int.parse(dateParts[2]);

      final now = DateTime.now();
      final startBooking = DateTime(year, month, day, startTime.hour, startTime.minute);
      final endBooking = DateTime(year, month, day, endTime.hour, endTime.minute);

      if (now.isBefore(startBooking)) {
        return 'จองแล้ว'; 
      } else if (now.isAfter(startBooking) && now.isBefore(endBooking)) {
        return 'กำลังใช้งาน'; 
      } else if (now.isAfter(endBooking)) {
        return 'เสร็จสิ้น'; 
      }
    } catch (e) {
      debugPrint("Error calculating currentStatus: $e");
    }

    return 'จองแล้ว'; 
  }
}

String globalCurrentUserName = "MMK";
int globalRoomUserId = 0;
final ValueNotifier<List<BookingHistory>> globalBookingHistory = ValueNotifier<List<BookingHistory>>([]);