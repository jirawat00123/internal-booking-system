// mobile_app/lib/Dashboard/dashboard_repository.dart

import 'dashboard_service.dart';
import 'dashboard_model.dart';

class DashboardRepository {
  final DashboardService _service;

  DashboardRepository({DashboardService? service})
    : _service = service ?? DashboardService();

  Future<AdminDashboardData> getAdminDashboard() async {
    final res = await _service.fetchAdminDashboard();
    if (res['success'] == true && res['data'] != null) {
      return AdminDashboardData.fromJson(res['data']);
    }
    throw Exception('ไม่สามารถแปลงข้อมูล Admin Dashboard ได้');
  }

  Future<UserDashboardData> getUserDashboard() async {
    final res = await _service.fetchUserDashboard();
    if (res['success'] == true && res['data'] != null) {
      return UserDashboardData.fromJson(res['data']);
    }
    throw Exception('ไม่สามารถแปลงข้อมูล User Dashboard ได้');
  }

  Future<SecurityDashboardData> getSecurityDashboard() async {
    final res = await _service.fetchSecurityDashboard();
    if (res['success'] == true && res['data'] != null) {
      return SecurityDashboardData.fromJson(res['data']);
    }
    throw Exception('ไม่สามารถแปลงข้อมูล Security Dashboard ได้');
  }
}
