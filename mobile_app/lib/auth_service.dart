import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _tokenKey = 'jwt_token';
  static const String _roleKey = 'user_role';
  static const String _modeKey = 'current_mode';
  static const String _employeeCodeKey = 'employee_code';
  static const String _hasPinKey = 'has_pin';
  static const String _pinResetRequiredKey = 'pin_reset_required';

  static const String baseUrl = 'https://192.168.88.25:3002';

  String? _accessToken;
  String? _userRole;
  String? _currentMode;
  String? _employeeCode;
  bool? _hasPin;
  bool? _pinResetRequired;

  Future<void> saveToken(String token) async {
    _accessToken = token;
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token);
        await prefs.setString('token', token);
      } else {
        await _storage.write(key: _tokenKey, value: token);
        await _storage.write(key: 'token', value: token);
      }
    } catch (e) {
      debugPrint('⚠️ Storage write error (Web fallback to memory): $e');
    }
  }

  Future<String?> getToken() async {
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      return _accessToken;
    }
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        _accessToken ??= prefs.getString(_tokenKey);
        _accessToken ??= prefs.getString('token');
      } else {
        _accessToken ??= await _storage.read(key: _tokenKey);
        _accessToken ??= await _storage.read(key: 'token');
      }
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
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_tokenKey);
        await prefs.remove('token');
        await prefs.remove(_roleKey);
        await prefs.remove(_modeKey);
        await prefs.remove(_employeeCodeKey);
        await prefs.remove('employeeCode');
        await prefs.remove(_hasPinKey);
        await prefs.remove(_pinResetRequiredKey);
      } else {
        await _storage.delete(key: _tokenKey);
        await _storage.delete(key: 'token');
        await _storage.delete(key: _roleKey);
        await _storage.delete(key: _modeKey);
        await _storage.delete(key: _employeeCodeKey);
        await _storage.delete(key: 'employeeCode');
        await _storage.delete(key: _hasPinKey);
        await _storage.delete(key: _pinResetRequiredKey);
      }
    } catch (e) {
      debugPrint('⚠️ Storage delete error: $e');
    }
  }

  Future<void> logout() async {
    await deleteToken();
  }

  Future<void> saveRole(String role) async {
    _userRole = role;
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_roleKey, role);
      } else {
        await _storage.write(key: _roleKey, value: role);
      }
    } catch (e) {
      debugPrint('⚠️ Storage write error (Role): $e');
    }
  }

  Future<String?> getRole() async {
    if (_userRole != null && _userRole!.isNotEmpty) {
      return _userRole;
    }
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        _userRole = prefs.getString(_roleKey);
      } else {
        _userRole = await _storage.read(key: _roleKey);
      }
    } catch (e) {
      debugPrint('⚠️ Storage read error (Role): $e');
    }
    return _userRole;
  }

  Future<void> saveMode(String mode) async {
    _currentMode = mode;
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_modeKey, mode);
      } else {
        await _storage.write(key: _modeKey, value: mode);
      }
    } catch (e) {
      debugPrint('⚠️ Storage write error (Mode): $e');
    }
  }

  Future<String?> getMode() async {
    if (_currentMode != null && _currentMode!.isNotEmpty) {
      return _currentMode;
    }
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        _currentMode = prefs.getString(_modeKey);
      } else {
        _currentMode = await _storage.read(key: _modeKey);
      }
    } catch (e) {
      debugPrint('⚠️ Storage read error (Mode): $e');
    }
    return _currentMode;
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> saveEmployeeCode(String employeeCode) async {
    _employeeCode = employeeCode;
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_employeeCodeKey, employeeCode);
        await prefs.setString('employeeCode', employeeCode);
      } else {
        await _storage.write(key: _employeeCodeKey, value: employeeCode);
        await _storage.write(key: 'employeeCode', value: employeeCode);
      }
    } catch (e) {
      debugPrint('⚠️ Storage write error (EmployeeCode): $e');
    }
  }

  Future<String?> getEmployeeCode() async {
    if (_employeeCode != null && _employeeCode!.isNotEmpty) {
      return _employeeCode;
    }
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        _employeeCode ??= prefs.getString(_employeeCodeKey);
        _employeeCode ??= prefs.getString('employeeCode');
      } else {
        _employeeCode ??= await _storage.read(key: _employeeCodeKey);
        _employeeCode ??= await _storage.read(key: 'employeeCode');
      }
    } catch (e) {
      debugPrint('⚠️ Storage read error (EmployeeCode): $e');
    }
    return _employeeCode;
  }

  Future<void> savePinStatus({
    required bool hasPin,
    required bool pinResetRequired,
  }) async {
    _hasPin = hasPin;
    _pinResetRequired = pinResetRequired;
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_hasPinKey, hasPin);
        await prefs.setBool(_pinResetRequiredKey, pinResetRequired);
      } else {
        await _storage.write(key: _hasPinKey, value: hasPin.toString());
        await _storage.write(
          key: _pinResetRequiredKey,
          value: pinResetRequired.toString(),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Storage write error (PinStatus): $e');
    }
  }

  Future<bool> getHasPin() async {
    if (_hasPin != null) return _hasPin!;
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        _hasPin = prefs.getBool(_hasPinKey);
      } else {
        final val = await _storage.read(key: _hasPinKey);
        _hasPin = val == 'true';
      }
    } catch (e) {
      debugPrint('⚠️ Storage read error (HasPin): $e');
      _hasPin = false;
    }
    return _hasPin ?? false;
  }

  Future<bool> getPinResetRequired() async {
    if (_pinResetRequired != null) return _pinResetRequired!;
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        _pinResetRequired = prefs.getBool(_pinResetRequiredKey);
      } else {
        final val = await _storage.read(key: _pinResetRequiredKey);
        _pinResetRequired = val == 'true';
      }
    } catch (e) {
      debugPrint('⚠️ Storage read error (PinResetRequired): $e');
      _pinResetRequired = false;
    }
    return _pinResetRequired ?? false;
  }
}
