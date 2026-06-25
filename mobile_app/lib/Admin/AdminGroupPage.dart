import 'package:flutter/material.dart';
// ดึงเข้ามารองรับปุ่มออกจากระบบ เพื่อกลับไปหน้าเลือกสิทธิ์

class AdminGroupPage extends StatelessWidget {
  const AdminGroupPage({super.key});

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
                image: AssetImage('assets/bg.png'),
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
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.logout, color: Colors.white, size: 16),
                      label: const Text(
                        'ออกจากระบบ',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Kanit'),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        side: BorderSide(color: Colors.white.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        minimumSize: Size.zero,
                      ),
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
                              'assets/MMK_logo.png', 
                              height: 100,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 16),
                            
                            
                            Container(
                              width: 320, 
                              height: 1,   
                              color: Colors.white.withOpacity(0.9), 
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
                            // TODO: ลิงก์ไปหน้าจัดการห้องประชุม
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        AdminMenuCard(
                          icon: Icons.directions_car_filled_outlined,
                          title: 'ยานพาหนะ',
                          onTap: () {
                            
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        AdminMenuCard(
                          icon: Icons.car_rental, // ไอคอนรูปรถและกุญแจ
                          title: 'ระบบจัดการรถ เข้า - ออก',
                          onTap: () {
                            
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        AdminMenuCard(
                          icon: Icons.people_alt_outlined,
                          title: 'ระบบจัดการผู้ใช้',
                          onTap: () {
                            
                          },
                        ),
                      ],
                    ),
                  ),

                  // --- Footer ---
                  Center(
                    child: Column(
                      children: [
                        Container(
                          height:1,
                          width: double.infinity,
                          color: Colors.white.withOpacity(0.9),
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
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
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
                  child: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF00529B)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}