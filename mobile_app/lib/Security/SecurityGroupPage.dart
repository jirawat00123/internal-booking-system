import 'package:flutter/material.dart';
 

class SecurityGroupPage extends StatelessWidget {
  const SecurityGroupPage({super.key});

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          // พื้นหลัง
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  
                  // ปุ่มออกจากระบบ
                  Align(
                    alignment: Alignment.topRight,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // กลับไปหน้าเลือกสิทธิ์ (ปิดหน้าปัจจุบันทิ้ง)
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


                  const SizedBox(height: 40),

                  // โลโก้
                  Center(
                    child: Image.asset(
                      'assets/MMK_logo.png', 
                      width: screenWidth * 0.6, // กว้าง 60% ของจอ
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                          height: 2,
                          width: screenWidth * 0.8,
                          color: Colors.white.withOpacity(0.9),
                        ),
                  
                  const SizedBox(height: 32),

                  // ข้อความ Welcome
                  const Text(
                    'Welcome Security',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Kanit',
                    ),
                  ),

                  const SizedBox(height: 20),

                  // เมนูการใช้งาน (มีแค่กล่องเดียว)
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        SecurityMenuCard(
                          icon: Icons.car_rental, // ไอคอนรูปรถ
                          title: 'ระบบจัดการรถ เข้า-ออก',
                          onTap: () {
                            // TODO: ลิงก์ไปหน้าระบบจัดการรถ รปภ.
                          },
                        ),
                      ],
                    ),
                  ),

                  // Footer
                  Center(
                    child: Column(
                      children: [
                        Container(
                          height: 2,
                          width: screenWidth * 0.8,
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
                        const SizedBox(height: 75),
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

// Widget คัสตอมสำหรับปุ่มเมนูของ รปภ.
class SecurityMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const SecurityMenuCard({
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F1F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 28, color: const Color(0xFF00529B)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontFamily: 'Kanit',
                    ),
                  ),
                ),
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