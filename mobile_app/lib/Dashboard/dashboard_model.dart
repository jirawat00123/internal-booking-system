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
