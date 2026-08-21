import 'package:flutter/material.dart';

// 💡 1. คลาสโมเดลสำหรับเก็บสิทธิ์การกระทำของ Booking (Dumb UI Pattern)
// หมายเหตุ: หากมีการ Import ไฟล์นี้ชนกับ Room_model อาจต้องย้ายคลาสนี้ไปไว้ในไฟล์ Shared Model กลาง
class BookingPermissions {
  final bool canCancel;
  final bool canEdit;

  BookingPermissions({this.canCancel = false, this.canEdit = false});

  factory BookingPermissions.fromJson(Map<String, dynamic>? json) {
    if (json == null) return BookingPermissions();
    return BookingPermissions(
      canCancel: json['canCancel'] ?? false,
      canEdit: json['canEdit'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {'canCancel': canCancel, 'canEdit': canEdit};
  }
}

// ==========================================
// 🚗 2. คลาสโมเดลสำหรับเก็บข้อมูลรถยนต์ (Vehicle)
// ==========================================
class VehicleModel {
  final int id;
  final String plateNumber;
  final String? province;
  final String brand;
  final String model;
  final int seats;
  final String status;
  final String? uploadUrl;
  final bool isDeleted;
  final String type;
  final String vehicleName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool hasFutureBooking;
  final String? actDocumentNumber;
  final DateTime? actExpiryDate;
  final String? actUploadUrl;

  VehicleModel({
    required this.id,
    required this.plateNumber,
    this.province,
    required this.brand,
    required this.model,
    required this.seats,
    required this.status,
    this.uploadUrl,
    this.isDeleted = false,
    this.type = 'รถยนต์',
    required this.vehicleName,
    this.createdAt,
    this.updatedAt,
    this.hasFutureBooking = false,
    this.actDocumentNumber,
    this.actExpiryDate,
    this.actUploadUrl,
  });

  VehicleModel copyWith({
    int? id,
    String? plateNumber,
    String? province,
    String? brand,
    String? model,
    int? seats,
    String? status,
    String? uploadUrl,
    bool? isDeleted,
    String? type,
    String? vehicleName,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? hasFutureBooking,
    String? actDocumentNumber,
    DateTime? actExpiryDate,
    String? actUploadUrl,
  }) {
    return VehicleModel(
      id: id ?? this.id,
      plateNumber: plateNumber ?? this.plateNumber,
      province: province ?? this.province,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      seats: seats ?? this.seats,
      status: status ?? this.status,
      uploadUrl: uploadUrl ?? this.uploadUrl,
      isDeleted: isDeleted ?? this.isDeleted,
      type: type ?? this.type,
      vehicleName: vehicleName ?? this.vehicleName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hasFutureBooking: hasFutureBooking ?? this.hasFutureBooking,
      actDocumentNumber: actDocumentNumber ?? this.actDocumentNumber,
      actExpiryDate: actExpiryDate ?? this.actExpiryDate,
      actUploadUrl: actUploadUrl ?? this.actUploadUrl,
    );
  }

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    // 🟢 ดึงข้อมูลเอกสาร พ.ร.บ. จาก Array documents
    String? actDocNum;
    DateTime? actExpDate;
    String? actUrl;

    if (json['documents'] is List && (json['documents'] as List).isNotEmpty) {
      final docs = json['documents'] as List;
      final actDoc = docs.firstWhere(
        (doc) =>
            doc is Map &&
            doc['documentType'] != null &&
            (doc['documentType']['name'] == 'พ.ร.บ.' ||
                doc['documentType']['name'] == 'ACT'),
        orElse: () => null,
      );

      if (actDoc != null) {
        actDocNum = actDoc['documentNumber'] ?? actDoc['document_number'];
        actExpDate =
            actDoc['expiryDate'] != null || actDoc['expiry_date'] != null
            ? DateTime.tryParse(actDoc['expiryDate'] ?? actDoc['expiry_date'])
            : null;
        actUrl = actDoc['uploadUrl'] ?? actDoc['upload_url'];
      }
    }

    return VehicleModel(
      id: json['id'],
      plateNumber:
          json['plateNumber'] ??
          json['license_plate'] ??
          '', // รองรับทั้ง camelCase และ snake_case
      province: json['province'],
      brand: json['brand'] ?? '',
      model: json['model'] ?? '',
      seats: json['seats'] ?? 4,
      status: json['status'] ?? 'AVAILABLE',
      uploadUrl: json['uploadUrl'] ?? json['upload_url'],
      isDeleted: json['isDeleted'] ?? json['is_deleted'] ?? false,
      type: json['type'] ?? 'รถยนต์',
      vehicleName: json['vehicleName'] ?? json['vehicle_name'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
      actDocumentNumber:
          actDocNum ?? json['actDocumentNumber'] ?? json['documentNumber'],
      actExpiryDate:
          actExpDate ??
          (json['actExpiryDate'] != null || json['expiryDate'] != null
              ? DateTime.tryParse(json['actExpiryDate'] ?? json['expiryDate'])
              : null),
      actUploadUrl: actUrl ?? json['actUploadUrl'] ?? json['act_upload_url'],
    );
  }
}

// ==========================================
// 📅 3. คลาสสำหรับเก็บโครงสร้างข้อมูลการจองรถ (VehicleBooking)
// ==========================================
class VehicleBookingModel {
  final int id;
  final int vehicleId;
  final int userId;
  final String userName; // 🟢 เพิ่มชื่อผู้จอง
  final String destination;
  final DateTime startDatetime;
  final DateTime endDatetime;
  final String purpose;
  final String rawStatus; // 🟢 รับค่าตรงจาก Backend ไม่ใช้การคำนวณซ้ำซ้อน
  final int passengers;
  final VehicleModel? vehicle; // 🟢 เก็บ Object ข้อมูลรถที่แนบมาด้วย
  final BookingPermissions permissions; // 🟢 สิทธิ์จาก Backend

  VehicleBookingModel({
    required this.id,
    required this.vehicleId,
    required this.userId,
    required this.userName,
    required this.destination,
    required this.startDatetime,
    required this.endDatetime,
    required this.purpose,
    this.rawStatus = 'PENDING',
    this.passengers = 1,
    this.vehicle,
    BookingPermissions? permissions,
  }) : permissions = permissions ?? BookingPermissions();

  // 🟢 แสดงข้อความสถานะภาษาไทยตามค่าจาก Backend
  String get currentStatus {
    switch (rawStatus) {
      case 'IN_USE':
        return 'กำลังใช้งาน';
      case 'COMPLETED':
        return 'เสร็จสิ้น';
      case 'CANCELLED':
        return 'ยกเลิกแล้ว';
      case 'APPROVED':
        return 'อนุมัติแล้ว';
      case 'PENDING':
        return 'รออนุมัติ';
      case 'REJECTED':
        return 'ปฏิเสธ';
      default:
        return rawStatus;
    }
  }

  factory VehicleBookingModel.fromJson(Map<String, dynamic> json) {
    // 🟢 ดึงชื่อผู้ใช้จากการ Join ของ Prisma
    final userObj = json['user'];
    final employeeObj = userObj != null ? userObj['employee'] : null;
    final name = employeeObj != null
        ? employeeObj['fullName'] ?? employeeObj['full_name'] ?? 'ผู้ใช้งาน'
        : 'ผู้ใช้งาน';

    return VehicleBookingModel(
      id: json['id'],
      vehicleId: json['vehicleId'] ?? json['vehicle_id'],
      userId: json['userId'] ?? json['user_id'],
      userName: name,
      destination: json['destination'] ?? '',
      startDatetime: DateTime.parse(
        json['startDatetime'] ??
            json['start_datetime'] ??
            DateTime.now().toIso8601String(),
      ),
      endDatetime: DateTime.parse(
        json['endDatetime'] ??
            json['end_datetime'] ??
            json['returnDate'] ??
            json['return_date'] ??
            DateTime.now().toIso8601String(),
      ),
      purpose: json['purpose'] ?? '',
      rawStatus: json['status'] ?? 'PENDING',
      passengers: json['passengers'] ?? 1,
      vehicle: json['vehicle'] != null
          ? VehicleModel.fromJson(json['vehicle'])
          : null,
      permissions: BookingPermissions.fromJson(json['permissions']),
    );
  }
}

// ==========================================
// 📋 4. คลาสสำหรับเก็บข้อมูลบันทึกการใช้รถ (VehicleLog)
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

  factory VehicleLogModel.fromJson(Map<String, dynamic> json) {
    return VehicleLogModel(
      id: json['id'],
      vehicleBookingId: json['vehicleBookingId'] ?? json['vehicle_booking_id'],
      checkoutById: json['checkoutById'] ?? json['checkout_by_id'],
      checkoutTime: DateTime.parse(
        json['checkoutTime'] ??
            json['checkout_time'] ??
            DateTime.now().toIso8601String(),
      ),
      checkoutMileage: json['checkoutMileage'] ?? json['checkout_mileage'] ?? 0,
      checkoutFuelLevel:
          json['checkoutFuelLevel'] ?? json['checkout_fuel_level'] ?? 0,
      returnById: json['returnById'] ?? json['return_by_id'],
      returnTime: json['returnTime'] != null
          ? DateTime.tryParse(json['returnTime'])
          : null,
      returnMileage: json['returnMileage'] ?? json['return_mileage'],
      returnFuelLevel: json['returnFuelLevel'] ?? json['return_fuel_level'],
      remark: json['remark'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
    );
  }
}

// ==========================================
// 🌍 5. ตัวแปร Global ส่วนกลางสำหรับเก็บข้อมูล
// ==========================================
String globalCurrentUserName = "MMK";
int globalCurrentUserId = 1;

final ValueNotifier<List<VehicleModel>> globalVehicles =
    ValueNotifier<List<VehicleModel>>([]);

final ValueNotifier<List<VehicleBookingModel>> globalVehicleBookingHistory =
    ValueNotifier<List<VehicleBookingModel>>([]);
