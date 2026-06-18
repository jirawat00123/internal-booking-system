import 'package:flutter/material.dart';
import 'Digital.dart'; 




class LoginSelectionPage extends StatelessWidget {
  const LoginSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Layer 1: Background Image
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF00529B),
              image: DecorationImage(
                image: AssetImage('assets/bg.png'), 
                fit: BoxFit.cover,
              ),
            ),
          ),
 
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 70), // เว้นที่ว่างหลบปุ่ม Back ด้านบน
                              Image.asset(
                                'assets/MMK_logo.png',
                                height: 100,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: 300, // ความยาวของเส้นใต้โลโก้ ปรับเพิ่ม-ลดได้ตามต้องการ
                                height: 2,   // ความหนาของเส้น
                                color: Colors.white.withOpacity(0.6), // สีขาวแบบโปร่งแสงเล็กน้อยให้ดูเนียนตา
                              ),
                              
                              const SizedBox(height: 20),

                              const Text(
                                'ยินดีต้อนรับเข้าสู่ระบบ',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.left,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'โปรดเลือกระดับสิทธิ์การเข้าถึงเพื่อดำเนินการต่อ',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                                textAlign: TextAlign.left,
                              ),
                            ],
                          ),
                          
                          Padding(
                            padding: const EdgeInsets.only(bottom: 80.0),
                            child: Column(
                              children: [
                                // --- ปุ่มที่ 1: ผู้ใช้งาน ---
                                SelectionCard(
                                  icon: Icons.people_alt_outlined,
                                  title: 'ผู้ใช้งาน',
                                  subtitle: 'การจัดการผู้ใช้งาน',
                                  onTap: () {
                                    // 🚀 เอาดีเลย์ออก กดปุ๊บเปลี่ยนหน้าทันทีแบบสมูทๆ
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const UserMenuPage()));
                                  },
                                ),
                                const SizedBox(height: 16),
                                
                                // --- ปุ่มที่ 2: ความปลอดภัย (รปภ) ---
                                SelectionCard(
                                  icon: Icons.shield_outlined,
                                  title: 'ความปลอดภัย (รปภ)',
                                  subtitle: 'ตรวจสอบและบันทึกรถเข้า-ออก',
                                  onTap: () {
                                    // 🚀 เอาดีเลย์ออก
                                    Navigator.push;
                                  },
                                ),
                                const SizedBox(height: 16),
                                
                                // --- ปุ่มที่ 3: ผู้ดูแลระบบ ---
                                SelectionCard(
                                  icon: Icons.person,
                                  title: 'ผู้ดูแลระบบ',
                                  subtitle: 'สิทธิ์การเข้าถึงระบบแบบเต็มรูปแบบ',
                                  onTap: () {
                                    // 🚀 เอาดีเลย์ออก
                                    Navigator.push;
                                  },
                                ),
                              ],
                            ),
                          ),

                          Column(
                            children: [
                              Container(
                                height: 1,
                                width: 300,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'MENAM MECHANIKA © 2026',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 30),
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
          
          // Layer 3: ปุ่มย้อนกลับ (อยู่เลเยอร์บนสุดเสมอ)
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                  onPressed: () {
                    Navigator.pop(context);
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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