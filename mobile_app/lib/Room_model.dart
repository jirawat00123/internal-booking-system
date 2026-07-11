// Room_model.dart
import 'package:flutter/material.dart';

// 💡 1. คลาสโมเดลสำหรับเก็บข้อมูลห้องประชุม
class MeetingRoom {
  final String id; // ไอดีห้อง (เช่น A, B, C)
  final String floor; // ชั้น (เช่น 1, 2, 3)
  final String side; // ฝั่ง (เช่น A, B, นอร์ธ)
  final int capacity; // จำนวนผู้เข้าร่วมสูงสุด
  final String? imagePath; // ที่อยู่รูปภาพ (Path ไฟล์ หรือ URL)
  final String status; // สถานะห้อง (เช่น 'ว่างพร้อมใช้งาน', 'กำลังใช้งาน')

  MeetingRoom({
    required this.id,
    required this.floor,
    required this.side,
    required this.capacity,
    this.imagePath,
    this.status = 'ว่างพร้อมใช้งาน', // ค่าเริ่มต้นกำหนดให้เป็นห้องว่าง
  });

  // ฟังก์ชันสําหรับก๊อปปี้ข้อมูลและเปลี่ยนบางค่า (มีประโยชน์มากเวลาทำระบบแก้ไขข้อมูล)
  MeetingRoom copyWith({
    String? id,
    String? floor,
    String? side,
    int? capacity,
    String? imagePath,
    String? status,
  }) {
    return MeetingRoom(
      id: id ?? this.id,
      floor: floor ?? this.floor,
      side: side ?? this.side,
      capacity: capacity ?? this.capacity,
      imagePath: imagePath ?? this.imagePath,
      status: status ?? this.status,
    );
  }
}
// 1. คลาสสำหรับเก็บโครงสร้างข้อมูลการจอง
class BookingHistory{
  final String roomId;
  final String title;
  final String date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int participantCount;
  final String type; 
  final String bookedBy;
  String? status; // 💡 เปลี่ยนเป็นแบบไม่บังคับ (Optional) หรือตั้งเป็น String status;

  BookingHistory({
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
  if (status != null) return status!;

  try {
    // 2. แปลงสตริงวันที่จอง (เช่น "27/05/2026") แยกส่วน วัน/เดือน/ปี
    List<String> dateParts = date.split('/');
    int day = int.parse(dateParts[0]);
    int month = int.parse(dateParts[1]);
    int year = int.parse(dateParts[2]);

    // 3. สร้าง DateTime ของจุดเริ่มต้นและจุดสิ้นสุดของการจองนั้น ๆ
    final now = DateTime.now();
    final startBooking = DateTime(year, month, day, startTime.hour, startTime.minute);
    final endBooking = DateTime(year, month, day, endTime.hour, endTime.minute);

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

// 2. ตัวแปรลิสต์ส่วนกลางสำหรับเก็บประวัติจองทั้งหมดในแอป (เริ่มต้นเป็นลิสต์ว่าง)
final ValueNotifier<List<BookingHistory>> globalBookingHistory = ValueNotifier<List<BookingHistory>>([]);
