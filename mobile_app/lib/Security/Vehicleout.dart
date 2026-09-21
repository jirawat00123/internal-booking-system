import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'Vehicleoutcompleted.dart';

class VehicleOutScreen extends StatefulWidget {
  final String bookingId;
  const VehicleOutScreen({Key? key, required this.bookingId}) : super(key: key);

  @override
  _VehicleOutScreenState createState() => _VehicleOutScreenState();
}

class _VehicleOutScreenState extends State<VehicleOutScreen> {
  // ❌ ลบช่องเก็บข้อมูล slotController ออกไปแล้ว

  XFile? frontImage;
  XFile? backImage;
  XFile? plateImage;

  bool _isSubmitting = false;
  bool _isLoadingBooking = true;
  String? _driverType;
  dynamic _companyDriverId;
  dynamic _driverId;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchBookingDetails();
  }

  Future<void> _fetchBookingDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String token =
          prefs.getString('token') ?? prefs.getString('jwt_token') ?? '';

      String baseUrl = kIsWeb
          ? 'https://192.168.88.25:3002'
          : 'https://192.168.88.25:3002';

      final response = await http.get(
        Uri.parse('$baseUrl/api/vehicle-bookings/${widget.bookingId}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final booking = data['data'] ?? data;
        final driverEmpId =
            booking['driverEmployeeId'] ??
            booking['companyDriverId'] ??
            (booking['driverEmployee'] is Map
                ? booking['driverEmployee']['id']
                : null) ??
            (booking['companyDriver'] is Map
                ? booking['companyDriver']['id']
                : null);

        print('[FETCH_BOOKING] Raw Data: $booking');
        print(
          '[FETCH_BOOKING] driverType: ${booking['driverType']}, driverEmployeeId: $driverEmpId, companyDriverId: ${booking['companyDriverId']}, driverId: ${booking['driverId']}, userId: ${booking['userId']}, createdById: ${booking['createdById']}',
        );
        if (mounted) {
          setState(() {
            _driverType = booking['driverType']?.toString();
            _companyDriverId = driverEmpId;
            _driverId =
                booking['driverId'] ??
                booking['driverUserId'] ??
                driverEmpId ??
                booking['userId'] ??
                booking['createdById'];
            _isLoadingBooking = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingBooking = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingBooking = false);
    }
  }

  Future<void> _pickImage(String imageType) async {
    // 🎯 บังคับใช้กล้อง และระบุให้เบราว์เซอร์เปิดกล้องหลัง + ลดขนาดภาพเพื่อแก้ปัญหาจอดำบนมือถือ
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
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
    bool isUnassignedCompanyDriver =
        (_driverType == 'COMPANY' || _driverType == 'COMPANY_DRIVER') &&
        (_companyDriverId == null ||
            _companyDriverId.toString().isEmpty ||
            _companyDriverId == 0);

    if (isUnassignedCompanyDriver) {
      _showErrorDialog(
        'ยังไม่ได้จัดสรรพนักงานขับรถ',
        title: 'ข้อมูลไม่ครบถ้วน',
      );
      return;
    }
    if (frontImage == null || backImage == null || plateImage == null) {
      _showErrorDialog(
        'กรุณาถ่ายรูปให้ครบทั้ง 3 มุมก่อนดำเนินการต่อ',
        title: 'ข้อมูลไม่ครบถ้วน',
      );
      return;
    }
    _showConfirmDialog();
  }

  void _showErrorDialog(String msg, {String title = 'แจ้งเตือน'}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
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
                      if (_isSubmitting) return;
                      setState(() {
                        _isSubmitting = true;
                      });
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
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
        return;
      }

      String baseUrl = kIsWeb
          ? 'https://192.168.88.25:3002'
          : 'https://192.168.88.25:3002';

      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/api/vehicle-bookings/${widget.bookingId}/release'),
      );

      request.headers.addAll({'Authorization': 'Bearer $token'});

      request.fields['status'] = 'IN_USE';
      if (_driverType != null && _driverType!.isNotEmpty) {
        request.fields['driverType'] = _driverType!;
      }
      if (_companyDriverId != null) {
        request.fields['companyDriverId'] = _companyDriverId.toString();
        request.fields['company_driver_id'] = _companyDriverId.toString();
        request.fields['driverEmployeeId'] = _companyDriverId.toString();
        request.fields['driver_employee_id'] = _companyDriverId.toString();
      }
      if (_driverId != null) {
        request.fields['driverId'] = _driverId.toString();
        request.fields['driver_id'] = _driverId.toString();
        request.fields['driverUserId'] = _driverId.toString();
        request.fields['driver_user_id'] = _driverId.toString();
        request.fields['userId'] = _driverId.toString();
      } else if (_companyDriverId != null) {
        request.fields['driverId'] = _companyDriverId.toString();
        request.fields['driver_id'] = _companyDriverId.toString();
      }

      print('[SUBMIT] Request Fields: ${request.fields}');

      MediaType getMediaType(XFile file) {
        final ext = file.name.split('.').last.toLowerCase();
        if (ext == 'png') return MediaType('image', 'png');
        return MediaType('image', 'jpeg');
      }

      String getFilename(XFile file, String defaultName) {
        if (file.name.isNotEmpty && file.name.contains('.')) {
          return file.name;
        }
        return '$defaultName.jpg';
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'frontImage',
          await frontImage!.readAsBytes(),
          filename: getFilename(frontImage!, 'front_image'),
          contentType: getMediaType(frontImage!),
        ),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'backImage',
          await backImage!.readAsBytes(),
          filename: getFilename(backImage!, 'back_image'),
          contentType: getMediaType(backImage!),
        ),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'plateImage',
          await plateImage!.readAsBytes(),
          filename: getFilename(plateImage!, 'plate_image'),
          contentType: getMediaType(plateImage!),
        ),
      );

      var response = await request.send();
      final respStr = await response.stream.bytesToString();

      print('[SUBMIT] Status Code: ${response.statusCode}');
      print('[SUBMIT] Response Body: $respStr');

      if (!mounted) return;
      Navigator.pop(context);
      setState(() {
        _isSubmitting = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const VehicleOutCompletedScreen(),
          ),
        );
      } else if (response.statusCode == 409) {
        final resData = json.decode(respStr);
        if (resData['code'] == 'NOT_YET_TIME') {
          _showEarlyReleaseRequestDialog();
        } else if (resData['code'] == 'PREVIOUS_BOOKING_ACTIVE') {
          _showErrorDialog('มีคิวก่อนหน้าที่ยังไม่คืนรถ');
        } else {
          _showErrorDialog(
            resData['error'] ??
                resData['message'] ??
                'เกิดข้อผิดพลาดในการปล่อยรถ',
          );
        }
      } else {
        print('Upload failed with status: ${response.statusCode}');
        try {
          final resData = json.decode(respStr);
          final errorMsg =
              resData['error'] ??
              resData['message'] ??
              'อัปโหลดรูปภาพไม่สำเร็จ (รหัส: ${response.statusCode})';
          _showErrorDialog(errorMsg.toString());
        } catch (_) {
          _showErrorDialog(
            'อัปโหลดรูปภาพไม่สำเร็จ (รหัส: ${response.statusCode})',
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      setState(() {
        _isSubmitting = false;
      });
      print('Network Error: $e');
      _showErrorDialog('เชื่อมต่อเซิร์ฟเวอร์ผิดพลาด');
    }
  }

  void _showEarlyReleaseRequestDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.access_time_filled,
              color: Colors.orange,
              size: 60,
            ),
            const SizedBox(height: 16),
            const Text(
              'ยังไม่ถึงเวลารับรถ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Kanit',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'ยังไม่ถึงเวลารับรถ ต้องการส่งคำขอรับรถก่อนเวลาไปยังผู้จองหรือไม่?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Kanit'),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _requestEarlyRelease();
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

  Future<void> _requestEarlyRelease() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      String token =
          prefs.getString('token') ?? prefs.getString('jwt_token') ?? '';

      String baseUrl = kIsWeb
          ? 'https://192.168.88.25:3002'
          : 'https://192.168.88.25:3002';

      final response = await http.post(
        Uri.parse(
          '$baseUrl/api/vehicle-bookings/${widget.bookingId}/early-request',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'ส่งคำขอรับรถก่อนเวลาไปยังผู้จองเรียบร้อยแล้ว',
              style: TextStyle(fontFamily: 'Kanit'),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final resData = json.decode(response.body);
        _showErrorDialog(resData['error'] ?? 'ส่งคำขอไม่สำเร็จ');
      }
    } catch (e) {
      if (!mounted) return;
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
    bool isUnassignedCompanyDriver =
        (_driverType == 'COMPANY' || _driverType == 'COMPANY_DRIVER') &&
        (_companyDriverId == null ||
            _companyDriverId.toString().isEmpty ||
            _companyDriverId == 0);

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

              // ❌ ลบส่วน UI กรอกข้อมูลช่องจอดรถออกแล้ว
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

              if (isUnassignedCompanyDriver) ...[
                const Center(
                  child: Text(
                    'ยังไม่ได้จัดสรรพนักงานขับรถ',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Kanit',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_isLoadingBooking || isUnassignedCompanyDriver)
                      ? null
                      : _checkAndSubmit,
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
