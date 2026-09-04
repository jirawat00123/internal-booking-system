// mobile_app/lib/Dashboard/dashboard_model.dart

import 'dart:convert';

/// Permissions Model - สำหรับทำ Backend-Driven UI
class DashboardPermissions {
  final bool canExportReport;
  final bool canManageSystem;
  final bool canCreateRoomBooking;
  final bool canCreateVehicleBooking;
  final bool canCheckOut;
  final bool canCheckIn;

  DashboardPermissions({
    this.canExportReport = false,
    this.canManageSystem = false,
    this.canCreateRoomBooking = false,
    this.canCreateVehicleBooking = false,
    this.canCheckOut = false,
    this.canCheckIn = false,
  });

  factory DashboardPermissions.fromJson(Map<String, dynamic> json) {
    return DashboardPermissions(
      canExportReport: json['canExportReport'] as bool? ?? false,
      canManageSystem: json['canManageSystem'] as bool? ?? false,
      canCreateRoomBooking: json['canCreateRoomBooking'] as bool? ?? false,
      canCreateVehicleBooking:
          json['canCreateVehicleBooking'] as bool? ?? false,
      canCheckOut: json['canCheckOut'] as bool? ?? false,
      canCheckIn: json['canCheckIn'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'canExportReport': canExportReport,
      'canManageSystem': canManageSystem,
      'canCreateRoomBooking': canCreateRoomBooking,
      'canCreateVehicleBooking': canCreateVehicleBooking,
      'canCheckOut': canCheckOut,
      'canCheckIn': canCheckIn,
    };
  }
}

/// 1. Admin Dashboard Data Model
class AdminDashboardData {
  final int totalRooms;
  final int totalVehicles;
  final int todayTotalBookings;
  final int activeUsers;
  final Map<String, int> roomStats;
  final Map<String, int> vehicleStats;
  final DashboardPermissions permissions;

  AdminDashboardData({
    required this.totalRooms,
    required this.totalVehicles,
    required this.todayTotalBookings,
    required this.activeUsers,
    required this.roomStats,
    required this.vehicleStats,
    required this.permissions,
  });

  factory AdminDashboardData.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? {};
    final roomStatsJson = json['roomStats'] as Map<String, dynamic>? ?? {};
    final vehicleStatsJson =
        json['vehicleStats'] as Map<String, dynamic>? ?? {};

