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
                image: AssetImage(
                  'assets/images/bgmmk.png',
                ), // ใช้ภาพพื้นหลังใหม่
                fit: BoxFit.cover,
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start, // จัดทุกอย่างชิดซ้ายตามรูป
                children: [
                  const SizedBox(height: 16),

                  // ปุ่มออกจากระบบ
                  Align(
                    alignment: Alignment.topRight,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
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
                        backgroundColor: Colors.white.withOpacity(
                          0.15,
                        ), // ปรับให้โปร่งใสขึ้นนิดหน่อยตามแบบ
                        side: BorderSide(color: Colors.white.withOpacity(0.5)),
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

                  const SizedBox(height: 60),

                  // โลโก้ (เอา Center ออก เพื่อให้ชิดซ้าย)
                  Image.asset(
                    'assets/images/MMK_logo.png',
                    width: screenWidth * 0.5, // ปรับให้กว้างขึ้นตามสัดส่วนในรูป
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(height: 12),

                  // เส้นบางๆ ใต้โลโก้ (จัดชิดซ้าย)
                  Container(
                    height: 2, // ปรับให้เส้นบางลง
                    width: screenWidth * 0.8,
                    color: Colors.white.withOpacity(0.6),
                  ),

                  const SizedBox(height: 24),

                  // ข้อความ Welcome
                  const Text(
                    'Welcome  Security', // เพิ่มช่องว่างนิดนึงให้เหมือนแบบ
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Kanit',
                    ),
                  ),

                  const SizedBox(height: 32),

                  // เมนูการใช้งาน
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        SecurityMenuCard(
                          icon: Icons
                              .directions_car_outlined, // เปลี่ยนไอคอนให้ใกล้เคียงรูปรถด้านหน้ามากขึ้น
                          title:
                              'ระบบจัดการรถ\nเข้า-ออก', // ตัดขึ้นบรรทัดใหม่ให้ตรงตามดีไซน์
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
                          height: 1, // ปรับให้เส้นบางลง
                          width: screenWidth * 0.8,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'MENAM MECHANIKA © 2026',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            fontFamily: 'Kanit',
                          ),
                        ),
                        const SizedBox(
                          height: 40,
                        ), // ปรับระยะห่างด้านล่างให้พอดีขอบจอ
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
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 20.0,
            ), // เพิ่ม padding บนล่างให้การ์ดดูโปร่งขึ้น
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14), // ขยายกล่องไอคอน
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F1F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: const Color(0xFF00529B),
                  ), // ขยายไอคอน
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.3, // ปรับระยะห่างระหว่างบรรทัด
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
