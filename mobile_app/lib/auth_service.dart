import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum RefreshStatus { success, unauthorized, networkOrServerError, noToken }

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
  static const String _fullNameKey = 'full_name';

  static const String baseUrl = 'https://192.168.88.25:3002';

  /// แปลง Path รูปภาพให้เป็น Full URL ชี้ไปที่ Backend (Port 3002)
  static String getImageUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path.replaceAll(':8443', ':3002');
    }
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$cleanPath';
  }

  String? _accessToken;
  String? _userRole;
  String? _currentMode;
  String? _employeeCode;
  bool? _hasPin;
  bool? _pinResetRequired;
  String? _fullName;
  Timer? _refreshTimer;

  // 🟢 เพิ่ม Flag ป้องกันการเรียก API ซ้ำซ้อน (Lock flags)
  bool _isLoggingOut = false;
  bool _isRefreshing = false;
  bool _isTransactionInProgress = false;

  /// ซ่อน Token เพื่อให้ Log ปลอดภัย
  String _maskToken(String? token) {
    if (token == null || token.length < 12) return 'invalid_token';
    return '${token.substring(0, 6)}...${token.substring(token.length - 6)}';
  }

  /// ตรวจสอบว่า Token ยังไม่หมดอายุในเครื่อง
  bool isTokenValid(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload['exp'] == null) return false;
      final exp = payload['exp'] as int;
      final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return (exp - currentTime) > 60;
    } catch (e) {
      return false;
    }
  }

  /// ล็อค/ปลดล็อค เมื่อมีการทำ Transaction สำคัญ เช่น กดส่งจองรถ/จองห้อง
  void setTransactionInProgress(bool inProgress) {
    _isTransactionInProgress = inProgress;
    if (inProgress) {
      debugPrint('🔒 [AUTH] Transaction in progress - locking silent refresh');
    } else {
      debugPrint('🔓 [AUTH] Transaction completed - unlocking silent refresh');
    }
  }

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
    stopSilentRefresh();
    _accessToken = null;
    _userRole = null;
    _currentMode = null; // ลบ Mode ออกจาก Memory
    _employeeCode = null; // 🟢 ลบรหัสพนักงานออกจาก Memory
    _hasPin = null; // 🟢 ลบสถานะ PIN ออกจาก Memory
    _pinResetRequired = null; // 🟢 ลบ Flag รีเซ็ต PIN ออกจาก Memory
    _fullName = null;
    try {
      // 🟢 ล้าง SharedPreferences ทั้งบน Web และ Mobile เพื่อให้ชัวร์ว่าไม่มีค่าค้าง
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove('token');
      await prefs.remove(_roleKey);
      await prefs.remove('role');
      await prefs.remove(_modeKey);
      await prefs.remove('current_mode');
      await prefs.remove(_employeeCodeKey);
      await prefs.remove('employeeCode');
      await prefs.remove(_hasPinKey);
      await prefs.remove(_pinResetRequiredKey);
      await prefs.remove(_fullNameKey);
      await prefs.remove('fullName');
      await prefs.remove('pin'); // 🟢 เพิ่มการลบ PIN
      await prefs.remove('username'); // 🟢 เพิ่มการลบ Username

      if (!kIsWeb) {
        // 🟢 ล้างข้อมูลทั้งหมดใน Secure Storage แบบ 100% ป้องกัน session เดิมหลงเหลือ
        await _storage.deleteAll();
      }
    } catch (e) {
      debugPrint('⚠️ Storage delete error: $e');
    }
  }

  Future<void> logout() async {
    if (_isLoggingOut) return; // 🟢 ป้องกันการกดซ้ำ
    _isLoggingOut = true;
    stopSilentRefresh(); // 🟢 หยุด Silent Refresh ทันที ป้องกันการยิง Refresh Token แทรกระหว่างออกจากระบบ

    try {
      final token = await getToken();
      // 🟢 ดึง employeeCode จากเครื่องเพื่อส่งเป็นข้อมูลสำรองไปให้ Backend
      final currentEmployeeCode = await getEmployeeCode();

      // 🟢 อนุญาตให้ยิง API ถ้ามี Token "หรือ" มี employeeCode สำรอง
      if ((token != null && token.isNotEmpty) ||
          (currentEmployeeCode != null && currentEmployeeCode.isNotEmpty)) {
        final response = await http
            .post(
              Uri.parse('$baseUrl/api/auth/logout'),
              headers: {
                'Content-Type': 'application/json',
                // 🟢 แนบ Token เฉพาะเมื่อมีค่า ป้องกัน Header Error
                if (token != null && token.isNotEmpty)
                  'Authorization': 'Bearer $token',
              },
              // 🟢 แนบ Body สำรองไว้ กรณี Token หมดอายุ Backend จะได้หา User เจอจาก employeeCode
              body: jsonEncode({
                if (currentEmployeeCode != null &&
                    currentEmployeeCode.isNotEmpty)
                  'employeeCode': currentEmployeeCode,
              }),
            )
            .timeout(
              const Duration(seconds: 10),
            ); // 🟢 ขยาย Timeout เป็น 10 วินาที ป้องกัน Request ขาดกลางคัน
        debugPrint('✅ Logout API Status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('⚠️ Logout API Error: $e');
    } finally {
      await deleteToken();
      _isLoggingOut = false; // 🟢 ปลดล็อคเมื่อทำงานเสร็จ
    }
  }

  /// ตั้งค่าเข้าสู่ระบบในฐานะ Guest โดยล้าง Token ทั้งหมด และกำหนด Role/Mode เป็น GUEST
  Future<void> loginAsGuest() async {
    await deleteToken();
    await saveRole('GUEST');
    await saveMode('GUEST');
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

  Future<void> saveFullName(String fullName) async {
    _fullName = fullName;
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_fullNameKey, fullName);
        await prefs.setString('fullName', fullName);
      } else {
        await _storage.write(key: _fullNameKey, value: fullName);
        await _storage.write(key: 'fullName', value: fullName);
      }
    } catch (e) {
      debugPrint('⚠️ Storage write error (FullName): $e');
    }
  }

  Future<String?> getFullName() async {
    if (_fullName != null && _fullName!.isNotEmpty) {
      return _fullName;
    }
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        _fullName ??= prefs.getString(_fullNameKey);
        _fullName ??= prefs.getString('fullName');
      } else {
        _fullName ??= await _storage.read(key: _fullNameKey);
        _fullName ??= await _storage.read(key: 'fullName');
      }
    } catch (e) {
      debugPrint('⚠️ Storage read error (FullName): $e');
    }
    return _fullName;
  }

  /// รีเฟรช Token และระบุสถานะของผลลัพธ์อย่างละเอียด
  Future<RefreshStatus> refreshTokenDetailed() async {
    if (_isRefreshing) {
      debugPrint('[AUTH] Refresh skipped - another refresh in progress');
      return RefreshStatus.networkOrServerError;
    }
    if (_isTransactionInProgress) {
      debugPrint('[AUTH] Refresh skipped - request in progress');
      return RefreshStatus.networkOrServerError;
    }

    _isRefreshing = true;

    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[AUTH] Refresh failed: No token found');
        return RefreshStatus.noToken;
      }

      debugPrint(
        '[AUTH] Silent refresh request started with token: ${_maskToken(token)}',
      );

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/auth/refresh'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('[AUTH] Refresh response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['token'] != null) {
          final newToken = data['token'] as String;
          await saveToken(newToken);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_tokenKey, newToken);
          await prefs.setString('token', newToken);

          debugPrint('[AUTH] Token updated: ${_maskToken(newToken)}');
          return RefreshStatus.success;
        }
      } else if (response.statusCode == 401) {
        debugPrint('[AUTH] Session invalid - logout');
        return RefreshStatus.unauthorized;
      } else {
        debugPrint(
          '[AUTH] Refresh failed: Server status ${response.statusCode}',
        );
        return RefreshStatus.networkOrServerError;
      }
    } catch (e) {
      debugPrint(
        '[AUTH] Refresh failed: $e (Network or Timeout - Session preserved)',
      );
      return RefreshStatus.networkOrServerError;
    } finally {
      _isRefreshing = false;
    }

    return RefreshStatus.networkOrServerError;
  }

  Future<bool> refreshToken() async {
    final status = await refreshTokenDetailed();
    return status == RefreshStatus.success;
  }

  /// เริ่มระบบ Silent Refresh ทุกๆ 20 นาที
  void startSilentRefresh() {
    stopSilentRefresh();
    debugPrint('[AUTH] Silent refresh started (Every 20 minutes)');

    _refreshTimer = Timer.periodic(const Duration(minutes: 20), (timer) async {
      if (_isTransactionInProgress) {
        debugPrint('[AUTH] Refresh skipped - request in progress');
        return;
      }

      final result = await refreshTokenDetailed();
      if (result == RefreshStatus.unauthorized) {
        debugPrint('[AUTH] Session invalid - logout');
        stopSilentRefresh();
        await deleteToken();
      } else if (result == RefreshStatus.networkOrServerError) {
        debugPrint(
          '[AUTH] Refresh failed - network error, keeping session for next cycle',
        );
      }
    });
  }

  /// หยุด Timer เมื่อ Logout หรือลบ Token
  void stopSilentRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// ตรวจสอบสถานะ PIN ของพนักงานก่อนเข้าสู่ระบบ
  Future<Map<String, dynamic>> checkPinStatus(String employeeCode) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'employeeCode': employeeCode}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'pinInitialized': data['pinInitialized'] ?? false,
          'pinResetRequired': data['pinResetRequired'] ?? false,
          'requireSetupPin': data['requireSetupPin'] ?? false,
          'message': data['message'] ?? '',
          'error': null,
          'statusCode': response.statusCode,
        };
      } else {
        return {
          'success': false,
          'pinInitialized': false,
          'pinResetRequired': false,
          'requireSetupPin': false,
          'message': null,
          'error':
              data['error'] ??
              data['message'] ??
              'เกิดข้อผิดพลาดในการตรวจสอบสถานะ PIN',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      debugPrint('❌ checkPinStatus Error: $e');
      return {
        'success': false,
        'pinInitialized': false,
        'pinResetRequired': false,
        'requireSetupPin': false,
        'message': null,
        'error': 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้',
        'statusCode': 500,
      };
    }
  }

  /// เข้าสู่ระบบด้วย employeeCode และ PIN
  Future<Map<String, dynamic>> login({
    required String employeeCode,
    required String pin,
    String? expectedRole,
    bool force = false,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'employeeCode': employeeCode,
              'pin': pin,
              if (expectedRole != null) 'expectedRole': expectedRole,
              if (force) 'force': true,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (data['token'] != null) {
          final token = data['token'] as String;
          await saveToken(token);
          if (data['role'] != null) await saveRole(data['role']);
          await saveEmployeeCode(employeeCode);
          if (data['fullName'] != null) await saveFullName(data['fullName']);
          await savePinStatus(
            hasPin: data['pinInitialized'] ?? true,
            pinResetRequired: data['pinResetRequired'] ?? false,
          );
          debugPrint('[AUTH] Login success');
          debugPrint(
            '[AUTH] Token expires in: 30m (Masked: ${_maskToken(token)})',
          );
          startSilentRefresh();
        }
        return {...data, 'error': null, 'statusCode': response.statusCode};
      } else {
        return {
          'success': false,
          'token': null,
          'role': null,
          'message': data['message'],
          'error': data['error'] ?? data['message'] ?? 'เข้าสู่ระบบไม่สำเร็จ',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      debugPrint('❌ Login Error: $e');
      return {
        'success': false,
        'token': null,
        'role': null,
        'message': null,
        'error': 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้',
        'statusCode': 500,
      };
    }
  }

  /// เข้าสู่ระบบด้วย PIN อย่างเดียว หรือ PIN + employeeCode (/login-pin)
  Future<Map<String, dynamic>> loginPin({
    required String pin,
    String? employeeCode,
    String? expectedRole,
    bool force = false,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/auth/login-pin'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'pin': pin,
              if (employeeCode != null && employeeCode.isNotEmpty)
                'employeeCode': employeeCode,
              if (expectedRole != null && expectedRole.isNotEmpty)
                'expectedRole': expectedRole,
              if (force) 'force': true,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (data['token'] != null) {
          final token = data['token'] as String;
          await saveToken(token);
          if (data['role'] != null) await saveRole(data['role']);
          if (employeeCode != null && employeeCode.isNotEmpty) {
            await saveEmployeeCode(employeeCode);
          }
          debugPrint('[AUTH] Login success');
          debugPrint(
            '[AUTH] Token expires in: 30m (Masked: ${_maskToken(token)})',
          );
          startSilentRefresh();
        }
        return {...data, 'error': null, 'statusCode': response.statusCode};
      } else {
        return {
          'success': false,
          'token': null,
          'role': null,
          'message': data['message'],
          'error':
              data['error'] ??
              data['message'] ??
              'เข้าสู่ระบบด้วย PIN ไม่สำเร็จ',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      debugPrint('❌ Login PIN Error: $e');
      return {
        'success': false,
        'token': null,
        'role': null,
        'message': null,
        'error': 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้',
        'statusCode': 500,
      };
    }
  }
}
