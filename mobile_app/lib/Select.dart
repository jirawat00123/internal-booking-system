import 'package:flutter/material.dart';

// 🟢 นำเข้าหน้าจอต่างๆ
import 'Manage.dart';
import 'Security/SecurityPin.dart'; // หมายเหตุ: หากโฟลเดอร์ของคุณคือ Security ให้เปลี่ยนเป็น 'Security/SecurityPin.dart'
import 'Admin_pin.dart';
import 'Digitel.dart'; // สำหรับ UserMenuPage
import 'main.dart'; // 💡 นำเข้าสำหรับพากลับไปหน้า WelcomeApp()

class LoginSelectionPage extends StatelessWidget {
  const LoginSelectionPage({super.key});

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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(
                                height: 70,
                              ), // เว้นที่ว่างหลบปุ่ม Back ด้านบน
                              Image.asset(
                                'assets/images/MMK_logo.png',
                                height: 100,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: 300,
                                height: 2,
                                color: Colors.white.withOpacity(0.6),
                              ),
                              const SizedBox(height: 32),
                              const Text(
                                'ยินดีต้อนรับเข้าสู่ระบบ',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  fontFamily: 'Kanit',
                                ),
                                textAlign: TextAlign.left,
                              ),
                              const SizedBox(height: 8),
                              // 🟢 ข้อความอธิบายเพิ่มเติมจากเวอร์ชันที่สอง
                              Text(
                                'โปรดเลือกระดับสิทธิ์การเข้าถึงเพื่อดำเนินการต่อ',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.8),
                                  fontFamily: 'Kanit',
                                ),
                                textAlign: TextAlign.left,
                              ),
                            ],
                          ),

                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20.0),
                            child: Column(
                              children: [
                                // 📦 1. User
                                SelectionCard(
                                  icon: Icons.people_alt_outlined,
                                  title: 'User',
                                  subtitle: 'บัญชีผู้ใช้ในองค์กร',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const ManagePage(),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),

                                // 📦 2. Security
                                SelectionCard(
                                  icon: Icons.verified_user_outlined,
                                  title: 'Security',
                                  subtitle: 'พนักงานความปลอดภัย',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const Security_Pinpage(),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),

                                // 📦 3. Admin
                                SelectionCard(
                                  icon: Icons.support_agent,
                                  title: 'Admin',
                                  subtitle: 'แอดมินระบบ',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const Admin_pinPage(),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),

                                // 📦 4. Guest (เพิ่มเข้ามาใหม่จากเวอร์ชันแรก)
                                SelectionCard(
                                  icon: Icons.person,
                                  title: 'Guest',
                                  subtitle: 'ผู้ใช้งานทั่วไป',
                                  onTap: () {
                                    print("Guest user selected");
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const UserMenuPage(isGuest: true),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          // Footer
                          Column(
                            children: [
                              Container(
                                height:
                                    1, // ปรับความหนาให้ดูชัดเจนขึ้นนิดหน่อยแบบเวอร์ชันสอง
                                width: 300,
                                color: Colors.white.withOpacity(0.8),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'MENAM MECHANIKA © 2026',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.8,
                                  fontFamily: 'Kanit',
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ==========================================
          // Layer 3: ปุ่มย้อนกลับ (ดึงมาจากเวอร์ชันที่สอง)
          // ==========================================
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 8.0),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () {
                    // 🟢 ใช้ pushReplacement เพื่อบังคับกลับไปหน้า WelcomeApp ตรงๆ เลย
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WelcomeApp(),
                      ),
                    );
                  },
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
// Widget คัสตอมของกล่องเมนู (คงโครงสร้าง UI ที่จัด Kanit ไว้)
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
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
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
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEBF3F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 26, color: const Color(0xFF00529B)),
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontFamily: 'Kanit',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontFamily: 'Kanit',
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEBF3F9),
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
