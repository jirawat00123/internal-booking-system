import 'package:flutter/material.dart';

// ==========================================
// 🚗 1. คลาสโมเดลสำหรับเก็บข้อมูลรถยนต์ (Vehicle)
// ==========================================
class VehicleModel {
  final int id;
  final String plateNumber;
  final String brand;
  final String model;
  final int seats;
  final String status;
  final String? uploadUrl;
  final bool isDeleted;
  final String vehicleName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ตัวแปรสำหรับใช้งานฝั่ง UI
  final bool hasFutureBooking;

  VehicleModel({
    required this.id,
    required this.plateNumber,
    required this.brand,
    required this.model,
    required this.seats,
    required this.status,
    this.uploadUrl,
    this.isDeleted = false,
    required this.vehicleName,
    this.createdAt,
    this.updatedAt,
    this.hasFutureBooking = false,
  });

  // 💡 ฟังก์ชันสําหรับก๊อปปี้ข้อมูลและเปลี่ยนบางค่า
  VehicleModel copyWith({
    int? id,
    String? plateNumber,
    String? brand,
    String? model,
    int? seats,
    String? status,
    String? uploadUrl,
    bool? isDeleted,
    String? vehicleName,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? hasFutureBooking,
  }) {
    return VehicleModel(
      id: id ?? this.id,
      plateNumber: plateNumber ?? this.plateNumber,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      seats: seats ?? this.seats,
      status: status ?? this.status,
      uploadUrl: uploadUrl ?? this.uploadUrl,
      isDeleted: isDeleted ?? this.isDeleted,
      vehicleName: vehicleName ?? this.vehicleName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hasFutureBooking: hasFutureBooking ?? this.hasFutureBooking,
    );
  }

  // 💡 แปลง JSON จาก API เป็น Object
  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'],
      plateNumber: json['plateNumber'] ?? '',
      brand: json['brand'] ?? '',
      model: json['model'] ?? '',
      seats: json['seats'] ?? 4,
      status: json['status'] ?? 'AVAILABLE',
      uploadUrl: json['uploadUrl'],
      isDeleted: json['isDeleted'] ?? false,
      vehicleName: json['vehicleName'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }
}

// ==========================================
// 📅 2. คลาสสำหรับเก็บโครงสร้างข้อมูลการจองรถ (VehicleBooking)
// ==========================================
class VehicleBookingModel {
  final int id;
  final int vehicleId;
  final int userId;
  final int? driverEmployeeId;
  final String destination;
  final DateTime
  startDatetime; // รวมวันที่และเวลาไว้ใน DateTime เดียวตาม Prisma
  final DateTime endDatetime;
  final String purpose;
  String status;
  final int passengers;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  VehicleBookingModel({
    required this.id,
    required this.vehicleId,
    required this.userId,
    this.driverEmployeeId,
    required this.destination,
    required this.startDatetime,
    required this.endDatetime,
    required this.purpose,
    this.status = 'Pending',
    this.passengers = 1,
    this.createdAt,
    this.updatedAt,
  });

  // 🔥 ฟังก์ชันอัจฉริยะ: เช็คสถานะตามเวลาจริงอัตโนมัติ
  String get currentStatus {
    // ถ้าระบบหลังบ้านส่งสถานะที่ไม่ได้รอดำเนินการมา (เช่น ยกเลิก หรือ อนุมัติแล้ว)
    if (status != 'Pending' && status != 'Approved') return status;

    final now = DateTime.now();
    if (now.isBefore(startDatetime)) {
      return 'จองแล้ว';
    } else if (now.isAfter(startDatetime) && now.isBefore(endDatetime)) {
      return 'กำลังใช้งาน';
    } else if (now.isAfter(endDatetime)) {
      return 'เสร็จสิ้น';
    }

    return status;
  }

  // 💡 แปลง JSON จาก API เป็น Object
  factory VehicleBookingModel.fromJson(Map<String, dynamic> json) {
    return VehicleBookingModel(
      id: json['id'],
      vehicleId: json['vehicleId'],
      userId: json['userId'],
      driverEmployeeId: json['driverEmployeeId'],
      destination: json['destination'] ?? '',
      startDatetime: DateTime.parse(json['startDatetime']),
      endDatetime: DateTime.parse(json['endDatetime']),
      purpose: json['purpose'] ?? '',
      status: json['status'] ?? 'Pending',
      passengers: json['passengers'] ?? 1,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }
}

// ==========================================
// 📋 3. คลาสสำหรับเก็บข้อมูลบันทึกการใช้รถ (VehicleLog)
// ==========================================
class VehicleLogModel {
  final int id;
  final int vehicleBookingId;
  final int checkoutById;
  final DateTime checkoutTime;
  final int checkoutMileage;
  final int checkoutFuelLevel;
  final int? returnById;
  final DateTime? returnTime;
  final int? returnMileage;
  final int? returnFuelLevel;
  final String? remark;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  VehicleLogModel({
    required this.id,
    required this.vehicleBookingId,
    required this.checkoutById,
    required this.checkoutTime,
    required this.checkoutMileage,
    required this.checkoutFuelLevel,
    this.returnById,
    this.returnTime,
    this.returnMileage,
    this.returnFuelLevel,
    this.remark,
    this.createdAt,
    this.updatedAt,
  });

  // 💡 แปลง JSON จาก API เป็น Object
  factory VehicleLogModel.fromJson(Map<String, dynamic> json) {
    return VehicleLogModel(
      id: json['id'],
      vehicleBookingId: json['vehicleBookingId'],
      checkoutById: json['checkoutById'],
      checkoutTime: DateTime.parse(json['checkoutTime']),
      checkoutMileage: json['checkoutMileage'],
      checkoutFuelLevel: json['checkoutFuelLevel'],
      returnById: json['returnById'],
      returnTime: json['returnTime'] != null
          ? DateTime.parse(json['returnTime'])
          : null,
      returnMileage: json['returnMileage'],
      returnFuelLevel: json['returnFuelLevel'],
      remark: json['remark'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }
}

// ==========================================
// 🌍 4. ตัวแปร Global ส่วนกลางสำหรับเก็บข้อมูล
// ==========================================
String globalCurrentUserName = "MMK"; // จำลองชื่อผู้ใช้งานล็อกอิน
int globalCurrentUserId = 1; // จำลอง ID ผู้ใช้งานล็อกอิน

// 🚗 ตัวแปรเก็บข้อมูลรถยนต์ทั้งหมด
final ValueNotifier<List<VehicleModel>> globalVehicles =
    ValueNotifier<List<VehicleModel>>([]);

// 📋 ตัวแปรเก็บประวัติการจองรถทั้งหมดในแอป (เริ่มต้นเป็นลิสต์ว่าง)
final ValueNotifier<List<VehicleBookingModel>> globalVehicleBookingHistory =
    ValueNotifier<List<VehicleBookingModel>>([]);
