import 'package:flutter/material.dart';
import 'dart:convert'; // 🟢 เพิ่มสำหรับจัดการ JSON
import 'package:http/http.dart' as http; // 🟢 เพิ่มสำหรับยิง API
import 'auth_service.dart'; // 🟢 เพิ่มการนำเข้า AuthService เพื่อล้างเซสชันตอนกดออกจากระบบ

// 🏢 ฟีเจอร์จองห้องประชุม (User)
import 'package:mobile_app/Booking_room/Room_list.dart';

// 🚗 ฟีเจอร์จองยานพาหนะ (User)
import 'package:mobile_app/Booking_vehicle/vehicle_list.dart';

// 📦 ไฟล์แกนหลักและหน้าตั้งค่า
import 'package:mobile_app/Book_history.dart';
import 'package:mobile_app/Manage.dart';
import 'package:mobile_app/Select.dart';
import 'package:mobile_app/user_setting_page.dart';
import 'Dashboard/dashboard_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'AdminGroupPage.dart';

class UserMenuPage extends StatefulWidget {
  // 🟢 รองรับการเข้าใช้งานในฐานะ Guest
  final bool isGuest;

  const UserMenuPage({super.key, this.isGuest = false});

  @override
  State<UserMenuPage> createState() => _UserMenuPageState();
}

