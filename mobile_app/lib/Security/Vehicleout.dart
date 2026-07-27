import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb; // 💡 1. เพิ่มการนำเข้า kIsWeb
import 'Vehicleoutcompleted.dart';

class VehicleOutScreen extends StatefulWidget {
  final String bookingId;
  const VehicleOutScreen({Key? key, required this.bookingId}) : super(key: key);

  @override
  _VehicleOutScreenState createState() => _VehicleOutScreenState();
}

class _VehicleOutScreenState extends State<VehicleOutScreen> {
  final TextEditingController slotController = TextEditingController();

  // 💡 2. เปลี่ยนจาก File เป็น XFile เพื่อให้รองรับ Web
  XFile? frontImage;
  XFile? plateImage;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(bool isFront) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        if (isFront)
          frontImage = image;
        else
          plateImage = image;
      });
    }
  }

  void _checkAndSubmit() {
    if (slotController.text.trim().isEmpty ||
        frontImage == null ||
        plateImage == null) {
      _showErrorDialog(
        'กรุณากรอกระบุช่องจอด และถ่ายรูปให้ครบถ้วนก่อนดำเนินการต่อ',
      );
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
              Icons.note_add_outlined,
              color: Color(0xFF003E75),
              size: 60,
            ),
            const SizedBox(height: 16),
            const Text(
              'ยืนยันการปล่อยรถออก',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Kanit',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'คุณต้องการปล่อยรถออกใช่หรือไม่?',
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
      String token = prefs.getString('token') ?? '';

      var request = http.MultipartRequest(
        'PUT',
        Uri.parse(
          'http://localhost:3001/api/vehicle-bookings/${widget.bookingId}/release',
        ),
      );
      request.headers['Authorization'] = 'Bearer $token';

      request.fields['status'] = 'In_Use';
      request.fields['parkingSlot'] = slotController.text;

      // 💡 3. แก้ไขการส่งไฟล์ให้รองรับ Web (ใช้ fromBytes แทน fromPath)
      request.files.add(
        http.MultipartFile.fromBytes(
          'frontImage',
          await frontImage!.readAsBytes(),
          filename: frontImage!.name,
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
      Navigator.pop(context);

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const VehicleOutCompletedScreen(),
          ),
        );
      } else {
        _showErrorDialog('อัปโหลดรูปภาพไม่สำเร็จ โปรดลองอีกครั้ง');
      }
    } catch (e) {
      Navigator.pop(context);
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
                  'บันทึกการปล่อยรถออก',
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

              const Text(
                'ระบุช่องจอด',
                style: TextStyle(
                  color: Colors.blueGrey,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kanit',
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: slotController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _buildPhotoBox(
                'แนบรูปหน้ารถ',
                frontImage,
                () => _pickImage(true),
              ),
              const SizedBox(height: 20),

              _buildPhotoBox(
                'แนบรูปเลขไมล์',
                plateImage,
                () => _pickImage(false),
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

  // 💡 4. แยกการโชว์รูปว่ารันบนเว็บ หรือบนมือถือ
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
                        ? Image.network(
                            image.path,
                            fit: BoxFit.cover,
                          ) // ถ้าเป็นเว็บ ใช้ Image.network แสดง path เสมือน
                        : Image.file(
                            File(image.path),
                            fit: BoxFit.cover,
                          ), // ถ้าเป็นมือถือ/Desktop ใช้ Image.file
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
