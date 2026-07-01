import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'addvehicle_successpage.dart'; 
import 'vehicle_page.dart'; 

class AddVehiclePage extends StatefulWidget {
  const AddVehiclePage({super.key});

  @override
  State<AddVehiclePage> createState() => _AddVehiclePageState();
}

class _AddVehiclePageState extends State<AddVehiclePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController statusController = TextEditingController();
  final TextEditingController plateController = TextEditingController();

  int passengerCount = 4;

  XFile? _vehicleImage;
  XFile? _documentImage; 
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    nameController.dispose();
    statusController.dispose();
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
        _vehicleImage = image;
      });
    }
  }

  Future<void> _pickDocumentImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _documentImage = image;
      });
    }
  }

  void _showConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
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
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    const Icon(Icons.directions_car, size: 70, color: Color(0xFF003E75)),
                    Container(
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.add_circle, size: 28, color: Color(0xFF003E75)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('ยืนยันการเพิ่มรถ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF003E75))),
                const SizedBox(height: 8),
                const Text('คุณต้องการเพิ่มรถใช่หรือไม่?', style: TextStyle(fontSize: 14, color: Color(0xFF003E75))),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Vehicle newVehicle = Vehicle(
                            id: DateTime.now().toString(),
                            name: nameController.text,
                            plate: plateController.text,
                            status: statusController.text.isEmpty ? 'ว่างพร้อมใช้งาน' : statusController.text,
                            capacity: passengerCount,
                            type: 'รถยนต์', 
                            imagePath: _vehicleImage?.path, 
                          );
                          
                          globalVehicles.add(newVehicle);

                          Navigator.pop(context); 
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const AddVehicleSuccessPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF009CB4),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('ตกลง', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB20000), 
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('เพิ่มรถเข้า', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
                // 📸 กล่อง 1: เลือกรถภาพรถยนต์
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('เลือกรูปภาพรถยนต์', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      GestureDetector(
                        onTap: _pickVehicleImage,
                        child: Container(
                          width: 100,
                          height: 65,
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
                          child: _vehicleImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: kIsWeb
                                      ? Image.network(_vehicleImage!.path, fit: BoxFit.cover)
                                      : Image.file(File(_vehicleImage!.path), fit: BoxFit.cover),
                                )
                              : Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(Icons.directions_car, color: Colors.grey.shade300, size: 50),
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), shape: BoxShape.circle),
                                      child: const Icon(Icons.camera_alt_outlined, color: Colors.black87, size: 16),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 📝 กล่อง 2: ฟอร์มกรอกข้อมูล
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(label: 'ชื่อรถยนต์', controller: nameController, isRequired: true),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start, // ปรับให้อยู่ชิดบนเวลาขึ้น Error
                        children: [
                          Expanded(
                            child: _buildTextField(
                              label: 'สถานะรถยนต์',
                              controller: statusController,
                              hint: 'ว่างพร้อมใช้งาน',
                              isRequired: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              label: 'ทะเบียนรถ',
                              controller: plateController,
                              hint: 'กข 1234',
                              isRequired: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Divider(color: Colors.grey.shade100, thickness: 1),
                      const SizedBox(height: 16),
                      
                      // จำนวนผู้โดยสาร
                      Center(
                        child: Column(
                          children: [
                            const Text('จำนวนผู้โดยสาร (คน)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildCircleButton(icon: Icons.remove, onPressed: _decrementPassenger),
                                  const SizedBox(width: 24),
                                  Row(
                                    children: [
                                      const Icon(Icons.people_outline, color: Colors.grey, size: 20),
                                      const SizedBox(width: 6),
                                      Text('$passengerCount', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    ],
                                  ),
                                  const SizedBox(width: 24),
                                  _buildCircleButton(icon: Icons.add, onPressed: _incrementPassenger),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // 📄 เอกสารรถ (พรบ)
                      const Text('เอกสารรถ (พรบ)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            width: 80,
                            height: 100,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey.shade50,
                            ),
                            child: _documentImage != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: kIsWeb
                                        ? Image.network(_documentImage!.path, fit: BoxFit.cover)
                                        : Image.file(File(_documentImage!.path), fit: BoxFit.cover),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.receipt_long, color: Colors.grey.shade300, size: 40),
                                      const SizedBox(height: 4),
                                      Text('ภาพ พรบ', style: TextStyle(fontSize: 10, color: Colors.grey.shade400))
                                    ],
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GestureDetector(
                              onTap: _pickDocumentImage,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('สั่งรูปภาพ', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14)),
                              ),
                            ),
                          )
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                
                // 🟢 ปุ่มยืนยัน
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40), 
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        // 1. เช็กว่ากรอกข้อมูลครบไหม (ถ้าไม่ครบมันจะขึ้นตัวแดงเตือนที่ช่อง)
                        if (_formKey.currentState!.validate()) {
                          
                          // 2. เช็กว่าอัปรูปรถหรือยัง
                          if (_vehicleImage == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('กรุณาเลือกรูปภาพรถยนต์', style: TextStyle(fontFamily: 'Kanit')), backgroundColor: Colors.red),
                            );
                            return; // หยุดการทำงาน ไม่ให้ไปต่อ
                          }

                          // 3. เช็กว่าอัปรูปเอกสารหรือยัง
                          if (_documentImage == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('กรุณาอัปโหลดเอกสาร พรบ', style: TextStyle(fontFamily: 'Kanit')), backgroundColor: Colors.red),
                            );
                            return; // หยุดการทำงาน
                          }

                          // ถ้าผ่านครบหมดทุกด่าน ค่อยโชว์ Popup
                          _showConfirmationDialog(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF009CB4),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
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

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool isRequired = false, // เพิ่มพารามิเตอร์นี้เพื่อเช็ก
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFB0BAC7), fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            isDense: true,
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
              borderSide: const BorderSide(color: Color(0xFF003E75), width: 1.5),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          // 🟢 เพิ่มระบบตรวจสอบความถูกต้องตรงนี้ (Validator)
          validator: (value) {
            if (isRequired && (value == null || value.trim().isEmpty)) {
              return 'กรุณากรอกข้อมูล'; // ข้อความตัวแดงที่จะแจ้งเตือนใต้ช่อง
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCircleButton({required IconData icon, required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), shape: BoxShape.circle),
        child: Icon(icon, size: 16, color: const Color(0xFF75BBE1)),
      ),
    );
  }
}