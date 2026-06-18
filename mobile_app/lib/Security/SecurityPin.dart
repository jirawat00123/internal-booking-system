import 'package:flutter/material.dart';
import 'PinError.dart'; 
import 'SecurityGroupPage.dart'; // ดึงหน้าเมนูรปภ.มาเตรียมไว้

class Security_Pinpage extends StatefulWidget {
  const Security_Pinpage({super.key});

  @override
  State<Security_Pinpage> createState() => _Security_PinpageState();
}

class _Security_PinpageState extends State<Security_Pinpage > {
  String pin = ""; 
  bool isObscured = true; 
  final String correctPin = "654321"; // 💡 รหัส PIN จำลองของ รปภ.

  void _addPin(String number) {
    if (pin.length < 6) {
      setState(() { pin += number; });
    }
  }

  void _removePin() {
    if (pin.isNotEmpty) {
      setState(() { pin = pin.substring(0, pin.length - 1); });
    }
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PinError(
          onRetry: () {
            setState(() { pin = ""; });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'กรอกรหัส PIN',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Kanit'),
                        ),
                      ),
                      const SizedBox(width: 48), 
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    width: 375,
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                    ),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shield_outlined, size: 30, color: Color(0xFF00529B)),
                            SizedBox(width: 8),
                            Text(
                              'รปภ. (Security Guard)',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00529B), fontFamily: 'Kanit'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('ระบุรหัส PIN', style: TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Kanit')),
                        ),
                        const SizedBox(height: 8),
                        
                        // กล่องใส่รหัส 6 หลัก
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (index) {
                            bool isFilled = index < pin.length;
                            return Container(
                              width: 45,
                              height: 55,
                              decoration: BoxDecoration(
                                border: Border.all(color: isFilled ? const Color(0xFF00529B) : Colors.grey.shade400, width: 1.5),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.transparent,
                              ),
                              child: Center(
                                child: Text(
                                  isFilled ? (isObscured ? '●' : pin[index]) : '',
                                  style: TextStyle(fontSize: isObscured ? 20 : 24, color: const Color(0xFF00529B), fontWeight: FontWeight.bold),
                                ),
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 40),

                        // ปุ่มเปิด/ปิดตา (ดูรหัส)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              isObscured = !isObscured;
                            });
                          },
                          child: Icon(
                            isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: Colors.blueAccent.withOpacity(0.5),
                            size: 28,
                          ),
                        ),

                        const Spacer(flex: 1),

                        // แป้นตัวเลข Numpad
                        _buildNumpadRow(['1', '2', '3']),

                        _buildNumpadRow(['4', '5', '6']),

                        _buildNumpadRow(['7', '8', '9']),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            const SizedBox(width: 60, height: 60), 
                            _buildNumButton('0'),
                            SizedBox(
                              width: 60,
                              height: 60,
                              child: IconButton(
                                onPressed: _removePin,
                                icon: const Icon(Icons.cancel_outlined, size: 32, color: Colors.blueAccent),
                              ),
                            ),
                          ],
                        ),

                        const Spacer(flex: 2),

                        // 🚀 ปุ่ม "ดำเนินการต่อ" พร้อมระบบเช็กถูก/ผิด
                        SizedBox(
                          width: 375 - 48,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              if (pin.length == 6) {
                                if (pin == correctPin) {
                                  
                                  // 💡 1. เคลียร์รหัสทิ้ง ป้องกันคนกดย้อนกลับมาเจอ
                                  setState(() { 
                                    pin = ""; 
                                  });

                                  // 🚀 2. เด้งไปหน้า AdminGroupPage (ใช้ pushReplacement เพื่อปิดหน้า PIN ทิ้ง)
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const SecurityGroupPage(),
                                    ),
                                  );
                                  
                                } else {
                                  // กรณีรหัส "ผิด" เรียก Popup แดง
                                  _showErrorDialog(); 
                                }
                              } else {
                                // กรณีกดไม่ครบ 6 ตัว
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('กรุณากรอกรหัส PIN ให้ครบ 6 หลัก', style: TextStyle(fontFamily: 'Kanit')),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0096C7),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('ดำเนินการต่อ', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
                          ),
                        ),

                        const SizedBox(height: 24),

                        Container(height: 1, width: 250, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text(
                          'MENAM MECHANIKA © 2026',
                          style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumpadRow(List<String> numbers) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: numbers.map((num) => _buildNumButton(num)).toList(),
      ),
    );
  }

  Widget _buildNumButton(String number) {
    return SizedBox(
      width: 60,
      height: 60,
      child: TextButton(
        onPressed: () => _addPin(number),
        style: TextButton.styleFrom(shape: const CircleBorder()),
        child: Text(number, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.black87)),
      ),
    );
  }
}