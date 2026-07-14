import 'package:flutter/material.dart';

// ==========================================
// 🚗 1. คลาสโมเดลสำหรับเก็บข้อมูลรถยนต์
// ==========================================
class VehicleModel {
  final String id;
  final String name;
  final String plate;
  final String type;
  final int capacity;
  final String status;
  final String imagePath;
  final String? documentPath;
  // 🔥 เพิ่มตัวแปรที่ระบบแอดมินตามหา
  final bool isDeleted;
  final bool hasFutureBooking;

  VehicleModel({
    required this.id,
    required this.name,
    required this.plate,
    required this.type,
    required this.capacity,
    required this.status,
    required this.imagePath,
    this.documentPath,
    this.isDeleted = false,
    this.hasFutureBooking = false,
  });

  // 🟢 ฟังก์ชันพระเอก! แปลงข้อมูล JSON จาก API หลังบ้าน มาเป็น Model ของแอป
  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      // แปลง ID เป็น String เสมอ เพื่อป้องกัน Error กรณี API ส่งมาเป็นตัวเลข (Int)
      id: json['id']?.toString() ?? '',
      name:
          json['vehicleName'] ??
          json['vehicle_name'] ??
          json['name'] ??
          'ไม่ระบุชื่อ',
      plate:
          json['plateNumber'] ??
          json['licensePlate'] ??
          json['license_plate'] ??
          json['plate'] ??
          '-',
      type: json['type'] ?? '',
      // ดึง capacity จาก 'seats' ของหลังบ้าน ถ้าไม่มีให้หาจาก 'capacity' หรือใช้ 4 เป็นค่าเริ่มต้น
      capacity: json['seats'] != null
          ? int.tryParse(json['seats'].toString()) ?? 4
          : (json['capacity'] != null
                ? int.tryParse(json['capacity'].toString()) ?? 4
                : 4),
      status: json['status'] ?? 'AVAILABLE',
      // ดึง URL รูปภาพจาก Database (ถ้ามี)
      imagePath:
          json['uploadUrl'] ?? json['upload_url'] ?? json['imagePath'] ?? '',
      documentPath: json['documentPath'],
      isDeleted: json['isDeleted'] ?? json['is_deleted'] ?? false,
      hasFutureBooking: json['hasFutureBooking'] ?? false,
    );
  }

  // 💡 ฟังก์ชันสําหรับก๊อปปี้ข้อมูลและเปลี่ยนบางค่า
  VehicleModel copyWith({
    String? id,
    String? name,
    String? plate,
    String? type,
    int? capacity,
    String? status,
    String? imagePath,
    String? documentPath,
    bool? isDeleted,
    bool? hasFutureBooking,
  }) {
    return VehicleModel(
      id: id ?? this.id,
      name: name ?? this.name,
      plate: plate ?? this.plate,
      type: type ?? this.type,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      imagePath: imagePath ?? this.imagePath,
      documentPath: documentPath ?? this.documentPath,
      isDeleted: isDeleted ?? this.isDeleted,
      hasFutureBooking: hasFutureBooking ?? this.hasFutureBooking,
    );
  }
}

// ==========================================
// 📅 2. คลาสสำหรับเก็บโครงสร้างข้อมูลการจองรถ
// ==========================================
class VehicleBookingHistory {
  final String vehicleId;
  final String destination;
  final String startDate;
  final String endDate;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int passengerCount;
  final int driveType;
  final String bookedBy;
  String? status;

  VehicleBookingHistory({
    required this.vehicleId,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.passengerCount,
    required this.driveType,
    required this.bookedBy,
    this.status,
  });

  // 🔥 ฟังก์ชันอัจฉริยะ: เช็คสถานะตามเวลาจริงอัตโนมัติ
  String get currentStatus {
    if (status != null) return status!;

    try {
      List<String> startParts = startDate.split('/');
      int sDay = int.parse(startParts[0]);
      int sMonth = int.parse(startParts[1]);
      int sYear = int.parse(startParts[2]);
      final startBooking = DateTime(
        sYear,
        sMonth,
        sDay,
        startTime.hour,
        startTime.minute,
      );

      List<String> endParts = endDate.split('/');
      int eDay = int.parse(endParts[0]);
      int eMonth = int.parse(endParts[1]);
      int eYear = int.parse(endParts[2]);
      final endBooking = DateTime(
        eYear,
        eMonth,
        eDay,
        endTime.hour,
        endTime.minute,
      );

      final now = DateTime.now();
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

// ==========================================
// 🌍 3. ตัวแปร Global ส่วนกลางสำหรับเก็บข้อมูล
// ==========================================
String globalCurrentUserName = "MMK"; // จำลองชื่อผู้ใช้งานล็อกอิน

// 🚗 ตัวแปรเก็บข้อมูลรถยนต์ทั้งหมด (เดี๋ยวเราจะไม่ได้ใช้ข้อมูลจำลองนี้แล้วเมื่อต่อ API สำเร็จ)
final ValueNotifier<List<VehicleModel>> globalVehicles =
    ValueNotifier<List<VehicleModel>>([]);

// 📋 ตัวแปรเก็บประวัติการจองรถทั้งหมดในแอป (เริ่มต้นเป็นลิสต์ว่าง)
final ValueNotifier<List<VehicleBookingHistory>> globalVehicleBookingHistory =
    ValueNotifier<List<VehicleBookingHistory>>([]);
