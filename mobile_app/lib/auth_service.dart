import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  // 1. สร้าง Singleton Pattern เพื่อให้เรียกใช้งานได้จากทุกที่อย่างปลอดภัย (หรือจะใช้คู่กับ Riverpod/Provider ก็ได้)
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  // 2. เรียกใช้งาน Secure Storage
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // 3. กำหนด Key เป็น Private Constant เพื่อป้องกันการพิมพ์ผิด
  static const String _tokenKey = 'jwt_token';
  static const String _roleKey = 'user_role';
  static const String _modeKey = 'current_mode'; // เพิ่ม Key สำหรับเก็บ Mode

  // Base URL กลางสำหรับเรียกใช้งาน API ทุกตัวในระบบ
  static const String baseUrl = 'http://192.168.88.25:3001';

  // 4. Private Variable สำหรับเก็บ Token ไว้ใน Memory (Runtime) เพื่อจะได้ไม่ต้อง I/O อ่านจาก Storage ทุกครั้งที่เรียก API
  String? _accessToken;
  String? _userRole;
  String? _currentMode; // เพิ่มตัวแปรสำหรับเก็บ Mode ใน Memory

  /// บันทึก Token เมื่อ Login สำเร็จ
  Future<void> saveToken(String token) async {
    _accessToken = token; // กำหนดค่าใน Memory ทันทีเพื่อให้ระบบทำงานต่อได้
    try {
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: 'token', value: token);
    } catch (e) {
      print('⚠️ Storage write error (Web fallback to memory): $e');
    }
  }

  /// ดึง Token เพื่อนำไปใช้กับ API (เช่น นำไปใส่ใน Header)
  Future<String?> getToken() async {
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      return _accessToken;
    }
    try {
      _accessToken ??= await _storage.read(key: _tokenKey);
      _accessToken ??= await _storage.read(key: 'token');
    } catch (e) {
      print('⚠️ Storage read error: $e');
    }
    return _accessToken;
  }

  /// ลบ Token เมื่อกด Logout หรือ Token หมดอายุ
  Future<void> deleteToken() async {
    _accessToken = null;
    _userRole = null;
    _currentMode = null; // ลบ Mode ออกจาก Memory
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: 'token');
      await _storage.delete(key: _roleKey);
      await _storage.delete(key: _modeKey); // ลบ Mode ออกจาก Storage
    } catch (e) {
      print('⚠️ Storage delete error: $e');
    }
  }

  /// บันทึก Role จาก API ลง Storage
  Future<void> saveRole(String role) async {
    _userRole = role;
    try {
      await _storage.write(key: _roleKey, value: role);
    } catch (e) {
      print('⚠️ Storage write error (Role): $e');
    }
  }

  /// ดึง Role เพื่อใช้ตรวจสอบสิทธิ์ในแอป
  Future<String?> getRole() async {
    if (_userRole != null && _userRole!.isNotEmpty) {
      return _userRole;
    }
    try {
      _userRole = await _storage.read(key: _roleKey);
    } catch (e) {
      print('⚠️ Storage read error (Role): $e');
    }
    return _userRole;
  }

  /// บันทึก Mode หน้าจอ (ADMIN_MODE, USER_MODE)
  Future<void> saveMode(String mode) async {
    _currentMode = mode;
    try {
      await _storage.write(key: _modeKey, value: mode);
    } catch (e) {
      print('⚠️ Storage write error (Mode): $e');
    }
  }

  /// ดึง Mode ที่กำลังใช้งานปัจจุบัน
  Future<String?> getMode() async {
    if (_currentMode != null && _currentMode!.isNotEmpty) {
      return _currentMode;
    }
    try {
      _currentMode = await _storage.read(key: _modeKey);
    } catch (e) {
      print('⚠️ Storage read error (Mode): $e');
    }
    return _currentMode;
  }

  /// เช็คว่า User Login อยู่หรือไม่
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
