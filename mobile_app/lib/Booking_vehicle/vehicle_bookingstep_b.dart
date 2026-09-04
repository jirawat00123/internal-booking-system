import 'dart:io';
import 'package:mobile_app/Booking_vehicle/Vehicle_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'vehicle_booking_confirm.dart';

class VehicleBookingFormBPage extends StatefulWidget {
  // 🟢 1. ประกาศตัวแปรมารับค่าที่ส่งมาจากหน้า A
  final VehicleModel vehicle;
  final String destination;
  final String startDate;
  final String endDate;
  final String timeRange;
  final int passengerCount;
  final List<String> passengerNames;
  final String driverType; // 💡 1. เพิ่มตัวแปร userId ตรงนี้ครับ!

  const VehicleBookingFormBPage({
    super.key,
    required this.vehicle,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.timeRange,
    required this.passengerCount,
    this.passengerNames = const [],
    required this.driverType, // 💡 2. บังคับรับค่า userId
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

  @override
  void initState() {
    super.initState();
    _selectedDriverType = (widget.driverType.isNotEmpty)
        ? widget.driverType
        : 'ขับขี่เอง';
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
  void _onNextPressed() {
    if (_formKey.currentState!.validate()) {
      if (_selectedDriverType == 'ขับขี่เอง' && _licenseImage == null) {
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

      // 🟢 นำรายละเอียดเพิ่มเติม (ถ้ามี) มาต่อท้ายวัตถุประสงค์เพื่อไม่ให้ข้อมูลสูญหาย
      String finalPurpose = objectiveController.text.trim();
      if (detailsController.text.trim().isNotEmpty) {
        finalPurpose += ' - ${detailsController.text.trim()}';
      }

      // 🚀 นำทางไปหน้า Step 3 (ตรวจสอบข้อมูลและยืนยัน)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VehicleBookingConfirmPage(
            vehicle: widget.vehicle,
            destination: widget.destination,
            startDate: widget.startDate,
            endDate: widget.endDate,
            timeRange: widget.timeRange,
            passengerCount: widget.passengerCount,
            passengerNames: widget.passengerNames,
            driverType: _selectedDriverType,
            licenseImage: _licenseImage,
            purpose: finalPurpose,
            bookerName: globalCurrentUserName, // ดึงชื่อตัวจริงมา
            userId:
                globalCurrentUserId, // 💡 เปลี่ยนเลข 2 เป็นตัวแปรที่เก็บ ID ตัวจริงครับ!
          ),
        ),
      );
    }
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
                          'เริ่ม: ${widget.startDate} เวลา ${widget.timeRange} น.\nคืนรถ: ${widget.endDate}',
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

                      _buildLabel('ประเภทผู้ขับขี่', isRequired: true),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text(
                                'ขับขี่เอง',
                                style: TextStyle(
                                  fontFamily: 'Kanit',
                                  fontSize: 14,
                                ),
                              ),
                              value: 'ขับขี่เอง',
                              groupValue: _selectedDriverType,
                              contentPadding: EdgeInsets.zero,
                              activeColor: const Color(0xFF009CB4),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedDriverType = value;
                                  });
                                }
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text(
                                'บริษัท',
                                style: TextStyle(
                                  fontFamily: 'Kanit',
                                  fontSize: 14,
                                ),
                              ),
                              value: 'บริษัท',
                              groupValue: _selectedDriverType,
                              contentPadding: EdgeInsets.zero,
                              activeColor: const Color(0xFF009CB4),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedDriverType = value;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      _buildLabel(
                        'อัปโหลดรูปภาพใบขับขี่',
                        isRequired: _selectedDriverType == 'ขับขี่เอง',
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

                      // 📸 กล่องอัปโหลดรูปภาพ
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
                                        borderRadius: BorderRadius.circular(8),
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
                                                          Icons.broken_image,
                                                          color: Colors.grey,
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
                                                          Icons.broken_image,
                                                          color: Colors.grey,
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
                                  mainAxisAlignment: MainAxisAlignment.center,
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
