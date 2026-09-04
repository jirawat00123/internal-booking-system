import 'dart:convert';
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
  final DateTime? actIssueDate;
  final DateTime? actExpiryDate;
  final String? actUploadUrl;
  final String? actDocumentUrl;
  final String? pororborUrl;

  String? get fullImageUrl {
    if (uploadUrl == null || uploadUrl!.isEmpty) return null;
    if (uploadUrl!.startsWith('http://') || uploadUrl!.startsWith('https://')) {
      return uploadUrl;
    }
    const String baseUrl = 'https://192.168.88.25:3002';
    return uploadUrl!.startsWith('/')
        ? '$baseUrl$uploadUrl'
        : '$baseUrl/$uploadUrl';
  }

  String? get fullActUrl {
    final rawUrl = actDocumentUrl ?? actUploadUrl ?? pororborUrl;
    if (rawUrl == null || rawUrl.isEmpty) return null;
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      return rawUrl;
    }
    const String baseUrl = 'https://192.168.88.25:3002';
    return rawUrl.startsWith('/') ? '$baseUrl$rawUrl' : '$baseUrl/$rawUrl';
  }

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
    this.actIssueDate,
    this.actExpiryDate,
    this.actUploadUrl,
    this.actDocumentUrl,
    this.pororborUrl,
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
    DateTime? actIssueDate,
    DateTime? actExpiryDate,
    String? actUploadUrl,
    String? actDocumentUrl,
    String? pororborUrl,
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
      actIssueDate: actIssueDate ?? this.actIssueDate,
      actExpiryDate: actExpiryDate ?? this.actExpiryDate,
      actUploadUrl: actUploadUrl ?? this.actUploadUrl,
      actDocumentUrl: actDocumentUrl ?? this.actDocumentUrl,
      pororborUrl: pororborUrl ?? this.pororborUrl,
    );
  }

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    // 🟢 ดึงข้อมูลเอกสาร พ.ร.บ. จาก Array documents
    String? actDocNum;
    DateTime? actIssueDate;
    DateTime? actExpDate;
    String? actUrl;

    if (json['documents'] is List && (json['documents'] as List).isNotEmpty) {
      final docs = json['documents'] as List;
      final actDoc = docs.firstWhere(
        (doc) =>
            doc is Map &&
            doc['documentType'] != null &&
            (doc['documentType']['name'] == 'พ.ร.บ.' ||
                doc['documentType']['name'] == 'ACT' ||
                doc['documentType']['name'] == 'พรบ.' ||
                doc['documentType']['name'] == 'พรบ'),
        orElse: () => null,
      );

      if (actDoc != null) {
        actDocNum = actDoc['documentNumber'] ?? actDoc['document_number'];
        actIssueDate =
            actDoc['issueDate'] != null || actDoc['issue_date'] != null
            ? DateTime.tryParse(
                (actDoc['issueDate'] ?? actDoc['issue_date']).toString(),
              )
            : null;
        actExpDate =
            actDoc['expiryDate'] != null || actDoc['expiry_date'] != null
            ? DateTime.tryParse(
                (actDoc['expiryDate'] ?? actDoc['expiry_date']).toString(),
              )
            : null;
        actUrl =
            actDoc['uploadUrl'] ??
            actDoc['upload_url'] ??
            actDoc['filePath'] ??
            actDoc['file_path'] ??
            actDoc['url'] ??
            actDoc['act_upload_url'] ??
            actDoc['actUploadUrl'];
      }
    }

    return VehicleModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      plateNumber:
          json['plateNumber'] ??
          json['license_plate'] ??
          json['plate_number'] ??
          '',
      province: json['province']?.toString(),
      brand: json['brand']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      seats: json['seats'] is int
          ? json['seats']
          : int.tryParse(json['seats']?.toString() ?? '4') ?? 4,
      status: json['status']?.toString() ?? 'AVAILABLE',
      uploadUrl:
          json['uploadUrl'] ??
          json['upload_url'] ??
          json['imageUrl'] ??
          json['image_url'] ??
          json['image'],
      isDeleted: json['isDeleted'] == true || json['is_deleted'] == true,
      type: json['type']?.toString() ?? 'รถยนต์',
      vehicleName:
          (json['vehicleName'] != null &&
              json['vehicleName'].toString().trim().isNotEmpty)
          ? json['vehicleName'].toString()
          : (json['vehicle_name'] != null &&
                json['vehicle_name'].toString().trim().isNotEmpty)
          ? json['vehicle_name'].toString()
          : '${json['brand'] ?? ''} ${json['model'] ?? ''}'.trim(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : (json['created_at'] != null
                ? DateTime.tryParse(json['created_at'].toString())
                : null),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : (json['updated_at'] != null
                ? DateTime.tryParse(json['updated_at'].toString())
                : null),
      actDocumentNumber:
          actDocNum ??
          json['actDocumentNumber']?.toString() ??
          json['documentNumber']?.toString(),
      actIssueDate:
          actIssueDate ??
          (json['actIssueDate'] != null || json['issueDate'] != null
              ? DateTime.tryParse(
                  (json['actIssueDate'] ?? json['issueDate']).toString(),
                )
              : null),
      actExpiryDate:
          actExpDate ??
          (json['actExpiryDate'] != null || json['expiryDate'] != null
              ? DateTime.tryParse(
                  (json['actExpiryDate'] ?? json['expiryDate']).toString(),
                )
              : null),
      actUploadUrl:
          actUrl ??
          json['actUploadUrl'] ??
          json['act_upload_url'] ??
          json['act_file_path'] ??
          json['actFilePath'],
      actDocumentUrl:
          actUrl ??
          json['actDocumentUrl'] ??
          json['actFilePath'] ??
          json['act_file_path'] ??
          json['actFile'] ??
          json['act_file'] ??
          json['actUrl'] ??
          json['actUploadUrl'] ??
          json['act_upload_url'] ??
          json['pororborUrl'],
      pororborUrl:
          actUrl ??
          json['pororborUrl'] ??
          json['actDocumentUrl'] ??
          json['actFilePath'] ??
          json['act_file_path'] ??
          json['actFile'] ??
          json['act_file'] ??
          json['actUrl'] ??
          json['actUploadUrl'] ??
          json['act_upload_url'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'plateNumber': plateNumber,
      'province': province,
      'brand': brand,
      'model': model,
      'seats': seats,
      'status': status,
      'uploadUrl': uploadUrl,
      'isDeleted': isDeleted,
      'type': type,
      'vehicleName': vehicleName,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'hasFutureBooking': hasFutureBooking,
      'actDocumentNumber': actDocumentNumber,
      'actIssueDate': actIssueDate?.toIso8601String(),
      'actExpiryDate': actExpiryDate?.toIso8601String(),
      'actUploadUrl': actUploadUrl,
      'actDocumentUrl': actDocumentUrl,
      'actFilePath': actDocumentUrl,
      'pororborUrl': pororborUrl ?? actDocumentUrl,
    };
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
  final List<String> passengerNames;
  final VehicleModel? vehicle; // 🟢 เก็บ Object ข้อมูลรถที่แนบมาด้วย
  final BookingPermissions permissions; // 🟢 สิทธิ์จาก Backend
  final DateTime?
  createdAt; // 🟢 เพิ่ม createdAt สำหรับจัดเรียงและตรวจสอบประวัติ
  final List<String>? checkOutImages; // 🟢 เก็บรูปถ่ายตอนปล่อยรถ
  final List<String>? checkInImages; // 🟢 เก็บรูปถ่ายตอนรับรถเข้า

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
    this.passengerNames = const [],
    this.vehicle,
    BookingPermissions? permissions,
    this.createdAt,
    this.checkOutImages,
    this.checkInImages,
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

    List<String> parsedPassengerNames = [];
    if (json['passengerDetails'] is List) {
      parsedPassengerNames = (json['passengerDetails'] as List)
          .map(
            (item) => item is Map
                ? (item['passengerName']?.toString() ??
                      item['name']?.toString() ??
                      '')
                : item.toString(),
          )
          .where((n) => n.isNotEmpty)
          .toList();
    } else if (json['passengerNames'] is List) {
      parsedPassengerNames = (json['passengerNames'] as List)
          .map((item) => item.toString())
          .where((n) => n.isNotEmpty)
          .toList();
    } else if (json['passengerNames'] is String &&
        (json['passengerNames'] as String).isNotEmpty) {
      try {
        final decoded = jsonDecode(json['passengerNames']);
        if (decoded is List) {
          parsedPassengerNames = decoded
              .map((e) => e.toString())
              .where((n) => n.isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }

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
      passengerNames: parsedPassengerNames,
      vehicle: json['vehicle'] != null
          ? VehicleModel.fromJson(json['vehicle'])
          : null,
      permissions: BookingPermissions.fromJson(json['permissions']),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : (json['created_at'] != null
                ? DateTime.tryParse(json['created_at'])
                : null),
      checkOutImages: json['checkOutImages'] != null
          ? List<String>.from(json['checkOutImages'])
          : (json['check_out_images'] != null
                ? List<String>.from(json['check_out_images'])
                : null),
      checkInImages: json['checkInImages'] != null
          ? List<String>.from(json['checkInImages'])
          : (json['check_in_images'] != null
                ? List<String>.from(json['check_in_images'])
                : null),
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
