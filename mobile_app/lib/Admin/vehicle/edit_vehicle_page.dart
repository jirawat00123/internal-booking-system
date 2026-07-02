import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart'; 
import 'package:file_picker/file_picker.dart';

import 'vehicle_page.dart';
import 'editvehicle_successpage.dart';


class EditVehiclePage extends StatefulWidget {
  final Vehicle vehicle;
  final int index;

  const EditVehiclePage({super.key, required this.vehicle, required this.index});

  @override
  State<EditVehiclePage> createState() => _EditVehiclePageState();
}

class _EditVehiclePageState extends State<EditVehiclePage> {
  late TextEditingController _nameController;
  late TextEditingController _plateController;
  late int _capacity;
  
  String? _carImagePath;
  String? _docFilePath; // 🟢 ตัวแปรเก็บพาธไฟล์ พรบ.
  String? _docFileName; // 🟢 ตัวแปรเก็บชื่อไฟล์ พรบ.

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.vehicle.name);
    _plateController = TextEditingController(text: widget.vehicle.plate);
    _capacity = widget.vehicle.capacity;
    _carImagePath = widget.vehicle.imagePath;
    
    _docFilePath = null; 
    _docFileName = null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  // 📸 ฟังก์ชันเลือกรูปรถ
  Future<void> _pickCarImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _carImagePath = image.path;
      });
    }
  }

  // 📄 ฟังก์ชันเลือกไฟล์เอกสาร (รองรับ PDF, DOC, รูปภาพ)
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

  // 🔴 ฟังก์ชันแสดง Popup ยืนยันการแก้ไข
  void _showEditConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
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
                    const Icon(Icons.directions_car, size: 60, color: Color(0xFF0056A0)),
                    Container(
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.edit, size: 24, color: Color(0xFF0056A0)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('ยืนยันการแก้ไขรถ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF003E75))),
                const SizedBox(height: 8),
                const Text('คุณต้องการแก้ไขรถใช่หรือไม่?', style: TextStyle(fontSize: 14, color: Color(0xFF003E75)), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // 1. บันทึกข้อมูล
                          globalVehicles[widget.index] = Vehicle(
                            id: widget.vehicle.id,
                            name: _nameController.text,
                            plate: _plateController.text,
                            capacity: _capacity,
                            status: widget.vehicle.status,
                            type: widget.vehicle.type,
                            imagePath: _carImagePath,
                          );
                          
                          // 2. ปิด Popup
                          Navigator.pop(dialogContext); 
                          
                          // 🟢 3. เปลี่ยนจาก pop กลับเฉยๆ เป็นการเด้งไปหน้า Success แทน
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const EditVehicleSuccessPage()),
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
                        onPressed: () => Navigator.pop(dialogContext),
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

  // 🖼️ ฟังก์ชันแสดงรูปภาพ (รองรับทั้ง Web และ Mobile)
  Widget _buildImagePreview(String? path, {double width = 100, double height = 60}) {
    if (path == null) {
      return Container(width: width, height: height, color: Colors.grey.shade300);
    }
    return kIsWeb
        ? Image.network(path, width: width, height: height, fit: BoxFit.cover)
        : Image.file(File(path), width: width, height: height, fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003E75),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('แก้ไขโปรไฟล์รถ', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 🖼️ Card 1: เปลี่ยนรูปภาพรถ
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('เปลี่ยนรูปภาพรถยนต์', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                    GestureDetector(
                      onTap: _pickCarImage, 
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: _buildImagePreview(_carImagePath, width: 120, height: 70),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 📝 Card 2: ข้อมูลรถ
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ชื่อรถยนต์', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    Center(
                      child: Column(
                        children: [
                          const Text('ทะเบียนรถ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 140, 
                            child: TextField(
                              controller: _plateController,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFF8DA2CD), fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const Padding(padding: EdgeInsets.symmetric(vertical: 24.0), child: Divider()),
                    
                    Center(
                      child: Column(
                        children: [
                          const Text('จำนวนผู้โดยสาร (คน)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
                          const SizedBox(height: 8),
                          Container(
                            width: 160,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, color: Colors.grey, size: 20),
                                  onPressed: () {
                                    if (_capacity > 1) setState(() => _capacity--);
                                  },
                                ),
                                Text('👥 $_capacity', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                IconButton(
                                  icon: const Icon(Icons.add, color: Colors.grey, size: 20),
                                  onPressed: () {
                                    setState(() => _capacity++);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const Padding(padding: EdgeInsets.symmetric(vertical: 24.0), child: Divider()),
                    
                    // เอกสารรถ (พรบ) - เปลี่ยนเป็นปุ่มเลือกไฟล์
                    const Text('เอกสารรถ (พรบ)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
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
                                  _docFileName != null ? Icons.check_circle : Icons.upload_file,
                                  color: _docFileName != null ? Colors.green : Colors.grey,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _docFileName ?? 'ยังไม่ได้เลือกไฟล์',
                                    style: TextStyle(
                                      color: _docFileName != null ? Colors.black87 : Colors.grey.shade600,
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
                          onTap: _pickDocFile, // 🟢 เรียกใช้ฟังก์ชันเลือกไฟล์
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFF009CB4)),
                              borderRadius: BorderRadius.circular(10),
                              color: const Color(0xFFE5F5F7),
                            ),
                            alignment: Alignment.center,
                            child: const Text('เลือกไฟล์', style: TextStyle(color: Color(0xFF009CB4), fontSize: 14, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // 🔘 ปุ่มยืนยัน
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () => _showEditConfirmDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF009CB4), 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: const Text('ยืนยัน', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}