import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  // 1. สร้าง Singleton Pattern เพื่อให้เรียกใช้งานได้จากทุกที่อย่างปลอดภัย (หรือจะใช้คู่กับ Riverpod/Provider ก็ได้)
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  // 2. เรียกใช้งาน Secure Storage
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // 3. กำหนด Key เป็น Private Constant เพื่อป้องกันการพิมพ์ผิด
  static const String _tokenKey = 'SECURE_AUTH_TOKEN';

  // 4. Private Variable สำหรับเก็บ Token ไว้ใน Memory (Runtime) เพื่อจะได้ไม่ต้อง I/O อ่านจาก Storage ทุกครั้งที่เรียก API
  String? _accessToken;

  /// บันทึก Token เมื่อ Login สำเร็จ
  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
    _accessToken = token;
  }

  /// ดึง Token เพื่อนำไปใช้กับ API (เช่น นำไปใส่ใน Header)
  Future<String?> getToken() async {
    // ถ้าใน Memory มีอยู่แล้วให้คืนค่าเลย ถ้าไม่มีค่อยไปดึงจาก Secure Storage
    _accessToken ??= await _storage.read(key: _tokenKey);
    return _accessToken;
  }

  /// ลบ Token เมื่อกด Logout หรือ Token หมดอายุ
  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
    _accessToken = null;
  }

  /// เช็คว่า User Login อยู่หรือไม่
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}