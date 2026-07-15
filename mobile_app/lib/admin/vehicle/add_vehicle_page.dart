import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart'; // 💡 เพิ่มบรรทัดนี้! เพื่อจัดการประเภทไฟล์ (MIME Type)

import 'addvehicle_successpage.dart'; 
import '../../Booking_vehicle/Vehicle_model.dart'; 

class AddVehiclePage extends StatefulWidget {
  const AddVehiclePage({super.key});

  @override
  State<AddVehiclePage> createState() => _AddVehiclePageState();
}

class _AddVehiclePageState extends State<AddVehiclePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController plateController = TextEditingController();

  final String currentStatus = 'AVAILABLE';
  int passengerCount = 4;

  XFile? _vehicleImage;
  String? _docFilePath; 
  String? _docFileName; 

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    nameController.dispose();
    plateController.dispose();
    super.dispose();
  }

  void _incrementPassenger() { setState(() { passengerCount++; }); }
  void _decrementPassenger() { if (passengerCount > 1) { setState(() { passengerCount--; }); } }

  Future<void> _pickVehicleImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) { setState(() { _vehicleImage = image; }); }
  }

  Future<void> _pickDocFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png']);
    if (result != null) {
      setState(() { _docFilePath = result.files.single.path; _docFileName = result.files.single.name; });
    }
  }

  void _showConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) { 
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    const Icon(Icons.directions_car, size: 70, color: Color(0xFF003E75)),
                    Container(decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.add_circle, size: 28, color: Color(0xFF003E75))),
                  ],
                ),
                const SizedBox(height: 16), const Text('ยืนยันการเพิ่มรถ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF003E75))), const SizedBox(height: 8), const Text('คุณต้องการเพิ่มรถใช่หรือไม่?', style: TextStyle(fontSize: 14, color: Color(0xFF003E75))), const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext); 
                          showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF009CB4))));

                          try {
                            final prefs = await SharedPreferences.getInstance();
                            final String? token = prefs.getString('token');

                            if (token == null || token.isEmpty) {
                              // ignore: use_build_context_synchronously
                              Navigator.pop(context);
                              // ignore: use_build_context_synchronously
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อนใช้งาน (No Token)'), backgroundColor: Colors.redAccent));
                              return;
                            }

                            var request = http.MultipartRequest('POST', Uri.parse('http://localhost:3001/api/vehicles'));
                            request.headers['Authorization'] = 'Bearer $token';
                            
                            request.fields['vehicleName'] = nameController.text;
                            request.fields['plateNumber'] = plateController.text;
                            request.fields['seats'] = passengerCount.toString();
                            request.fields['status'] = currentStatus;
                            request.fields['brand'] = "-"; 
                            request.fields['model'] = "Sedan"; 

                            // 🔥 ไฮไลท์การแก้ปัญหา: บังคับนามสกุลไฟล์ และระบุ MediaType
                            if (_vehicleImage != null) {
                              if (kIsWeb) {
                                var bytes = await _vehicleImage!.readAsBytes();
                                request.files.add(http.MultipartFile.fromBytes(
                                  'image', 
                                  bytes, 
                                  filename: 'upload_web_image.jpg', // 💡 1. บังคับชื่อไฟล์ให้มีนามสกุล .jpg
                                  contentType: MediaType('image', 'jpeg') // 💡 2. บังคับบอกเซิร์ฟเวอร์ว่าไฟล์นี้คือรูปภาพ
                                ));
                              } else {
                                request.files.add(await http.MultipartFile.fromPath('image', _vehicleImage!.path));
                              }
                            }

                            var streamedResponse = await request.send();
                            var response = await http.Response.fromStream(streamedResponse);

                            // ignore: use_build_context_synchronously
                            Navigator.pop(context);

                            if (response.statusCode == 201 || response.statusCode == 200) {
                              final responseData = jsonDecode(response.body);
                              
                              VehicleModel newVehicle = VehicleModel(
                                id: responseData['data']['id'], 
                                vehicleName: responseData['data']['vehicleName'] ?? nameController.text,
                                plateNumber: responseData['data']['plateNumber'] ?? plateController.text,
                                status: responseData['data']['status'] ?? currentStatus,
                                seats: responseData['data']['seats'] ?? passengerCount,
                                model: responseData['data']['model'] ?? 'Sedan', 
                                brand: responseData['data']['brand'] ?? '-', 
                                uploadUrl: responseData['data']['uploadUrl'] ?? '', 
                              );
                              
                              globalVehicles.value = [...globalVehicles.value, newVehicle];

                              // ignore: use_build_context_synchronously
                              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AddVehicleSuccessPage()));
                            } else {
                              final errorData = jsonDecode(response.body);
                              // ignore: use_build_context_synchronously
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorData['error'] ?? errorData['message'] ?? 'บันทึกไม่สำเร็จ (${response.statusCode})'), backgroundColor: Colors.redAccent));
                            }
                          } catch (e) {
                            // ignore: use_build_context_synchronously
                            Navigator.pop(context);
                            // ignore: use_build_context_synchronously
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้'), backgroundColor: Colors.redAccent));
                          }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF003E75),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text('เพิ่มรถเข้า', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
                      const Text('เลือกรูปภาพรถยนต์', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      GestureDetector(
                        onTap: _pickVehicleImage,
                        child: Container(
                          width: 100, height: 65,
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
                          child: _vehicleImage != null
                              ? ClipRRect(borderRadius: BorderRadius.circular(10), child: kIsWeb ? Image.network(_vehicleImage!.path, fit: BoxFit.cover) : Image.file(File(_vehicleImage!.path), fit: BoxFit.cover))
                              : Stack(alignment: Alignment.center, children: [Icon(Icons.directions_car, color: Colors.grey.shade300, size: 50), Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), shape: BoxShape.circle), child: const Icon(Icons.camera_alt_outlined, color: Colors.black87, size: 16))]),
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
                          bool isDuplicate = globalVehicles.value.any((v) => v.plateNumber.replaceAll(' ', '') == inputPlate);
                          if (isDuplicate) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ทะเบียนรถนี้มีในระบบแล้ว กรุณาตรวจสอบอีกครั้ง'), backgroundColor: Colors.redAccent));
                            return; 
                          }
                          if (_vehicleImage == null) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาเลือกรูปภาพรถยนต์'), backgroundColor: Colors.redAccent));
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
        TextFormField(controller: controller, style: const TextStyle(color: Colors.black87, fontSize: 14), decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Color(0xFF9098A9), fontSize: 14), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade400)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF003E75), width: 1.5)), errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)), filled: true, fillColor: Colors.white), validator: (value) { if (isRequired && (value == null || value.trim().isEmpty)) return 'กรุณากรอกข้อมูล'; return null; }),
      ],
    );
  }

  Widget _buildCircleButton({required IconData icon, required VoidCallback onPressed}) {
    return InkWell(onTap: onPressed, borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), shape: BoxShape.circle), child: Icon(icon, size: 16, color: const Color(0xFF75BBE1))));
  }
}