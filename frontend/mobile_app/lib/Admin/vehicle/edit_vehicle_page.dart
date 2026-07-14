import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'editvehicle_successpage.dart';
import 'vehicle_page.dart'; // ดึง Model ของ Vehicle มาใช้

class EditVehiclePage extends StatefulWidget {
  final Vehicle vehicle;
  final int index;

  const EditVehiclePage({
    super.key,
    required this.vehicle,
    required this.index,
  });

  @override
  State<EditVehiclePage> createState() => _EditVehiclePageState();
}

class _EditVehiclePageState extends State<EditVehiclePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  late TextEditingController plateController;

  late String currentStatus;
  late int passengerCount;

  XFile? _newVehicleImage; // 🟢 รูปภาพใหม่ที่ผู้ใช้เลือกมาอัปเดต
  String? _docFilePath;
  String? _docFileName;

  bool isSubmitting = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // 🟢 ดึงข้อมูลเดิมจากหน้าต่างที่แล้วมาใส่ใน Controller
    nameController = TextEditingController(text: widget.vehicle.vehicleName);
    plateController = TextEditingController(text: widget.vehicle.plate);
    currentStatus = widget.vehicle.status;
    passengerCount = widget.vehicle.seats;
  }

  @override
  void dispose() {
    nameController.dispose();
    plateController.dispose();
    super.dispose();
  }

  void _incrementPassenger() {
    setState(() {
      passengerCount++;
    });
  }

  void _decrementPassenger() {
    if (passengerCount > 1) {
      setState(() {
        passengerCount--;
      });
    }
  }

  Future<void> _pickVehicleImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _newVehicleImage = image;
      });
    }
  }

  Future<void> _pickDocFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
    );

    if (result != null) {
      setState(() {
        _docFilePath = result.files.single.path;
        _docFileName = result.files.single.name;
      });
    }
  }

  // 🚀 ฟังก์ชันยิง API อัปเดตข้อมูลรถยนต์ (PUT)
  Future<void> _updateVehicleToApi(BuildContext dialogContext) async {
    setState(() {
      isSubmitting = true;
    });

    try {
      final baseUrl = kIsWeb ? 'http://localhost:3001' : 'http://10.0.2.2:3001';
      // 🚨 เปลี่ยนเป็นยิงไปที่ /api/vehicles/:id ด้วย HTTP PUT
      final url = Uri.parse('$baseUrl/api/vehicles/${widget.vehicle.id}');

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      var request = http.MultipartRequest('PUT', url);

      request.headers['Authorization'] = 'Bearer ${token.trim()}';

      // 🟢 ลอจิกหั่นคำอัจฉริยะ (แยกชื่อรถออกเป็น 'ยี่ห้อ' และ 'รุ่น' อัตโนมัติ)
      String fullName = nameController.text.trim();
      String plateText = plateController.text.trim();
      List<String> nameParts = fullName.split(' ');
      String brandStr = nameParts.isNotEmpty ? nameParts[0] : 'ไม่ระบุ';
      String modelStr = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : fullName;

      // 📦 ส่งข้อมูลไปยัง Backend ตาม Contract (Rule 12 & 14)
      request.fields['vehicleName'] = fullName;
      request.fields['plateNumber'] = plateText;
      request.fields['capacity'] = passengerCount.toString();
      request.fields['type'] = 'CAR';
      request.fields['status'] = currentStatus;

      // ส่งคีย์ตัวช่วยเพื่อกัน Error จากด่านตรวจ Backend
      request.fields['plate'] = plateText;
      request.fields['brand'] = brandStr;
      request.fields['model'] = modelStr;
      request.fields['seats'] = passengerCount.toString();
      request.fields['seatCount'] = passengerCount.toString();

      // 📸 กรณีผู้ใช้อัปโหลดรูปใหม่ (ถ้าไม่มีก็จะปล่อยว่างไว้ หลังบ้านจะใช้รูปเก่า)
      if (_newVehicleImage != null) {
        if (kIsWeb) {
          final bytes = await _newVehicleImage!.readAsBytes();

          String finalFileName = _newVehicleImage!.name;
          String lowerName = finalFileName.toLowerCase();
          if (!lowerName.endsWith('.png') &&
              !lowerName.endsWith('.jpg') &&
              !lowerName.endsWith('.jpeg')) {
            finalFileName = 'vehicle_image.png';
          }

          request.files.add(
            http.MultipartFile.fromBytes(
              'image',
              bytes,
              filename: finalFileName,
            ),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath('image', _newVehicleImage!.path),
          );
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.pop(dialogContext); // ปิด Dialog ยืนยัน
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const EditVehicleSuccessPage(),
            ),
          );
        }
      } else {
        debugPrint('🔥 Error API: ${response.body}');
        if (mounted) {
          Navigator.pop(dialogContext);
          _showUploadErrorDialog(context);
        }
      }
    } catch (e) {
      debugPrint('🔥 Exception: $e');
      if (mounted) {
        Navigator.pop(dialogContext);
        _showUploadErrorDialog(context);
      }
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
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
                  'แก้ไขข้อมูลไม่สำเร็จ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003E75),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'เซิร์ฟเวอร์อาจขัดข้อง หรือข้อมูลไม่ครบถ้วน',
                  style: TextStyle(fontSize: 14, color: Color(0xFF003E75)),
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
                    ),
                    child: const Text(
                      'ตกลง',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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

  void _showConfirmationDialog(BuildContext context) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: isSubmitting
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF003E75)),
                          SizedBox(height: 20),
                          Text(
                            'กำลังบันทึกข้อมูล...',
                            style: TextStyle(
                              color: Color(0xFF003E75),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              const Icon(
                                Icons.directions_car,
                                size: 70,
                                color: Color(0xFF003E75),
                              ),
                              Container(
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 28,
                                  color: Color(0xFF003E75),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'ยืนยันการแก้ไขข้อมูล',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF003E75),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'คุณต้องการบันทึกการเปลี่ยนแปลงใช่หรือไม่?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF003E75),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    setStateDialog(() {
                                      isSubmitting = true;
                                    });
                                    _updateVehicleToApi(
                                      dialogContext,
                                    ); // 🚀 ยิง API PUT
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF009CB4),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'ตกลง',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFB20000),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'ยกเลิก',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
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
          },
        );
      },
    );
  }

  // ตัวช่วยโหลดรูปรถเก่ามาโชว์
  Widget _buildVehicleImage() {
    // 1. ถ้ามีอัปโหลดรูปใหม่ โชว์รูปใหม่
    if (_newVehicleImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: kIsWeb
            ? Image.network(_newVehicleImage!.path, fit: BoxFit.cover)
            : Image.file(File(_newVehicleImage!.path), fit: BoxFit.cover),
      );
    }

    // 2. ถ้าไม่มีรูปใหม่ ให้เช็กว่ารถเก่ามีรูปไหม
    if (widget.vehicle.uploadUrl != null &&
        widget.vehicle.uploadUrl!.isNotEmpty) {
      final baseUrl = kIsWeb ? 'http://localhost:3001' : 'http://10.0.2.2:3001';
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          '$baseUrl${widget.vehicle.uploadUrl}', // ดึงรูปผ่าน Base URL
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholderIcon(),
        ),
      );
    }

    // 3. ถ้าไม่มีทั้งคู่ โชว์ไอคอนรถเปล่าๆ
    return _buildPlaceholderIcon();
  }

  Widget _buildPlaceholderIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.directions_car, color: Colors.grey.shade300, size: 50),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.camera_alt_outlined,
            color: Colors.black87,
            size: 16,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF003E75),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'แก้ไขข้อมูลรถยนต์',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // 📸 กล่อง 1: เลือกรูปภาพรถยนต์
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'รูปภาพรถยนต์',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: _pickVehicleImage,
                        child: Container(
                          width: 100,
                          height: 65,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _buildVehicleImage(),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 📝 กล่อง 2: ฟอร์มกรอกข้อมูล
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        label: 'ชื่อรถยนต์',
                        controller: nameController,
                        isRequired: true,
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: SizedBox(
                          width: 200,
                          child: _buildTextField(
                            label: 'ทะเบียนรถ',
                            controller: plateController,
                            hint: 'กข 1234',
                            isRequired: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Divider(color: Colors.indigo.shade50, thickness: 1.5),
                      const SizedBox(height: 20),

                      Center(
                        child: Column(
                          children: [
                            const Text(
                              'จำนวนผู้โดยสาร (คน)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.grey.shade50,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildCircleButton(
                                    icon: Icons.remove,
                                    onPressed: _decrementPassenger,
                                  ),
                                  const SizedBox(width: 24),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.people_outline,
                                        color: Colors.grey,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '$passengerCount',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 24),
                                  _buildCircleButton(
                                    icon: Icons.add,
                                    onPressed: _incrementPassenger,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      Divider(color: Colors.indigo.shade50, thickness: 1.5),
                      const SizedBox(height: 20),

                      // 📄 เอกสารรถ (พรบ)
                      const Text(
                        'เอกสารรถ (พรบ)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.grey.shade50,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _docFileName != null
                                        ? Icons.check_circle
                                        : Icons.upload_file,
                                    color: _docFileName != null
                                        ? Colors.green
                                        : Colors.grey,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _docFileName ?? 'ยังไม่ได้เลือกไฟล์',
                                      style: TextStyle(
                                        color: _docFileName != null
                                            ? Colors.black87
                                            : Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: _pickDocFile,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFF009CB4),
                                ),
                                borderRadius: BorderRadius.circular(10),
                                color: const Color(0xFFE5F5F7),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'เลือกไฟล์',
                                style: TextStyle(
                                  color: Color(0xFF009CB4),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // 🟢 ปุ่มบันทึกการแก้ไข
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _showConfirmationDialog(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF009CB4),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'บันทึกการแก้ไข',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9098A9), fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF003E75),
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) {
            if (isRequired && (value == null || value.trim().isEmpty)) {
              return 'กรุณากรอกข้อมูล';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF75BBE1)),
      ),
    );
  }
}
