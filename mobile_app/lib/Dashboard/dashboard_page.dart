import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_repository.dart';
import 'dashboard_model.dart';
import 'dashboard_loading.dart';
import 'dashboard_empty.dart';
import 'admin_dashboard.dart';
import 'user_dashboard.dart';
import 'security_dashboard.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DashboardRepository _repository = DashboardRepository();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool _isLoading = true;
  String? _errorMessage;
  String _userRole = 'USER'; // Default role

  AdminDashboardData? _adminData;
  UserDashboardData? _userData;
  SecurityDashboardData? _securityData;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  String? _getRoleFromToken(String? token) {
    if (token == null || token.isEmpty) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      String normalized = base64Url.normalize(parts[1]);
      String payloadString = utf8.decode(base64Url.decode(normalized));
      final Map<String, dynamic> payload = jsonDecode(payloadString);

      return payload['role']?.toString();
    } catch (e) {
      return null;
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. อ่าน Token จาก Storage
      final token =
          await _storage.read(key: 'token') ??
          await _storage.read(key: 'jwt') ??
          prefs.getString('token');

      // 2. ดึง Role จาก Token เป็นอันดับแรก
      String? role = _getRoleFromToken(token);
      role ??=
          await _storage.read(key: 'user_role') ??
          await _storage.read(key: 'role') ??
          await _storage.read(key: 'userRole') ??
          prefs.getString('user_role') ??
          prefs.getString('role') ??
          prefs.getString('userRole') ??
          'USER';

      _userRole = role.toString().replaceAll('"', '').trim().toUpperCase();

      switch (_userRole) {
        case 'ADMIN':
        case 'SUPER_ADMIN':
        case 'SUPERADMIN':
          _adminData = await _repository.getAdminDashboard();
          break;
        case 'SECURITY':
        case 'GUARD':
          _securityData = await _repository.getSecurityDashboard();
          break;
        default:
          _userData = await _repository.getUserDashboard();
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleExport(String type, String format) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token =
          await _storage.read(key: 'token') ??
          await _storage.read(key: 'jwt') ??
          prefs.getString('token');

      // กำหนด Base URL ตามสภาพแวดล้อม (Web ใช้ localhost, Emulator ใช้ 192.168.88.25:3001.2.2)
      final String baseUrl = kIsWeb
          ? 'http://192.168.88.25:3001'
          : 'http://192.168.88.25:3001';
      final Uri exportUrl = Uri.parse(
        '$baseUrl/api/reports/export?type=$type&format=csv&token=$token',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('กำลังดาวน์โหลดรายงาน $type ($format)...'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      if (await canLaunchUrl(exportUrl)) {
        await launchUrl(exportUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'ไม่สามารถเปิดลิงก์สำหรับดาวน์โหลดได้';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการดาวน์โหลด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('แดชบอร์ดและรายงาน'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'รีเฟรชข้อมูล',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const DashboardLoadingWidget();
    }

    if (_errorMessage != null) {
      return DashboardEmptyWidget(
        message: _errorMessage!,
        onRefresh: _loadDashboardData,
      );
    }

    if (_adminData != null) {
      return AdminDashboardView(
        data: _adminData!,
        onRefresh: _loadDashboardData,
        onExport: _handleExport,
      );
    }

    if (_securityData != null) {
      return SecurityDashboardView(
        data: _securityData!,
        onRefresh: _loadDashboardData,
      );
    }

    if (_userData != null) {
      return UserDashboardView(data: _userData!, onRefresh: _loadDashboardData);
    }

    return DashboardEmptyWidget(
      message: 'ไม่พบข้อมูลแดชบอร์ดสำหรับสิทธิ์การใช้งานนี้',
      onRefresh: _loadDashboardData,
    );
  }
}
