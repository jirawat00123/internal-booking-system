import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart'; // เพิ่มสำหรับการใช้ debugPrint แก้ไข Warning avoid_print

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
  static const String _employeeCodeKey =
      'employee_code'; // 🟢 เพิ่ม Key สำหรับเก็บรหัสพนักงาน
  static const String _hasPinKey =
      'has_pin'; // 🟢 เพิ่ม Key สำหรับเก็บสถานะ PIN
  static const String _pinResetRequiredKey =
      'pin_reset_required'; // 🟢 เพิ่ม Key สำหรับเก็บ Flag รีเซ็ต PIN

  // Base URL กลางสำหรับเรียกใช้งาน API ทุกตัวในระบบ
  static const String baseUrl = 'http://localhost:3001';

  // 4. Private Variable สำหรับเก็บ Token ไว้ใน Memory (Runtime) เพื่อจะได้ไม่ต้อง I/O อ่านจาก Storage ทุกครั้งที่เรียก API
  String? _accessToken;
  String? _userRole;
  String? _currentMode; // เพิ่มตัวแปรสำหรับเก็บ Mode ใน Memory
  String? _employeeCode; // 🟢 เพิ่มตัวแปรสำหรับเก็บรหัสพนักงานใน Memory
  bool? _hasPin; // 🟢 เพิ่มตัวแปรเก็บสถานะ PIN ใน Memory
  bool? _pinResetRequired; // 🟢 เพิ่มตัวแปรเก็บ Flag รีเซ็ต PIN ใน Memory

  /// บันทึก Token เมื่อ Login สำเร็จ
  Future<void> saveToken(String token) async {
    _accessToken = token; // กำหนดค่าใน Memory ทันทีเพื่อให้ระบบทำงานต่อได้
    try {
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: 'token', value: token);
    } catch (e) {
      debugPrint('⚠️ Storage write error (Web fallback to memory): $e');
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
      debugPrint('⚠️ Storage read error: $e');
    }
    return _accessToken;
  }

  /// ลบ Token เมื่อกด Logout หรือ Token หมดอายุ
  Future<void> deleteToken() async {
    _accessToken = null;
    _userRole = null;
    _currentMode = null; // ลบ Mode ออกจาก Memory
    _employeeCode = null; // 🟢 ลบรหัสพนักงานออกจาก Memory
    _hasPin = null; // 🟢 ลบสถานะ PIN ออกจาก Memory
    _pinResetRequired = null; // 🟢 ลบ Flag รีเซ็ต PIN ออกจาก Memory
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: 'token');
      await _storage.delete(key: _roleKey);
      await _storage.delete(key: _modeKey); // ลบ Mode ออกจาก Storage
      await _storage.delete(
        key: _employeeCodeKey,
      ); // 🟢 ลบรหัสพนักงานออกจาก Storage
      await _storage.delete(
        key: 'employeeCode',
      ); // 🟢 ลบ Key สำรองเพื่อป้องกัน State ค้าง
      await _storage.delete(key: _hasPinKey); // 🟢 ลบสถานะ PIN ออกจาก Storage
      await _storage.delete(
        key: _pinResetRequiredKey,
      ); // 🟢 ลบ Flag รีเซ็ต PIN ออกจาก Storage
    } catch (e) {
      debugPrint('⚠️ Storage delete error: $e');
    }
  }

  /// 🟢 ฟังก์ชันสำหรับเรียกใช้งานเมื่อกด Logout (Clear Session ออกจาก Memory และ Storage 100%)
  Future<void> logout() async {
    await deleteToken();
  }

  /// บันทึก Role จาก API ลง Storage
  Future<void> saveRole(String role) async {
    _userRole = role;
    try {
      await _storage.write(key: _roleKey, value: role);
    } catch (e) {
      debugPrint('⚠️ Storage write error (Role): $e');
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
      debugPrint('⚠️ Storage read error (Role): $e');
    }
    return _userRole;
  }

  /// บันทึก Mode หน้าจอ (ADMIN_MODE, USER_MODE)
  Future<void> saveMode(String mode) async {
    _currentMode = mode;
    try {
      await _storage.write(key: _modeKey, value: mode);
    } catch (e) {
      debugPrint('⚠️ Storage write error (Mode): $e');
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
      debugPrint('⚠️ Storage read error (Mode): $e');
    }
    return _currentMode;
  }

  /// เช็คว่า User Login อยู่หรือไม่
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// 🟢 บันทึกรหัสพนักงาน (Employee Code) ลง Storage
  Future<void> saveEmployeeCode(String employeeCode) async {
    _employeeCode = employeeCode;
    try {
      await _storage.write(key: _employeeCodeKey, value: employeeCode);
    } catch (e) {
      debugPrint('⚠️ Storage write error (EmployeeCode): $e');
    }
  }

  /// 🟢 ดึงรหัสพนักงานที่กำลังใช้งาน
  Future<String?> getEmployeeCode() async {
    if (_employeeCode != null && _employeeCode!.isNotEmpty) {
      return _employeeCode;
    }
    try {
      _employeeCode = await _storage.read(key: _employeeCodeKey);
    } catch (e) {
      debugPrint('⚠️ Storage read error (EmployeeCode): $e');
    }
    return _employeeCode;
  }

  /// 🟢 บันทึกสถานะ PIN (hasPin, pinResetRequired)
  Future<void> savePinStatus({
    required bool hasPin,
    required bool pinResetRequired,
  }) async {
    _hasPin = hasPin;
    _pinResetRequired = pinResetRequired;
    try {
      await _storage.write(key: _hasPinKey, value: hasPin.toString());
      await _storage.write(
        key: _pinResetRequiredKey,
        value: pinResetRequired.toString(),
      );
    } catch (e) {
      debugPrint('⚠️ Storage write error (PinStatus): $e');
    }
  }

  /// 🟢 ดึงสถานะ hasPin
  Future<bool> getHasPin() async {
    if (_hasPin != null) return _hasPin!;
    try {
      final val = await _storage.read(key: _hasPinKey);
      _hasPin = val == 'true';
    } catch (e) {
      debugPrint('⚠️ Storage read error (HasPin): $e');
      _hasPin = false;
    }
    return _hasPin ?? false;
  }

  /// 🟢 ดึงสถานะ pinResetRequired
  Future<bool> getPinResetRequired() async {
    if (_pinResetRequired != null) return _pinResetRequired!;
    try {
      final val = await _storage.read(key: _pinResetRequiredKey);
      _pinResetRequired = val == 'true';
    } catch (e) {
      debugPrint('⚠️ Storage read error (PinResetRequired): $e');
      _pinResetRequired = false;
    }
    return _pinResetRequired ?? false;
  }
}
