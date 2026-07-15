import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'; 
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // 💡 เพิ่มสำหรับระบุประเภทไฟล์
import 'package:shared_preferences/shared_preferences.dart';

import '../../Booking_vehicle/Vehicle_model.dart'; 
import 'editvehicle_successpage.dart'; 

class EditVehiclePage extends StatefulWidget {
  final VehicleModel vehicle; 
  final int index;

  const EditVehiclePage({super.key, required this.vehicle, required this.index});

  @override
  State<EditVehiclePage> createState() => _EditVehiclePageState();
}

class _EditVehiclePageState extends State<EditVehiclePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  late TextEditingController plateController;

  late String currentStatus;
  late int passengerCount;

  // สำหรับจัดการรูปภาพ
  String? _carImagePath; 
  Uint8List? _webImageBytes; 
  bool _isNewImagePicked = false; 
  String? _imageFileName;

  // สำหรับเอกสาร พรบ.
  String? _docFilePath; 
  String? _docFileName; 

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.vehicle.vehicleName);
    plateController = TextEditingController(text: widget.vehicle.plateNumber);
    currentStatus = widget.vehicle.status;
    passengerCount = widget.vehicle.seats;
    
    _carImagePath = widget.vehicle.uploadUrl;
  }

  @override
  void dispose() {
    nameController.dispose();
    plateController.dispose();
    super.dispose();
  }

  void _incrementPassenger() { setState(() { passengerCount++; }); }
  void _decrementPassenger() { if (passengerCount > 1) { setState(() { passengerCount--; }); } }

  // =========================================================
  // 📸 ฟังก์ชันเลือกรูปภาพ (รองรับ Web และ Mobile)
  // =========================================================
  Future<void> _pickVehicleImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (kIsWeb) {
        var bytes = await image.readAsBytes();
        setState(() {
          _webImageBytes = bytes;
          _carImagePath = image.path;
          _imageFileName = image.name;
          _isNewImagePicked = true;
        });
      } else {
        setState(() {
          _carImagePath = image.path;
          _isNewImagePicked = true;
        });
      }
    }
  }

  Future<void> _pickDocFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png']);
    if (result != null) {
      setState(() {
        _docFilePath = result.files.single.path;
        _docFileName = result.files.single.name;
      });
    }
  }

  // =========================================================
  // 🚀 ฟังก์ชันยืนยันและบันทึกข้อมูลไปฐานข้อมูล
  // =========================================================
  void _showConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    const Icon(Icons.directions_car, size: 70, color: Color(0xFF003E75)),
                    Container(decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.edit, size: 28, color: Color(0xFF003E75))),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('ยืนยันการแก้ไขรถ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF003E75))),
                const SizedBox(height: 8),
                const Text('คุณต้องการบันทึกการแก้ไขใช่หรือไม่?', style: TextStyle(fontSize: 14, color: Color(0xFF003E75))),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext); // ปิด popup ยืนยัน
                          await _submitUpdate(); 
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF009CB4), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        child: const Text('ตกลง', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB20000), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        child: const Text('ยกเลิก', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
  }

  // =========================================================
  // 📡 ฟังก์ชันยิง API ไปหาหลังบ้าน
  // =========================================================
  Future<void> _submitUpdate() async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      var uri = Uri.parse('http://localhost:3001/api/vehicles/${widget.vehicle.id}');
      var request = http.MultipartRequest('PUT', uri);
      
      request.headers['Authorization'] = 'Bearer $token';
      
      request.fields['vehicleName'] = nameController.text;
      request.fields['plateNumber'] = plateController.text;
      request.fields['seats'] = passengerCount.toString();

      // 💡 ส่งรูปภาพพร้อมระบุว่าเป็นไฟล์ JPEG ให้ Multer ยอมรับ
      if (_isNewImagePicked) {
        if (kIsWeb && _webImageBytes != null) {
          request.files.add(http.MultipartFile.fromBytes(
            'image', 
            _webImageBytes!, 
            filename: _imageFileName ?? 'upload.jpg',
            contentType: MediaType('image', 'jpeg'),
          ));
        } else if (_carImagePath != null) {
          request.files.add(await http.MultipartFile.fromPath(
            'image', 
            _carImagePath!,
            contentType: MediaType('image', 'jpeg'),
          ));
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;
      Navigator.pop(context); // ปิด Loading

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        
        // 💡 ดึง URL รูปใหม่จากออบเจกต์ 'data' ที่หลังบ้านส่งกลับมา
        final updatedData = responseData['data'] ?? {};

        List<VehicleModel> updatedList = List.from(globalVehicles.value);
        updatedList[widget.index] = VehicleModel(
          id: widget.vehicle.id,
          vehicleName: nameController.text,
          plateNumber: plateController.text,
          status: currentStatus,
          seats: passengerCount,
          model: widget.vehicle.model,
          brand: widget.vehicle.brand, 
          // เซ็ตค่า URL รูปล่าสุด
          uploadUrl: updatedData['uploadUrl'] ?? widget.vehicle.uploadUrl ?? '', 
          isDeleted: widget.vehicle.isDeleted,
          hasFutureBooking: widget.vehicle.hasFutureBooking,
        );
        globalVehicles.value = updatedList; 

        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const EditVehicleSuccessPage()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกข้อมูลไม่สำเร็จ กรุณาลองใหม่'), backgroundColor: Colors.redAccent));
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // ปิด Loading
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('เกิดข้อผิดพลาดในการเชื่อมต่อเซิร์ฟเวอร์'), backgroundColor: Colors.redAccent));
    }
  }

  // =========================================================
  // 🖼️ วิดเจ็ตจัดการแสดงรูปภาพ
  // =========================================================
  Widget _buildCarImage() {
    if (_isNewImagePicked) {
      if (kIsWeb && _webImageBytes != null) {
        return Image.memory(_webImageBytes!, fit: BoxFit.cover);
      } else if (_carImagePath != null) {
        return Image.file(File(_carImagePath!), fit: BoxFit.cover);
      }
    } else if (_carImagePath != null && _carImagePath!.isNotEmpty) {
      String imgUrl = _carImagePath!;
      // เติม localhost ให้ถ้ารูปมาจาก backend
      if (imgUrl.startsWith('/uploads')) {
        imgUrl = 'http://localhost:3001$imgUrl';
      }
      return Image.network(imgUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.directions_car, color: Colors.grey, size: 50));
    }
    
    // กรณีไม่มีรูป
    return Stack(
      alignment: Alignment.center, 
      children: [
        Icon(Icons.directions_car, color: Colors.grey.shade300, size: 50), 
        Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), shape: BoxShape.circle), child: const Icon(Icons.camera_alt_outlined, color: Colors.black87, size: 16))
      ]
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF003E75),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text('แก้ไขโปรไฟล์รถ', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true, elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey, 
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))], border: Border.all(color: Colors.grey.shade100)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('เปลี่ยนรูปภาพรถยนต์', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      GestureDetector(
                        onTap: _pickVehicleImage,
                        child: Container(
                          width: 100, height: 65,
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10), 
                            child: _buildCarImage()
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))], border: Border.all(color: Colors.grey.shade100)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(label: 'ชื่อรถยนต์', controller: nameController, isRequired: true),
                      const SizedBox(height: 24),
                      Center(child: SizedBox(width: 200, child: _buildTextField(label: 'ทะเบียนรถ', controller: plateController, hint: 'กข 1234', isRequired: true))),
                      const SizedBox(height: 24),
                      Divider(color: Colors.indigo.shade50, thickness: 1.5),
                      const SizedBox(height: 20),
                      Center(
                        child: Column(
                          children: [
                            const Text('จำนวนผู้โดยสาร (คน)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12), color: Colors.grey.shade50),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildCircleButton(icon: Icons.remove, onPressed: _decrementPassenger),
                                  const SizedBox(width: 24),
                                  Row(children: [const Icon(Icons.people_outline, color: Colors.grey, size: 20), const SizedBox(width: 6), Text('$passengerCount', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey))]),
                                  const SizedBox(width: 24),
                                  _buildCircleButton(icon: Icons.add, onPressed: _incrementPassenger),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Divider(color: Colors.indigo.shade50, thickness: 1.5),
                      const SizedBox(height: 20),
                      const Text('เอกสารรถ (พรบ)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10), color: Colors.grey.shade50),
                              child: Row(
                                children: [
                                  Icon(_docFileName != null ? Icons.check_circle : Icons.upload_file, color: _docFileName != null ? Colors.green : Colors.grey, size: 24),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(_docFileName ?? 'ยังไม่ได้เลือกไฟล์', style: TextStyle(color: _docFileName != null ? Colors.black87 : Colors.grey.shade600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: _pickDocFile,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(border: Border.all(color: const Color(0xFF009CB4)), borderRadius: BorderRadius.circular(10), color: const Color(0xFFE5F5F7)),
                              alignment: Alignment.center,
                              child: const Text('เลือกไฟล์', style: TextStyle(color: Color(0xFF009CB4), fontSize: 14, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40), 
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          String inputPlate = plateController.text.replaceAll(' ', '');
                          
                          bool isDuplicate = globalVehicles.value.asMap().entries.any((entry) {
                            int currentIndex = entry.key;
                            VehicleModel v = entry.value; 
                            return currentIndex != widget.index && v.plateNumber.replaceAll(' ', '') == inputPlate;
                          });

                          if (isDuplicate) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ทะเบียนรถนี้มีในระบบแล้ว กรุณาตรวจสอบอีกครั้ง'), backgroundColor: Colors.redAccent));
                            return; 
                          }
                          _showConfirmationDialog(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF009CB4), elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('ยืนยัน', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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

  Widget _buildTextField({required String label, required TextEditingController controller, String? hint, bool isRequired = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)), const SizedBox(height: 8),
        TextFormField(
          controller: controller, style: const TextStyle(color: Colors.black87, fontSize: 14),
          decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Color(0xFF9098A9), fontSize: 14), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade400)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF003E75), width: 1.5)), errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)), filled: true, fillColor: Colors.white),
          validator: (value) { if (isRequired && (value == null || value.trim().isEmpty)) return 'กรุณากรอกข้อมูล'; return null; },
        ),
      ],
    );
  }

  Widget _buildCircleButton({required IconData icon, required VoidCallback onPressed}) {
    return InkWell(onTap: onPressed, borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), shape: BoxShape.circle), child: Icon(icon, size: 16, color: const Color(0xFF75BBE1))));
  }
}