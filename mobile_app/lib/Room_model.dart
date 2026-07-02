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
class BookingHistory {
  final String roomId;
  final String date; // ฟอร์แมต "MM/DD/YYYY"
  final TimeOfDay startTime; // อ็อบเจกต์เวลาเริ่ม
  final TimeOfDay endTime; // อ็อบเจกต์เวลาสิ้นสุด

  BookingHistory({
    required this.roomId,
    required this.date,
    required this.startTime,
    required this.endTime,
  });
}

// 2. ตัวแปรลิสต์ส่วนกลางสำหรับเก็บประวัติจองทั้งหมดในแอป (เริ่มต้นเป็นลิสต์ว่าง)
final ValueNotifier<List<BookingHistory>>
globalBookingHistory = ValueNotifier<List<BookingHistory>>([
  // คุณสามารถใส่ข้อมูลจำลองไว้ทดสอบตรงนี้ได้ เช่น:
  // BookingHistory(roomId: 'A', date: '05/27/2026', startTime: TimeOfDay(hour: 10, minute: 0), endTime: TimeOfDay(hour: 12, minute: 0)),
]);
