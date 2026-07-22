import 'package:flutter/material.dart';

// 🏢 ฟีเจอร์จองห้องประชุม (User)
import 'package:mobile_app/Booking_room/Room_list.dart';

// 🚗 ฟีเจอร์จองยานพาหนะ (User)
import 'package:mobile_app/Booking_vehicle/vehicle_list.dart';

// 📦 ไฟล์แกนหลักและหน้าตั้งค่า
import 'package:mobile_app/Book_history.dart';
import 'package:mobile_app/Manage.dart';
import 'package:mobile_app/Select.dart';
import 'package:mobile_app/user_setting_page.dart';

class UserMenuPage extends StatelessWidget {
  // 🟢 รองรับการเข้าใช้งานในฐานะ Guest
  final bool isGuest;

  const UserMenuPage({super.key, this.isGuest = false});

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
                              isGuest
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

                    const SizedBox(height: 32),

                    // 🏢 เมนูที่ 1: ห้องประชุม
                    SelectionCard(
                      icon: Icons.groups_outlined,
                      title: 'ห้องประชุม',
                      subtitle: isGuest
                          ? 'ตารางการใช้ห้องประชุม'
                          : 'จองห้องประชุม',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                RoomListScreen(isGuest: isGuest),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // 🚗 เมนูที่ 2: ยานพาหนะ
                    SelectionCard(
                      icon: Icons.directions_car_filled_outlined,
                      title: 'ยานพาหนะ',
                      subtitle: isGuest ? 'ตารางการใช้ยานพาหนะ' : 'จองรถ',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                VehicleBooking(isGuest: isGuest),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // 📜 เมนูที่ 3: ประวัติการจอง (โชว์เฉพาะผู้ใช้งานปกติ)
                    if (!isGuest) ...[
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
                    // ⚙️ ปุ่มตั้งค่า (โชว์เฉพาะผู้ใช้งานปกติ)
                    if (!isGuest)
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
                    IconButton(
                      icon: const Icon(
                        Icons.logout,
                        color: Colors.white,
                        size: 26,
                      ),
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginSelectionPage(),
                          ),
                          (route) => false,
                        );
                      },
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
