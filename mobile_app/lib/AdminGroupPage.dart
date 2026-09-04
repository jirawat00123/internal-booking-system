import 'package:mobile_app/Admin/users/users_page.dart';
import 'package:mobile_app/Admin/vehicle/vehicle_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '/Admin/room/Admin_roompage.dart';
import 'Select.dart';
import 'Book_history.dart'; // นำเข้าหน้า BookingHistoryScreen
import 'digitel.dart'; // นำเข้าหน้า UserMenuPage สำหรับการสลับโหมด
import 'Security/SecurityVehiclelist.dart'; // 🟢 เพิ่มการ Import หน้าต่างจัดการรถเข้า-ออก
import 'auth_service.dart'; // 🟢 เพิ่มการนำเข้า AuthService สำหรับการ Logout
// ดึงเข้ามารองรับปุ่มออกจากระบบ เพื่อกลับไปหน้าเลือกสิทธิ

class AdminGroupPage extends StatefulWidget {
  const AdminGroupPage({super.key});

  @override
  State<AdminGroupPage> createState() => _AdminGroupPageState();
}

class _AdminGroupPageState extends State<AdminGroupPage> {
  @override
  void initState() {
    super.initState();
    _checkModeGuard();
  }

  // 🛡️ ป้องกันกรณีผู้ใช้ที่ไม่ได้อยู่โหมด ADMIN หลุดเข้ามาในหน้านี้ (Route Guard)
  Future<void> _checkModeGuard() async {
    final prefs = await SharedPreferences.getInstance();
    final currentMode = prefs.getString('current_mode');

    if (currentMode != 'ADMIN_MODE' && mounted) {
      debugPrint('🚨 [Guard] Unauthorized access. Kick back to User Menu.');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const UserMenuPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. ภาพพื้นหลัง
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF00529B),
              image: DecorationImage(
                image: AssetImage('assets/images/bgmmk.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 2. เนื้อหาหลัก
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // จัดชิดซ้าย
                children: [
                  const SizedBox(height: 20),

                  Align(
                    alignment: Alignment.topRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 🌟 ปุ่มใหม่: สลับเป็น User Mode
                        OutlinedButton.icon(
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('current_mode', 'USER_MODE');

                            try {
                              const storage = FlutterSecureStorage();
                              await storage.write(
                                key: 'current_mode',
                                value: 'USER_MODE',
                              );
                            } catch (e) {
                              print("⚠️ SecureStorage Write Error (Mode): $e");
                            }

                            if (!context.mounted) return;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const UserMenuPage(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.swap_horiz,
                            color: Colors.white,
                            size: 16,
                          ),
                          label: const Text(
                            'โหมดผู้ใช้',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontFamily: 'Kanit',
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.orange.withValues(
                              alpha: 0.8,
                            ),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.5),
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
                        const SizedBox(width: 8),
                        // ปุ่มออกจากระบบ (เดิม)
                        OutlinedButton.icon(
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
                                    onPressed: () =>
                                        Navigator.pop(context, true),
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
                                builder: (context) =>
                                    const LoginSelectionPage(),
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
                            backgroundColor: Colors.red.withValues(alpha: 0.8),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.5),
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
                      ],
                    ),
                  ),

                  const SizedBox(height: 5),

                  // --- โลโก้ และข้อความต้อนรับ ---
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
                            width: 320,
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),

                          const SizedBox(height: 20),

                          const Text(
                            'ยินดีต้อนรับ Admin',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // --- กล่องเมนูทั้ง 4 ---
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        AdminMenuCard(
                          icon: Icons.groups_outlined,
                          title: 'ห้องประชุม',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const MobileFrameContainer(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        AdminMenuCard(
                          icon: Icons.directions_car_filled_outlined,
                          title: 'ยานพาหนะ',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const VehiclePage(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        AdminMenuCard(
                          icon: Icons.car_rental, // ไอคอนรูปรถและกุญแจ
                          title: 'ระบบจัดการรถ เข้า - ออก',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const SecurityVehicleListScreen(), // 🟢 นำทางไปยังหน้าจัดการรถเข้า-ออก
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        AdminMenuCard(
                          icon: Icons.people_alt_outlined,
                          title: 'ระบบจัดการผู้ใช้',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const UsersPage(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        /*AdminMenuCard(
                          icon: Icons.dashboard_outlined,
                          title: 'แดชบอร์ดและรายงาน',
                          onTap: () {
                            Navigator.pushNamed(context, '/dashboard');
                          },
                        ),*/

                        // นำไปวางต่อจากปุ่มสุดท้าย (ก่อนถึงข้อความลิขสิทธิ์ด้านล่าง)
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
                              ),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.3,
                              ),
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
                      ],
                    ),
                  ),

                  // --- Footer ---
                  Center(
                    child: Column(
                      children: [
                        Container(
                          height: 1,
                          width: double.infinity,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        const SizedBox(height: 20),
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
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// Widget คัสตอมสำหรับปุ่มเมนูของ Admin (ไม่มี Subtitle)
// ==========================================
class AdminMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const AdminMenuCard({
    super.key,
    required this.icon,
    required this.title,
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
            color: Colors.black.withValues(alpha: 0.1),
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
              vertical: 16.0,
            ),
            child: Row(
              children: [
                // กล่องไอคอน
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F1F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 28, color: const Color(0xFF00529B)),
                ),
                const SizedBox(width: 16),

                // ข้อความชื่อเมนู
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontFamily: 'Kanit',
                    ),
                  ),
                ),

                // ไอคอนลูกศร
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F1F5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    size: 20,
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
