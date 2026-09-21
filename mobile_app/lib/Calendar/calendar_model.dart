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
  final Map<String, dynamic>? roomInfo;
  final Map<String, dynamic>? vehicleInfo;

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
    this.roomInfo,
    this.vehicleInfo,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    String rawStatus = json['status'] ?? 'UNKNOWN';
    if (rawStatus.toUpperCase() == 'APPROVED') {
      rawStatus = 'RESERVED';
    }

    return CalendarEvent(
      eventId: json['eventId'] ?? '',
      originalId: json['originalId'] ?? 0,
      type: json['type'] ?? '',
      title: json['title'] ?? 'ไม่มีชื่อ',
      bookerName: json['bookerName'] ?? 'ไม่ระบุชื่อผู้จอง',
      start: DateTime.parse(
        (json['start'] ?? json['startDatetime']).toString(),
      ).toLocal(),
      end: DateTime.parse(
        (json['end'] ?? json['endDatetime'] ?? json['returnDate']).toString(),
      ).toLocal(),
      colorHex: json['color'] ?? '#42BCA4',
      status: rawStatus,
      roomInfo: json['roomInfo'],
      vehicleInfo: json['vehicleInfo'],
    );
  }

  // กำหนดสีของการจองตาม Booking Status
  Color get color {
    switch (status.toUpperCase()) {
      case 'RESERVED':
      case 'PENDING':
        return const Color(0xFFF59E0B); // สีเหลืองส้ม (#F59E0B)
      case 'APPROVED':
        return const Color(0xFF2EC4B6); // สีเขียวมิ้นต์
      case 'IN_USE':
        return const Color(0xFF004381); // สีน้ำเงินเข้ม
      case 'COMPLETED':
        return const Color(0xFF9E9E9E); // สีเทา
      case 'EXPIRED':
        return const Color(0xFFE11D48); // สีแดง
      default:
        return const Color(0xFF00A8CC); // สีตั้งต้น
    }
  }
}

class VehicleCalendarGrid {
  final int vehicleId;
  final String vehicleName;
  final String plateNumber;
  final String? upload_url;
  final List<BookingItem> bookings;

  String? get imageUrl => upload_url;

  VehicleCalendarGrid({
    required this.vehicleId,
    required this.vehicleName,
    required this.plateNumber,
    this.upload_url,
    required this.bookings,
  });

  factory VehicleCalendarGrid.fromJson(Map<String, dynamic> json) {
    return VehicleCalendarGrid(
      vehicleId: json['vehicleId'],
      vehicleName: json['vehicleName'] ?? '',
      plateNumber: json['plateNumber'] ?? '',
      upload_url:
          json['upload_url'] ??
          json['uploadUrl'] ??
          json['imageUrl'] ??
          json['image'] ??
          json['vehicle']?['upload_url'] ??
          json['vehicle']?['uploadUrl'] ??
          json['vehicle']?['imageUrl'] ??
          json['vehicle']?['image'],
      bookings: (json['bookings'] as List? ?? [])
          .map((b) => BookingItem.fromJson(b))
          .toList(),
    );
  }
}

class BookingItem {
  final int id;
  final String userName;
  final String purpose;
  final DateTime startDatetime;
  final DateTime endDatetime;
  final String status;

  BookingItem({
    required this.id,
    required this.userName,
    required this.purpose,
    required this.startDatetime,
    required this.endDatetime,
    required this.status,
  });

  factory BookingItem.fromJson(Map<String, dynamic> json) {
    return BookingItem(
      id: json['id'],
      userName: json['userName'] ?? '-',
      purpose: json['purpose'] ?? '-',
      startDatetime: DateTime.parse(json['startDatetime'].toString()).toLocal(),
      endDatetime: DateTime.parse(json['endDatetime'].toString()).toLocal(),
      status: json['status'] ?? '',
    );
  }
}

class RoomCalendarGrid {
  final int roomId;
  final String roomName;
  final String location;
  final String? floor;
  final String? upload_url;
  final List<BookingItem> bookings;

  String? get imageUrl => upload_url;

  RoomCalendarGrid({
    required this.roomId,
    required this.roomName,
    required this.location,
    this.floor,
    this.upload_url,
    required this.bookings,
  });

  factory RoomCalendarGrid.fromJson(Map<String, dynamic> json) {
    return RoomCalendarGrid(
      roomId: json['roomId'],
      roomName: json['roomName'] ?? '',
      location: json['location'] ?? '',
      floor: json['floor']?.toString(),
      upload_url:
          json['upload_url'] ??
          json['uploadUrl'] ??
          json['imageUrl'] ??
          json['image'] ??
          json['room']?['upload_url'] ??
          json['room']?['uploadUrl'] ??
          json['room']?['imageUrl'] ??
          json['room']?['image'],
      bookings: (json['bookings'] as List? ?? [])
          .map((b) => BookingItem.fromJson(b))
          .toList(),
    );
  }
}
