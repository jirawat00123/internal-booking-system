// Room_model.dart
import 'package:flutter/material.dart';

// 💡 1. คลาสโมเดลสำหรับเก็บสิทธิ์การกระทำของ Booking (Dumb UI Pattern)
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

// 💡 2. คลาสโมเดลสำหรับเก็บข้อมูลห้องประชุม
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
      roomName: json['roomName'] ?? json['room_name'] ?? '',
      location: json['location'] ?? '',
      capacity: json['capacity'] is int
          ? json['capacity']
          : int.tryParse(json['capacity'].toString()) ?? 0,
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

// 💡 3. คลาสสำหรับเก็บโครงสร้างข้อมูลการจองห้องประชุม
class BookingHistory {
  final int? id;
  final String roomId;
  final String title;
  final String date;
  final DateTime startTime;
  final DateTime endTime;
  final int participantCount;
  final String type;
  final String bookedBy;
  final String rawStatus;
  final MeetingRoom? room;
  final BookingPermissions permissions; // 🟢 สิทธิ์ที่ส่งมาจาก Backend

  BookingHistory({
    this.id,
    required this.roomId,
    required this.title,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.participantCount,
    required this.type,
    required this.bookedBy,
    this.rawStatus = 'RESERVED',
    this.room,
    BookingPermissions? permissions,
  }) : permissions = permissions ?? BookingPermissions();

  // 🟢 Factory constructor สำหรับ Parse JSON จาก Backend
  factory BookingHistory.fromJson(Map<String, dynamic> json) {
    final start =
        DateTime.tryParse(json['startDatetime'] ?? '') ?? DateTime.now();
    final end = DateTime.tryParse(json['endDatetime'] ?? '') ?? DateTime.now();

    // แปลงวันที่ให้อยู่ในรูปแบบ DD/MM/YYYY สำหรับแสดงผล
    final formattedDate =
        "${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year}";

    final userObj = json['user'];
    final employeeObj = userObj != null ? userObj['employee'] : null;
    final userName = employeeObj != null
        ? employeeObj['fullName'] ?? employeeObj['full_name'] ?? 'ผู้ใช้งาน'
        : 'ผู้ใช้งาน';

    return BookingHistory(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()),
      roomId: json['roomId']?.toString() ?? json['room_id']?.toString() ?? '',
      title: json['purpose'] ?? json['title'] ?? 'การประชุม',
      date: formattedDate,
      startTime: start,
      endTime: end,
      participantCount: json['participantCount'] ?? 0,
      type: 'ห้องประชุม',
      bookedBy: userName,
      rawStatus: json['status'] ?? 'RESERVED',
      room: json['room'] != null ? MeetingRoom.fromJson(json['room']) : null,
      permissions: BookingPermissions.fromJson(json['permissions']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomId': roomId,
      'purpose': title,
      'startDatetime': startTime.toIso8601String(),
      'endDatetime': endTime.toIso8601String(),
      'status': rawStatus,
      'permissions': permissions.toJson(),
    };
  }

  // 🟢 แสดงข้อความสถานะภาษาไทยตามค่าจาก Backend
  String get currentStatus {
    switch (rawStatus) {
      case 'RESERVED':
        return 'จองแล้ว';
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
}

String globalCurrentUserName = "MMK";
int globalRoomUserId = 0;

final ValueNotifier<List<BookingHistory>> globalBookingHistory =
    ValueNotifier<List<BookingHistory>>([]);

final ValueNotifier<List<MeetingRoom>> globalMeetingRooms =
    ValueNotifier<List<MeetingRoom>>([]);
