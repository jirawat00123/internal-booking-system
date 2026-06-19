import 'package:flutter/material.dart';

class ManagePage extends StatefulWidget {
  const ManagePage({super.key});

  @override
  State<ManagePage> createState() => _ManagePageState();
}

class _ManagePageState extends State<ManagePage> {
  // ตัวแปรเก็บค่าที่เลือกจาก Dropdown
  String? _selectedPosition;
  String? _selectedName;

  // รายการข้อมูลจำลอง
  final List<String> _positions = [
    'Information Technology (IT)',
    'Human Resources',
    'Accounting',
    'Engineering',
  ];

  final List<String> _names = [
    'นายธีรวัฒน์ พรหมสิงห์ (เอก)',
    'นายสมชาย ใจดี',
    'นางสาวสมศรี มีสุข'
  ];

  // 1. ฟังก์ชันโชว์กล่องแจ้งเตือน "ข้อมูลไม่ครบถ้วน" (สีแดง)
  void _showErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(24),
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.priority_high, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 20),
                const Text(
                  'ข้อมูลไม่ครบถ้วน',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF003E77), fontFamily: 'Kanit'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'กรุณาเลือกตำแหน่งและชื่อ-สกุลก่อนดำเนินการต่อ',
                  style: TextStyle(fontSize: 13, color: Color(0xFF00529B), fontFamily: 'Kanit'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 160,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0096C7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('ตกลง', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================================
  // 💡 2. ส่วนที่เพิ่มเข้ามาใหม่: ฟังก์ชันโชว์กล่อง "ยืนยันการดำเนินการ"
  // ==========================================================
  void _showConfirmDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent, // ปรับให้โปร่งใสเพื่อให้ Container จัดการพื้นหลังเอง
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24), 
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            width: 340,
            // ✅ เพิ่มพื้นหลังรูปภาพตรงนี้
            decoration: BoxDecoration(
              color: Colors.white, // สีพื้นหลังเผื่อรูปโหลดไม่ขึ้น
              borderRadius: BorderRadius.circular(24),
  
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ไอคอนผู้ใช้งานวงกลมสีฟ้าอ่อนด้านบนป๊อปอัป
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEBF3F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.people_alt_outlined,
                    color: Color(0xFF00529B),
                    size: 38,
                  ),
                ),
                const SizedBox(height: 16),
                
                // หัวข้อ ยืนยันการดำเนินการ
                const Text(
                  'ยืนยันการดำเนินการ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003E77),
                    fontFamily: 'Kanit',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'กรุณาตรวจสอบข้อมูลก่อนดำเนินการต่อ',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontFamily: 'Kanit',
                  ),
                ),
                const SizedBox(height: 20),

                // ตารางแสดงผลสรุปข้อมูลที่ผู้ใช้เลือกจริง
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85), // ปรับให้โปร่งใสเล็กน้อยเพื่อให้เห็นพื้นหลัง
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2EFF2)),
                  ),
                  child: Column(
                    children: [
                      // แถวแสดง "ตำแหน่ง"
                      Row(
                        children: [
                          const Icon(Icons.circle, size: 6, color: Color(0xFF00529B)),
                          const SizedBox(width: 8),
                          const Text(
                            'ตำแหน่ง',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF003E77), fontFamily: 'Kanit'),
                          ),
                          const Spacer(),
                          Text(
                            _selectedPosition ?? '',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF007AD6), fontFamily: 'Kanit'),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10.0),
                        child: Divider(height: 1, color: Color(0xFFE2EFF2)),
                      ),
                      // แถวแสดง "ชื่อ-สกุล"
                      Row(
                        children: [
                          const Icon(Icons.circle, size: 6, color: Color(0xFF00529B)),
                          const SizedBox(width: 8),
                          const Text(
                            'ชื่อ-สกุล',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF003E77), fontFamily: 'Kanit'),
                          ),
                          const Spacer(),
                          Text(
                            _selectedName ?? '',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF007AD6), fontFamily: 'Kanit'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // กลุ่มปุ่มกดยืนยัน และ ปุ่มยกเลิก
                Column(
                  children: [
                    // ปุ่ม "ยืนยัน" สีฟ้า
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // ปิด Popup ยืนยัน
                          // TODO: นำข้อมูลไปบันทึก หรือส่งผลสลับหน้าต่อได้ตรงนี้เลยครับ
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0096C7),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        child: const Text('ยืนยัน', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // ปุ่ม "ยกเลิก" เส้นขอบใส
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context), 
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF0096C7), width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          foregroundColor: const Color(0xFF0096C7),
                          backgroundColor: Colors.white.withOpacity(0.8), // เติมสีขาวโปร่งแสงเพื่อให้ปุ่มไม่จมไปกับพื้นหลัง
                        ),
                        child: const Text('ยกเลิก', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Background Image Layer (หน้าหลัก)
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF00529B),
              image: DecorationImage(
                image: AssetImage('assets/bg.png'), 
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'จัดการผู้ใช้งาน',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Kanit'),
                    ),
                    const SizedBox(height: 24),

                    // --- การ์ดสีขาวตรงกลาง (White Form Card) ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 8),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_alt_outlined, color: Color(0xFF00529B), size: 36),
                              SizedBox(width: 10),
                              Text(
                                'ผู้ใช้งาน',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF00529B), fontFamily: 'Kanit'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // 1. Dropdown ส่วน "ตำแหน่ง"
                          _buildLabel('ตำแหน่ง'),
                          _buildDropdownField(
                            hint: 'เลือกตำแหน่ง',
                            value: _selectedPosition,
                            items: _positions,
                            onChanged: (value) {
                              setState(() {
                                _selectedPosition = value;
                              });
                            },
                          ),
                          const SizedBox(height: 24),

                          // 2. Dropdown ส่วน "ชื่อ-สกุล"
                          _buildLabel('ชื่อ-สกุล'),
                          _buildDropdownField(
                            hint: 'เลือกรายชื่อ',
                            value: _selectedName,
                            items: _names,
                            onChanged: (value) {
                              setState(() {
                                _selectedName = value;
                              });
                            },
                          ),
                          const SizedBox(height: 40),

                          // ปุ่ม "ดำเนินการต่อ" 
                          SizedBox(
                            width: 240, 
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () {
                                if (_selectedPosition == null || _selectedName == null) {
                                  _showErrorDialog(); 
                                } else {
                                  _showConfirmDialog(); 
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0096C7), 
                                foregroundColor: Colors.white,
                                elevation: 3,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('ดำเนินการต่อ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // --- ส่วนล่างสุด: เส้นใต้ และ ฟุตเตอร์ (Footer) ---
                    Container(
                      height: 0.5,
                      width: double.infinity,
                      color: Colors.white.withOpacity(0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'MENAM MECHANIKA © 2026',
                      style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w500, letterSpacing: 0.8, fontFamily: 'Kanit'),
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
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 24), 
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF003E77), fontFamily: 'Kanit'),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00529B).withOpacity(0.6), width: 1.2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: TextStyle(color: Colors.grey[500], fontSize: 14, fontFamily: 'Kanit')),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF00529B), size: 24), 
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: const TextStyle(color: Colors.black87, fontSize: 14, fontFamily: 'Kanit')),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}