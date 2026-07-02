import 'package:flutter/material.dart';
import 'Room_List.dart';

class UserMenuPage extends StatelessWidget {
  const UserMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Background Image
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF00529B),
              image: DecorationImage(
                image: AssetImage('assets/images/bgmmk.png'), 
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 2. Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center, 
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start, 
                          children: [
                            // Logo Image
                            Image.asset(
                              'assets/images/MMK_logo.png', 
                              height: 100,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 16),
                            
                            // เส้นใต้โลโก้
                            Container(
                              width: 300, 
                              height: 2,   
                              color: Colors.white.withValues(alpha: 0.6), 
                            ),

                            const SizedBox(height: 40),
                            
                            // Welcome Texts
                            const Text(
                              'ยินดีต้อนรับ',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'โปรดเลือกรายการเข้าทำเพื่อดำเนินการต่อ',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // 3. Menu Selection Cards (ห้องประชุม & ยานพาหนะ)
                    SelectionCard(
                      icon: Icons.groups_outlined, 
                      title: 'ห้องประชุม',
                      subtitle: 'จองห้องประชุม',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RoomListScreen(), 
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    SelectionCard(
                      icon: Icons.directions_car_filled_outlined, 
                      title: 'ยานพาหนะ',
                      subtitle: 'จองรถ',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            // ⚠️ หมายเหตุ: ให้คุณเปลี่ยนชื่อ "ManagePage()" ตรงนี้ 
                            // ให้ตรงกับชื่อคลาส (class) หน้าหลักจริง ๆ ที่อยู่ภายในไฟล์ Manage.dart ของคุณ
                            builder: (context) => const RoomListScreen(), 
                          ),
                        );
                      },
                      // ==========================================
                    ),

                    const SizedBox(height: 24),

                    // 4. ปุ่ม "ประวัติการจอง" สีเทาโปร่งแสง
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          // TODO: ไปยังหน้าประวัติการจอง
                        },
                        icon: const Icon(Icons.history, color: Colors.white, size: 18),
                        label: const Text(
                          'ประวัติการจอง',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.3), 
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 50),
                    
                    // Footer
                    Center(
                      child: Column(
                        children: [
                          Container(
                            height: 1,
                            width: 300,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'MENAM MECHANIKA © 2026',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
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

          // 3. Layer ปุ่มย้อนกลับ
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Reusable Widget สำหรับสร้างการ์ดแต่ละตัวเลือก (ห้องประชุม / ยานพาหนะ)
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
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F1F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: const Color(0xFF00529B),
                  ),
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
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
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