class _UserMenuPageState extends State<UserMenuPage> {
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminRole();
  }

  // 🛡️ ตรวจสอบสิทธิ์ว่าผู้ใช้ปัจจุบันมี role เป็น ADMIN หรือไม่
  Future<void> _checkAdminRole() async {
    if (!mounted) return;

    setState(() {
      _isAdmin = false;
    });

    if (widget.isGuest) return;

    try {
      final token = await AuthService.instance.getToken();
      if (token != null && token.isNotEmpty) {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payloadStr = utf8.decode(
            base64Url.decode(base64Url.normalize(parts[1])),
          );
          final payload = jsonDecode(payloadStr);
          final role = payload['role']?.toString().toUpperCase();
          final employeeCode = payload['employeeCode']?.toString();
          final fullName = payload['fullName']?.toString();

          final isAdminRole = (role == 'ADMIN');

          if (!mounted) return;

          setState(() {
            _isAdmin = isAdminRole;
          });

          debugPrint(
            'LOGIN SUCCESS -> employeeCode: $employeeCode | role: $role | fullName: $fullName | current_mode: ${isAdminRole ? "ADMIN_MODE" : "USER_MODE"} | _isAdmin: $_isAdmin',
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('Error checking admin role: $e');
    }

    if (!mounted) return;
    setState(() {
      _isAdmin = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ==========================================
          // Layer 1: Background Image
          // ==========================================
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF00529B),
              image: DecorationImage(
                image: AssetImage('assets/images/bgmmk.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // ==========================================
          // Layer 2: Main Content
          // ==========================================
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Image.asset(
                              'assets/images/MMK_logo.png',
                              height: 100,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: 300,
                              height: 2,
                              color: Colors.white.withOpacity(0.7),
                            ),
                            const SizedBox(height: 40),
                            const Text(
                              'ยินดีต้อนรับ',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'Kanit',
                              ),
                            ),
                            const SizedBox(height: 6),
                            // 🟢 ข้อความต้อนรับปรับเปลี่ยนตามสถานะ Guest
                            Text(
                              widget.isGuest
                                  ? 'โหมดผู้เยี่ยมชม (ดูได้อย่างเดียว)'
                                  : 'โปรดเลือกรายการเข้าทำเพื่อดำเนินการต่อ',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.8),
                                fontFamily: 'Kanit',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 🏢 เมนูที่ 1: ห้องประชุม
                    SelectionCard(
                      icon: Icons.groups_outlined,
                      title: 'ห้องประชุม',
                      subtitle: widget.isGuest
                          ? 'ตารางการใช้ห้องประชุม'
                          : 'จองห้องประชุม',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                RoomListScreen(isGuest: widget.isGuest),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // 🚗 เมนูที่ 2: ยานพาหนะ
                    SelectionCard(
                      icon: Icons.directions_car_filled_outlined,
                      title: 'ยานพาหนะ',
                      subtitle: widget.isGuest
                          ? 'ตารางการใช้ยานพาหนะ'
                          : 'จองรถ',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                VehicleBooking(isGuest: widget.isGuest),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // 📜 เมนูที่ 3: ประวัติการจอง (โชว์เฉพาะผู้ใช้งานปกติ)
                    if (!widget.isGuest) ...[
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const BookingHistoryScreen(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.history,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text(
                            'ประวัติการจอง',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontFamily: 'Kanit',
                            ),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.3),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 50),
                    ] else ...[
                      const SizedBox(height: 30),
                    ],

                    // Footer
                    Center(
                      child: Column(
                        children: [
                          Container(
                            height: 1.5,
                            width: 300,
                            color: Colors.white.withOpacity(0.4),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'MENAM MECHANIKA © 2026',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                              fontFamily: 'Kanit',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),

          // ==========================================
          // Layer 3: Top Right Actions (Setting & Logout)
          // ==========================================
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0, top: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🌟 ปุ่มสลับเป็น Admin Mode (แสดงเฉพาะผู้ใช้ที่มี role เป็น ADMIN)
                    if (!widget.isGuest && _isAdmin)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('current_mode', 'ADMIN_MODE');

                            try {
                              const storage = FlutterSecureStorage();
                              await storage.write(
                                key: 'current_mode',
                                value: 'ADMIN_MODE',
                              );
                            } catch (e) {
                              debugPrint(
                                "⚠️ SecureStorage Write Error (Mode): $e",
                              );
                            }

                            if (!context.mounted) return;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AdminGroupPage(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.swap_horiz,
                            color: Colors.white,
                            size: 16,
                          ),
                          label: const Text(
                            'โหมดแอดมิน',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontFamily: 'Kanit',
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.orange.withOpacity(0.8),
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ),
                    // ⚙️ ปุ่มตั้งค่า (โชว์เฉพาะผู้ใช้งานปกติ)
                    if (!widget.isGuest)
                      IconButton(
                        icon: const Icon(
                          Icons.settings_outlined,
                          color: Colors.white,
                          size: 26,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UserSettingPage(),
                            ),
                          );
                        },
                      ),
                    // 🚪 ปุ่ม Logout
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          // 🟢 1. แสดง Dialog ยืนยันการออกจากระบบ ป้องกันการกดผิดพลาด
                          final shouldLogout = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: const Text(
                                'ยืนยันการออกจากระบบ',
                                style: TextStyle(
                                  fontFamily: 'Kanit',
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00529B),
                                ),
                              ),
                              content: const Text(
                                'คุณต้องการออกจากระบบใช่หรือไม่?',
                                style: TextStyle(fontFamily: 'Kanit'),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text(
                                    'ยกเลิก',
                                    style: TextStyle(
                                      fontFamily: 'Kanit',
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text(
                                    'ออกจากระบบ',
                                    style: TextStyle(
                                      fontFamily: 'Kanit',
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (shouldLogout != true) return;

                          // 🟢 2. เคลียร์ข้อมูลเซสชันทั้งหมดแบบ 100% (ล้างทั้ง Memory และ Storage)
                          await AuthService.instance.logout();

                          if (!context.mounted) return;

                          // 🟢 3. กลับไปหน้าแรกและเคลียร์ Stack ทิ้งป้องกัน State ค้าง
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginSelectionPage(),
                            ),
                            (route) => false,
                          );
                        },
                        icon: const Icon(
                          Icons.logout,
                          color: Colors.white,
                          size: 16,
                        ),
                        label: const Text(
                          'ออกจากระบบ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'Kanit',
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.8),
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// Custom Widget: SelectionCard
// ==========================================
class SelectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const SelectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 14.0,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F1F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 28, color: const Color(0xFF00529B)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontFamily: 'Kanit',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontFamily: 'Kanit',
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F1F5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Color(0xFF00529B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
