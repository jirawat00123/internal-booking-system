import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app/Booking_vehicle/Vehicle_model.dart';
import 'package:mobile_app/Booking_vehicle/driver_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'vehicle_booking_confirm.dart';

class VehicleBookingFormBPage extends StatefulWidget {
  // 🟢 1. ประกาศตัวแปรมารับค่าที่ส่งมาจากหน้า A
  final VehicleModel vehicle;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final String timeRange;
  final String returnTime;
  final int passengerCount;
  final List<String> passengerNames;
  final String driverType; // 💡 1. เพิ่มตัวแปร userId ตรงนี้ครับ!
  final int? driverEmployeeId;

  const VehicleBookingFormBPage({
    super.key,
    required this.vehicle,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.timeRange,
    required this.returnTime,
    required this.passengerCount,
    this.passengerNames = const [],
    required this.driverType, // 💡 2. บังคับรับค่า userId
    this.driverEmployeeId,
  });

  @override
  State<VehicleBookingFormBPage> createState() =>
      _VehicleBookingFormBPageState();
}

class _VehicleBookingFormBPageState extends State<VehicleBookingFormBPage> {
  final _formKey = GlobalKey<FormState>();

  // 💡 เพิ่ม objectiveController สำหรับช่องพิมพ์วัตถุประสงค์
  final TextEditingController objectiveController = TextEditingController();
  final TextEditingController detailsController = TextEditingController();
  final TextEditingController pettyCashController = TextEditingController();

  late String _selectedDriverType;
  XFile? _licenseImage;
  int _imageRotation = 0;

  final ImagePicker _picker = ImagePicker();

  // ตัวแปรสำหรับเก็บรายชื่อผู้ขับขี่กรณี "ขับขี่เอง" (ดึงจาก Passenger List)
  String? _selectedSelfDriveDriver;

  // ตัวแปรสำหรับพนักงานขับรถบริษัท
  List<CompanyDriver> _companyDrivers = [];
  CompanyDriver? _selectedCompanyDriver;
  bool _isLoadingDrivers = false;

  // ✅ ตัวแปรสถานะใบขับขี่
  bool _hasLicenseInSystem = false;
  bool _isLicenseExpired = false;
  bool _isCheckingLicense = false;

  @override
  void initState() {
    super.initState();
    _retrieveLostData();
    _selectedDriverType = (widget.driverType.isNotEmpty)
        ? widget.driverType
        : 'ขับขี่เอง';

    final bool isSelfDrive =
        _selectedDriverType == 'ขับขี่เอง' ||
        _selectedDriverType == 'SELF_DRIVE';

    // กำหนดค่าเริ่มต้นผู้ขับขี่กรณีขับขี่เองจากรายชื่อผู้โดยสารคนแรก
    if (isSelfDrive && widget.passengerNames.isNotEmpty) {
      _selectedSelfDriveDriver = widget.passengerNames.first;
      _checkLicenseStatus(widget.driverEmployeeId, _selectedSelfDriveDriver);
    }
  }

  Future<void> _retrieveLostData() async {
    debugPrint('[LicenseImage] Checking lost data...');
    try {
      final LostDataResponse response = await _picker.retrieveLostData();
      if (response.isEmpty) {
        debugPrint('[LicenseImage] No lost image');
        return;
      }

      if (response.file != null) {
        if (!mounted) return;
        setState(() {
          _licenseImage = response.file;
          _imageRotation = 0;
        });
        debugPrint('[LicenseImage] Lost image recovered');
        return;
      }

      if (response.files != null && response.files!.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _licenseImage = response.files!.first;
          _imageRotation = 0;
        });
        debugPrint('[LicenseImage] Lost image recovered');
        return;
      }

