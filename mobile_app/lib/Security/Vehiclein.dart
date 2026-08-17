import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// 💡 อย่าลืมสร้างไฟล์หน้า Success สำหรับรับรถเข้า (หรือจะเด้งกลับหน้าเดิมก็ได้ครับ)
import 'Vehicleincompleted.dart';

class VehicleInScreen extends StatefulWidget {
  final String bookingId;
  const VehicleInScreen({Key? key, required this.bookingId}) : super(key: key);

  @override
  _VehicleInScreenState createState() => _VehicleInScreenState();
}

class _VehicleInScreenState extends State<VehicleInScreen> {
  XFile? frontImage;
  XFile? backImage;
  XFile? plateImage;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(String imageType) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        if (imageType == 'front') {
          frontImage = image;
        } else if (imageType == 'back') {
          backImage = image;
        } else if (imageType == 'plate') {
          plateImage = image;
        }
      });
    }
  }

  void _checkAndSubmit() {
    if (frontImage == null || backImage == null || plateImage == null) {
      _showErrorDialog('กรุณาถ่ายรูปให้ครบทั้ง 3 มุมก่อนดำเนินการต่อ');
      return;
    }
    _showConfirmDialog();
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            const Text(
              'ข้อมูลไม่ครบถ้วน',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Kanit',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Kanit'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF009CB4),
              ),
              child: const Text(
                'ตกลง',
                style: TextStyle(color: Colors.white, fontFamily: 'Kanit'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons
                  .check_circle_outline, // 🎯 เปลี่ยนไอคอนให้ดูเป็นเชิงเสร็จสิ้น
              color: Color(0xFF003E75),
              size: 60,
            ),
            const SizedBox(height: 16),
            const Text(
              'ยืนยันการรับรถเข้า', // 🎯 เปลี่ยนข้อความ
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Kanit',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'คุณต้องการรับรถเข้าใช่หรือไม่?', // 🎯 เปลี่ยนข้อความ
              style: TextStyle(fontFamily: 'Kanit'),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _submitToDatabase();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF009CB4),
                    ),
                    child: const Text(
                      'ตกลง',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Kanit',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                    ),
                    child: const Text(
                      'ยกเลิก',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Kanit',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitToDatabase() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      String token =
          prefs.getString('token') ?? prefs.getString('jwt_token') ?? '';

      if (token.isEmpty) {
        Navigator.pop(context);
        _showErrorDialog(
          'ไม่พบข้อมูลการเข้าสู่ระบบ (Token สูญหาย) กรุณาเข้าสู่ระบบใหม่',
        );
        return;
      }

      String baseUrl = kIsWeb
          ? 'http://192.168.88.25:3001'
          : 'http://192.168.88.25:3001';

      // 🎯 เปลี่ยน URL API ไปที่ /return สำหรับการคืนรถ
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/api/vehicle-bookings/${widget.bookingId}/return'),
      );

      request.headers.addAll({'Authorization': 'Bearer $token'});

      // 🎯 เปลี่ยนสถานะเป็น Completed (เสร็จสิ้นการใช้งาน)
      request.fields['status'] =
          'COMPLETED'; // 🟢 เปลี่ยนเป็นตัวพิมพ์ใหญ่ตาม API Contract ใหม่

      request.files.add(
        http.MultipartFile.fromBytes(
          'frontImage',
          await frontImage!.readAsBytes(),
          filename: frontImage!.name,
        ),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'backImage',
          await backImage!.readAsBytes(),
          filename: backImage!.name,
        ),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'plateImage',
          await plateImage!.readAsBytes(),
          filename: plateImage!.name,
        ),
      );

      var response = await request.send();
      Navigator.pop(context); // ปิดตัวโหลด

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.push(
          context,
          MaterialPageRoute(
            // 🎯 ไปหน้าเสร็จสิ้นการรับรถ (ต้องสร้างไฟล์ Vehicleincompleted.dart ไว้ด้วยนะครับ)
            builder: (context) => const VehicleInCompletedScreen(),
          ),
        );
      } else {
        print('Upload failed with status: ${response.statusCode}');
        _showErrorDialog(
          'อัปโหลดรูปภาพไม่สำเร็จ (รหัส: ${response.statusCode})',
        );
      }
    } catch (e) {
      Navigator.pop(context);
      print('Network Error: $e');
      _showErrorDialog('เชื่อมต่อเซิร์ฟเวอร์ผิดพลาด');
    }
  }

  String _getCurrentFormattedDate() {
    DateTime now = DateTime.now();
    String month = now.month.toString().padLeft(2, '0');
    String day = now.day.toString().padLeft(2, '0');
    return '$month/$day/${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003E75),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ระบบจัดการรถเข้า-ออก',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Kanit',
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'บันทึกการรับรถเข้า', // 🎯 เปลี่ยนข้อความ
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003E75),
                    fontFamily: 'Kanit',
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: Colors.blue.shade300,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ระบุวัน',
                    style: TextStyle(
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Kanit',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: 170,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _getCurrentFormattedDate(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontFamily: 'Kanit',
                        color: Colors.black87,
                      ),
                    ),
                    const Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: Colors.black87,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              _buildPhotoBox(
                'แนบรูปหน้ารถ',
                frontImage,
                () => _pickImage('front'),
              ),
              const SizedBox(height: 20),

              _buildPhotoBox(
                'แนบรูปหลังรถ',
                backImage,
                () => _pickImage('back'),
              ),
              const SizedBox(height: 20),

              _buildPhotoBox(
                'แนบรูปเลขไมล์',
                plateImage,
                () => _pickImage('plate'),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _checkAndSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF009CB4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'กดบันทึก',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Kanit',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoBox(String label, XFile? image, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.blueGrey,
            fontWeight: FontWeight.bold,
            fontFamily: 'Kanit',
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: kIsWeb
                        ? Image.network(image.path, fit: BoxFit.cover)
                        : Image.file(File(image.path), fit: BoxFit.cover),
                  )
                : const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 40,
                    color: Colors.grey,
                  ),
          ),
        ),
      ],
    );
  }
}