    return AdminDashboardData(
      totalRooms: (summary['totalRooms'] as num?)?.toInt() ?? 0,
      totalVehicles: (summary['totalVehicles'] as num?)?.toInt() ?? 0,
      todayTotalBookings: (summary['todayTotalBookings'] as num?)?.toInt() ?? 0,
      activeUsers: (summary['activeUsers'] as num?)?.toInt() ?? 0,
      roomStats: roomStatsJson.map(
        (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
      ),
      vehicleStats: vehicleStatsJson.map(
        (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
      ),
      permissions: DashboardPermissions.fromJson(
        json['permissions'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

/// 2. User Dashboard Data Model
class UserDashboardData {
  final int myTotalBookings;
  final int pendingApprovals;
  final List<dynamic> recentRooms;
  final List<dynamic> recentVehicles;
  final DashboardPermissions permissions;

  UserDashboardData({
    required this.myTotalBookings,
    required this.pendingApprovals,
    required this.recentRooms,
    required this.recentVehicles,
    required this.permissions,
  });

  factory UserDashboardData.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? {};
    final recentBookings =
        json['recentBookings'] as Map<String, dynamic>? ?? {};

    return UserDashboardData(
      myTotalBookings: (summary['myTotalBookings'] as num?)?.toInt() ?? 0,
      pendingApprovals: (summary['pendingApprovals'] as num?)?.toInt() ?? 0,
      recentRooms: recentBookings['rooms'] as List<dynamic>? ?? [],
      recentVehicles: recentBookings['vehicles'] as List<dynamic>? ?? [],
      permissions: DashboardPermissions.fromJson(
        json['permissions'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

/// 3. Security Dashboard Data Model
class SecurityDashboardData {
  final int vehiclesInUse;
  final int todayCheckoutCount;
  final int waitingReturnCount;
  final List<dynamic> todayLogs;
  final DashboardPermissions permissions;

  SecurityDashboardData({
    required this.vehiclesInUse,
    required this.todayCheckoutCount,
    required this.waitingReturnCount,
    required this.todayLogs,
    required this.permissions,
  });

  factory SecurityDashboardData.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? {};

    return SecurityDashboardData(
      vehiclesInUse: (summary['vehiclesInUse'] as num?)?.toInt() ?? 0,
      todayCheckoutCount: (summary['todayCheckoutCount'] as num?)?.toInt() ?? 0,
      waitingReturnCount: (summary['waitingReturnCount'] as num?)?.toInt() ?? 0,
      todayLogs: json['todayLogs'] as List<dynamic>? ?? [],
      permissions: DashboardPermissions.fromJson(
        json['permissions'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

/// 4. Dashboard Stats & Summary Models
class DashboardSummary {
  final int totalEmployees;
  final int totalVehicles;
  final int totalRooms;
  final int totalBookings;
  final int totalPending;
  final int totalApproved;
  final int totalInUse;

  DashboardSummary({
    required this.totalEmployees,
    required this.totalVehicles,
    required this.totalRooms,
    required this.totalBookings,
    required this.totalPending,
    required this.totalApproved,
    required this.totalInUse,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      totalEmployees: (json['totalEmployees'] as num?)?.toInt() ?? 0,
      totalVehicles: (json['totalVehicles'] as num?)?.toInt() ?? 0,
      totalRooms: (json['totalRooms'] as num?)?.toInt() ?? 0,
      totalBookings: (json['totalBookings'] as num?)?.toInt() ?? 0,
      totalPending: (json['totalPending'] as num?)?.toInt() ?? 0,
      totalApproved: (json['totalApproved'] as num?)?.toInt() ?? 0,
      totalInUse: (json['totalInUse'] as num?)?.toInt() ?? 0,
    );
  }
}

class VehicleOverview {
  final int available;
  final int inUse;
  final int maintenance;
  final int inactive;
  final int reserved;

  VehicleOverview({
    required this.available,
    required this.inUse,
    required this.maintenance,
    required this.inactive,
    required this.reserved,
  });

  factory VehicleOverview.fromJson(Map<String, dynamic> json) {
    return VehicleOverview(
      available: (json['AVAILABLE'] as num?)?.toInt() ?? 0,
      inUse: (json['IN_USE'] as num?)?.toInt() ?? 0,
      maintenance: (json['MAINTENANCE'] as num?)?.toInt() ?? 0,
      inactive: (json['INACTIVE'] as num?)?.toInt() ?? 0,
      reserved: (json['RESERVED'] as num?)?.toInt() ?? 0,
    );
  }
}

class BookingStatusCounts {
  final int pending;
  final int approved;
  final int inUse;
  final int completed;
  final int cancelled;
  final int rejected;

  BookingStatusCounts({
    required this.pending,
    required this.approved,
    required this.inUse,
    required this.completed,
    required this.cancelled,
    required this.rejected,
  });

  factory BookingStatusCounts.fromJson(Map<String, dynamic> json) {
    return BookingStatusCounts(
      pending: (json['PENDING'] as num?)?.toInt() ?? 0,
      approved: (json['APPROVED'] as num?)?.toInt() ?? 0,
      inUse: (json['IN_USE'] as num?)?.toInt() ?? 0,
      completed: (json['COMPLETED'] as num?)?.toInt() ?? 0,
      cancelled: (json['CANCELLED'] as num?)?.toInt() ?? 0,
      rejected: (json['REJECTED'] as num?)?.toInt() ?? 0,
    );
  }
}

class BookingOverviewData {
  final BookingStatusCounts room;
  final BookingStatusCounts vehicle;

  BookingOverviewData({
    required this.room,
    required this.vehicle,
  });

  factory BookingOverviewData.fromJson(Map<String, dynamic> json) {
    return BookingOverviewData(
      room: BookingStatusCounts.fromJson(
        json['room'] as Map<String, dynamic>? ?? {},
      ),
      vehicle: BookingStatusCounts.fromJson(
        json['vehicle'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class RecentBooking {
  final String id;
  final String bookerName;
  final String type;
  final String itemName;
  final DateTime? date;
  final String status;
  final DateTime? createdAt;

  RecentBooking({
    required this.id,
    required this.bookerName,
    required this.type,
    required this.itemName,
    this.date,
    required this.status,
    this.createdAt,
  });

  factory RecentBooking.fromJson(Map<String, dynamic> json) {
    return RecentBooking(
      id: json['id'] as String? ?? '',
      bookerName: json['bookerName'] as String? ?? '',
      type: json['type'] as String? ?? '',
      itemName: json['itemName'] as String? ?? '',
      date: json['date'] != null ? DateTime.tryParse(json['date'].toString()) : null,
      status: json['status'] as String? ?? '',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }
}

class DashboardData {
  final DashboardSummary summary;
  final VehicleOverview vehicleOverview;
  final BookingOverviewData bookingOverview;
  final List<RecentBooking> recentBookings;

  DashboardData({
    required this.summary,
    required this.vehicleOverview,
    required this.bookingOverview,
    required this.recentBookings,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final recentList = json['recentBookings'] as List<dynamic>? ?? [];
    return DashboardData(
      summary: DashboardSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? {},
      ),
      vehicleOverview: VehicleOverview.fromJson(
        json['vehicleOverview'] as Map<String, dynamic>? ?? {},
      ),
      bookingOverview: BookingOverviewData.fromJson(
        json['bookingOverview'] as Map<String, dynamic>? ?? {},
      ),
      recentBookings: recentList
          .map((item) => RecentBooking.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