      if (response.exception != null) {
        debugPrint('[LicenseImage] Recovery error: ${response.exception}');
      }
    } catch (e) {
      debugPrint('[LicenseImage] Recovery error: $e');
    }
  }

  Future<void> _fetchCompanyDrivers() async {
    setState(() => _isLoadingDrivers = true);
    try {
      // ดึง Token จาก SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      String token =
          prefs.getString('token') ??
          prefs.getString('jwt_token') ??
          prefs.getString('jwt') ??
          prefs.getString('accessToken') ??
          prefs.getString('auth_token') ??
          '';

      final response = await http.get(
        Uri.parse('https://192.168.88.25:3002/api/company-drivers'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final resData = json.decode(response.body);
        final List listData = resData['data'] ?? [];
        setState(() {
          _companyDrivers = listData
              .map((e) => CompanyDriver.fromJson(e))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Fetch drivers error: $e');
    } finally {
      setState(() => _isLoadingDrivers = false);
    }
  }

  // ✅ ฟังก์ชันตรวจสอบสถานะใบขับขี่
  Future<void> _checkLicenseStatus(int? employeeId, String? driverName) async {
    setState(() {
      _isCheckingLicense = true;
      _hasLicenseInSystem = false;
      _isLicenseExpired = false;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      String token = prefs.getString('token') ?? '';

      if (driverName == null || driverName.isEmpty) {
        setState(() => _isCheckingLicense = false);
        return;
      }

      final String queryParam = 'name=${Uri.encodeComponent(driverName)}';
      debugPrint('[Check License Request] QueryParam: $queryParam');

      final response = await http.get(
        Uri.parse('https://192.168.88.25:3002/api/check-license?$queryParam'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint(
        '[Check License Response] Status: ${response.statusCode}, Body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final resData = json.decode(response.body);
        final bool hasLic = resData['hasLicense'] ?? false;
        final bool isExp = resData['isExpired'] ?? false;

        setState(() {
          _hasLicenseInSystem = hasLic;
          _isLicenseExpired = isExp;
        });

        debugPrint(
          '[Check License Result] hasLicense: $hasLic, isExpired: $isExp',
        );

        if (isExp && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'ใบขับขี่ในระบบหมดอายุแล้ว กรุณาอัปโหลดรูปภาพใบขับขี่ใหม่',
                style: TextStyle(fontFamily: 'Kanit'),
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[Check License Error] Exception: $e');
    } finally {
      if (mounted) {
        setState(() => _isCheckingLicense = false);
      }
    }
  }

  @override
  void dispose() {
    objectiveController.dispose(); // อย่าลืม dispose ตัวใหม่ด้วย
    detailsController.dispose();
    pettyCashController.dispose();
    super.dispose();
  }

  void _showUploadErrorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF0000),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.priority_high,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'อัปโหลดรูปภาพไม่สำเร็จ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003E75),
                    fontFamily: 'Kanit',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'โปรดลองอีกครั้ง',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF003E75),
                    fontFamily: 'Kanit',
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 140,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF009CB4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'ตกลง',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kanit',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickLicenseImage([
    ImageSource source = ImageSource.gallery,
  ]) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _licenseImage = image;
          _imageRotation = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        _showUploadErrorDialog(context);
      }
    }
  }

  void _showImageSourceSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF004381)),
                title: const Text(
                  'ถ่ายรูปจากกล้อง',
                  style: TextStyle(fontFamily: 'Kanit'),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickLicenseImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: Color(0xFF004381),
                ),
                title: const Text(
                  'เลือกจากคลังภาพ',
                  style: TextStyle(fontFamily: 'Kanit'),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickLicenseImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 🔥 2. ฟังก์ชันกดปุ่ม "ต่อไป" แก้ให้พาไปหน้า Step 3
  Future<void> _onNextPressed() async {
    if (_formKey.currentState!.validate()) {
      final bool isSelfDrive =
          _selectedDriverType == 'ขับขี่เอง' ||
          _selectedDriverType == 'SELF_DRIVE';

      if (isSelfDrive) {
        if (_selectedSelfDriveDriver == null ||
            _selectedSelfDriveDriver!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'กรุณาเลือกผู้ขับรถจากรายชื่อผู้โดยสาร',
                style: TextStyle(fontFamily: 'Kanit'),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }

        // ✅ บังคับอัปโหลดเฉพาะกรณีไม่มีใบขับขี่ในระบบ หรือใบขับขี่หมดอายุ
        if ((!_hasLicenseInSystem || _isLicenseExpired) &&
            _licenseImage == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'กรุณาอัปโหลดรูปภาพใบขับขี่',
                style: TextStyle(fontFamily: 'Kanit'),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }
      }

      // 🟢 นำรายละเอียดเพิ่มเติม (ถ้ามี) มาต่อท้ายวัตถุประสงค์เพื่อไม่ให้ข้อมูลสูญหาย
      String finalPurpose = objectiveController.text.trim();
      if (detailsController.text.trim().isNotEmpty) {
        finalPurpose += ' - ${detailsController.text.trim()}';
      }

      // ดึงข้อมูล User จาก SharedPreferences แทนตัวแปร Global
      final prefs = await SharedPreferences.getInstance();
      final currentUserName =
          prefs.getString('fullName') ??
          prefs.getString('username') ??
          prefs.getString('name') ??
          'ไม่ระบุชื่อ';

      int currentUserId = 0;
      final userIdDynamic =
          prefs.get('userId') ?? prefs.get('user_id') ?? prefs.get('id');
      if (userIdDynamic != null) {
        if (userIdDynamic is int) {
          currentUserId = userIdDynamic;
        } else if (userIdDynamic is String) {
          currentUserId = int.tryParse(userIdDynamic) ?? 0;
        }
      }

      if (!mounted) return;

      List<String> finalPassengerNames = List.from(widget.passengerNames);
      if (isSelfDrive && _selectedSelfDriveDriver != null) {
        finalPassengerNames.remove(_selectedSelfDriveDriver);
        finalPassengerNames.insert(0, _selectedSelfDriveDriver!);
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VehicleBookingConfirmPage(
            vehicle: widget.vehicle,
            destination: widget.destination,
            startDate: widget.startDate,
            endDate: widget.endDate,
            timeRange: widget.timeRange,
            returnTime: widget.returnTime,
            passengerCount: widget.passengerCount,
            passengerNames: finalPassengerNames,
            driverType: _selectedDriverType,
            licenseImage: isSelfDrive ? _licenseImage : null,
            purpose: finalPurpose,
            bookerName: currentUserName,
            userId: currentUserId,
          ),
        ),
      );
    }
  }

  String _formatDateThai(DateTime date) {
    final List<String> months = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year + 543}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF004381),
        title: const Text(
          'จองรถบริษัท',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Kanit',
          ),
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          // 🔵 เพิ่ม Container แถบสีน้ำเงินตรงนี้ครับ
          Container(
            width: double.infinity,
            color: const Color(0xFF004381),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: const Text(
              'กรอกข้อมูลการจอง',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Kanit',
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('วันและเวลาที่ต้องการใช้งาน'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          'เริ่ม: ${_formatDateThai(widget.startDate)} เวลา ${widget.timeRange} น.\nคืนรถ: ${_formatDateThai(widget.endDate)} เวลา ${widget.returnTime} น.',
                          style: const TextStyle(
                            fontFamily: 'Kanit',
                            fontSize: 14,
                            color: Color(0xFF4B5563),
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      _buildLabel('วัตถุประสงค์', isRequired: true),
                      const SizedBox(height: 8),
                      // 💡 เปลี่ยนจาก Dropdown เป็น TextFormField สำหรับพิมพ์ข้อความ
                      TextFormField(
                        controller: objectiveController,
                        style: const TextStyle(
                          fontFamily: 'Kanit',
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'เช่น พบลูกค้า, ติดต่อราชการ ฯลฯ',
                          hintStyle: TextStyle(
                            fontFamily: 'Kanit',
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF009CB4),
                            ),
                          ),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'กรุณากรอกวัตถุประสงค์'
                            : null,
                      ),
                      const SizedBox(height: 20),

                      _buildLabel('รายละเอียดเพิ่มเติม (Optional)'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: detailsController,
                        maxLines: 2,
                        style: const TextStyle(
                          fontFamily: 'Kanit',
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'ไปหน้างานที่อยุธยา อื่นๆ',
                          hintStyle: TextStyle(
                            fontFamily: 'Kanit',
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF009CB4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 🟢 แสดง Dropdown เลือกผู้ขับรถและใบขับขี่เฉพาะกรณี "ขับขี่เอง" / SELF_DRIVE เท่านั้น
                      if (_selectedDriverType == 'ขับขี่เอง' ||
                          _selectedDriverType == 'SELF_DRIVE') ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value:
                              (widget.passengerNames.contains(
                                _selectedSelfDriveDriver,
                              ))
                              ? _selectedSelfDriveDriver
                              : (widget.passengerNames.isNotEmpty
                                    ? widget.passengerNames.first
                                    : null),
                          decoration: InputDecoration(
                            labelText: 'ผู้ขับรถ (เลือกจากรายชื่อผู้โดยสาร) *',
                            labelStyle: const TextStyle(
                              fontFamily: 'Kanit',
                              fontSize: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          style: const TextStyle(
                            fontFamily: 'Kanit',
                            color: Colors.black,
                          ),
                          items: widget.passengerNames.map((name) {
                            return DropdownMenuItem<String>(
                              value: name,
                              child: Text(
                                name,
                                style: const TextStyle(fontFamily: 'Kanit'),
                              ),
                            );
                          }).toList(),
                          onChanged: (driverName) {
                            setState(() {
                              _selectedSelfDriveDriver = driverName;
                            });
                            if (driverName != null) {
                              _checkLicenseStatus(
                                widget.driverEmployeeId,
                                driverName,
                              );
                            }
                          },
                          validator: (value) => (value == null || value.isEmpty)
                              ? 'กรุณาเลือกผู้ขับรถ'
                              : null,
                        ),
                      ],

                      const SizedBox(height: 20),

                      if (_selectedDriverType == 'ขับขี่เอง' ||
                          _selectedDriverType == 'SELF_DRIVE') ...[
                        if (_isCheckingLicense)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: CircularProgressIndicator()),
                          ),

                        if (!_isCheckingLicense && _isLicenseExpired)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'ใบขับขี่ในระบบหมดอายุแล้ว กรุณาอัปโหลดใบขับขี่ใหม่',
                                    style: TextStyle(
                                      fontFamily: 'Kanit',
                                      fontSize: 14,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (!_isCheckingLicense &&
                            (!_hasLicenseInSystem || _isLicenseExpired)) ...[
                          _buildLabel(
                            'อัปโหลดรูปภาพใบขับขี่',
                            isRequired: true,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'อัปโหลดใบขับขี่ (ผู้ขับขี่ต้องเป็นพนักงาน)',
                            style: TextStyle(
                              fontFamily: 'Kanit',
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: _licenseImage == null
                                ? _showImageSourceSelector
                                : null,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: double.infinity,
                              height: 220,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: _licenseImage != null
                                  ? Stack(
                                      children: [
                                        Positioned.fill(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: RotatedBox(
                                              quarterTurns: _imageRotation,
                                              child: kIsWeb
                                                  ? Image.network(
                                                      _licenseImage!.path,
                                                      key: ValueKey(
                                                        _licenseImage!.path,
                                                      ),
                                                      width: double.infinity,
                                                      height: double.infinity,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (
                                                            context,
                                                            error,
                                                            stackTrace,
                                                          ) => const Center(
                                                            child: Icon(
                                                              Icons
                                                                  .broken_image,
                                                              color:
                                                                  Colors.grey,
                                                              size: 40,
                                                            ),
                                                          ),
                                                    )
                                                  : Image.file(
                                                      File(_licenseImage!.path),
                                                      key: ValueKey(
                                                        _licenseImage!.path,
                                                      ),
                                                      width: double.infinity,
                                                      height: double.infinity,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (
                                                            context,
                                                            error,
                                                            stackTrace,
                                                          ) => const Center(
                                                            child: Icon(
                                                              Icons
                                                                  .broken_image,
                                                              color:
                                                                  Colors.grey,
                                                              size: 40,
                                                            ),
                                                          ),
                                                    ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 12,
                                          right: 12,
                                          child: InkWell(
                                            onTap: () {
                                              setState(() {
                                                _imageRotation =
                                                    (_imageRotation + 1) % 4;
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: const BoxDecoration(
                                                color: Colors.black54,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.rotate_90_degrees_ccw,
                                                color: Colors.white,
                                                size: 22,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 12,
                                          right: 60,
                                          child: InkWell(
                                            onTap: _showImageSourceSelector,
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: const BoxDecoration(
                                                color: Colors.black54,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.edit,
                                                color: Colors.white,
                                                size: 22,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.camera_alt_outlined,
                                          color: Colors.grey.shade400,
                                          size: 40,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'แตะ ถ่ายรูปหรืออัปโหลดใบขับขี่\n(แนะนำให้ถ่ายแนวนอน)',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontFamily: 'Kanit',
                                            fontSize: 14,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ], // ปิด condition ของ !_hasLicenseInSystem || _isLicenseExpired
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(color: Color(0xFFF4F7FA)),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _onNextPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF009CB4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text(
              'ต่อไป',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Kanit',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E2841),
            fontFamily: 'Kanit',
          ),
        ),
        if (isRequired)
          const Text(
            ' *',
            style: TextStyle(
              color: Colors.red,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepItem(
            step: '1',
            title: 'เลือกรถ',
            isActive: true,
            isDone: true,
          ),
          _buildStepLine(isActive: true),
          _buildStepItem(
            step: '2',
            title: 'กรอกข้อมูล',
            isActive: true,
            isDone: false,
          ),
          _buildStepLine(isActive: false),
          _buildStepItem(
            step: '3',
            title: 'ยืนยัน',
            isActive: false,
            isDone: false,
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({
    required String step,
    required String title,
    required bool isActive,
    required bool isDone,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 70,
          height: 36,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF009CB4) : const Color(0xFFE6EDF5),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: TextStyle(
              color: isActive ? Colors.white : const Color(0xFFAAB6C7),
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Kanit',
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            color: isActive ? const Color(0xFF004381) : const Color(0xFFAAB6C7),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'Kanit',
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine({required bool isActive}) {
    return Container(
      margin: const EdgeInsets.only(top: 17, left: 4, right: 4),
      width: 80,
      height: 2,
      color: isActive ? const Color(0xFF009CB4) : const Color(0xFFE6EDF5),
    );
  }
}
