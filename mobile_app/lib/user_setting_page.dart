import 'package:flutter/material.dart';
import 'package:mobile_app/change_password_page.dart';
import 'change_password_page.dart';

class UserSettingPage extends StatelessWidget {
  const UserSettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🌌 พื้นหลังสีน้ำเงิน
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF00529B),
              image: DecorationImage(
                image: AssetImage('assets/images/bgmmk.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // 🏷️ แถบด้านบน (App Bar)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'การตั้งค่า',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Kanit',
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 48,
                      ), // เว้นที่ไว้ให้ title อยู่ตรงกลางพอดี
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // ⬜ กล่องเมนูสีขาว
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(
                      left: 16.0,
                      right: 16.0,
                      bottom: 24.0,
                    ),
                    padding: const EdgeInsets.only(top: 8.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        // 🔘 เมนูเปลี่ยนรหัสผ่าน
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 8.0,
                          ),
                          title: const Text(
                            'เปลี่ยนรหัสผ่าน',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF003E77),
                              fontFamily: 'Kanit',
                            ),
                          ),
                          subtitle: const Padding(
                            padding: EdgeInsets.only(top: 4.0),
                            child: Text(
                              'กรอกรหัส PIN 6 หลักเดิมและรหัสใหม่ที่ต้องการตั้ง',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontFamily: 'Kanit',
                              ),
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 18,
                            color: Color(0xFF003E77),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ChangePasswordPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
