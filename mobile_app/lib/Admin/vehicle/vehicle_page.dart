import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'add_vehicle_page.dart';
import 'edit_vehicle_page.dart';
import 'deletevehicle_successpage.dart'; // 🟢 ดึงหน้าลบสำเร็จมาใช้

// 💡 1. โครงสร้างเก็บข้อมูลรถ
class Vehicle {
  final String id;
  final String name;
  final String plate;
  final String status;
  final int capacity;
  final String type;
  final String? imagePath;

  Vehicle({
    required this.id,
    required this.name,
    required this.plate,
    this.status = 'ว่างพร้อมใช้งาน',
    required this.capacity,
    this.type = 'Sedan',
    this.imagePath,
  });
}

// 🟢 2. กล่องเก็บข้อมูลรถ (เริ่มต้นด้วยหน้าว่างเปล่า)
List<Vehicle> globalVehicles = [];

class VehiclePage extends StatefulWidget {
  const VehiclePage({super.key});

  @override
  State<VehiclePage> createState() => _VehiclePageState();
}

class _VehiclePageState extends State<VehiclePage> {
  
  // 🔴 ฟังก์ชันแสดง Popup ยืนยันการลบรถ
  void _showDeleteConfirmDialog(BuildContext context, int index) {
    showDialog(
      context: context,
      barrierDismissible: false, // บังคับให้ต้องกดปุ่มใดปุ่มหนึ่งเพื่อปิด
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
                // 🔴 ไอคอนเครื่องหมายตกใจสีแดง
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD32F2F), // สีแดง
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.priority_high,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                
                // 📝 ข้อความหัวข้อ
                const Text(
                  'ยืนยันการลบรถ',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003E75),
                  ),
                ),
                const SizedBox(height: 8),
                
                // 📝 ข้อความรายละเอียด
                const Text(
                  'คุณต้องการลบรถคันนี้ใช่หรือไม่?',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF003E75),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // 🖲️ ปุ่ม ลบรถ และ ยกเลิก
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // 1. ปิด Popup ก่อน
                          Navigator.pop(dialogContext);  
                          
                          // 2. สั่งลบข้อมูลออกจาก List
                          setState(() {
                            globalVehicles.removeAt(index);
                          });

                          // 🟢 3. สั่งเด้งไปหน้าลบสำเร็จ
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const DeleteVehicleSuccessPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB20000), // ปุ่มสีแดง
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'ลบรถ',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext); // ปิด Popup เฉยๆ ไม่ลบอะไร
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF009CB4), // ปุ่มสีฟ้าอมเขียว
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'ยกเลิก',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
        title: const Text(
          'รายชื่อรถ',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 🔘 ปุ่มเพิ่มรถเข้า
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddVehiclePage()),
                  ).then((value) {
                    setState(() {}); // รีเฟรชหน้าตอนกลับมาจากหน้าเพิ่มรถ
                  });
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'เพิ่มรถเข้า',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CB8C4), 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 🚙 รายการรถยนต์
            Expanded(
              child: globalVehicles.isEmpty
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.directions_car, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('ยังไม่มีข้อมูลรถในระบบ', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                        Text('กดปุ่ม "เพิ่มรถเข้า" ด้านบนเพื่อเพิ่มรถใหม่', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                      ],
                    )
                  : ListView.builder(
                      itemCount: globalVehicles.length,
                      itemBuilder: (context, index) {
                        return _buildVehicleCard(globalVehicles[index], index);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // 📝 Widget สร้างการ์ดรถ
  Widget _buildVehicleCard(Vehicle vehicle, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🖼️ รูปภาพรถ
          Stack(
            children: [
              vehicle.imagePath != null
                  ? (kIsWeb
                      ? Image.network(vehicle.imagePath!, height: 160, width: double.infinity, fit: BoxFit.cover)
                      : Image.file(File(vehicle.imagePath!), height: 160, width: double.infinity, fit: BoxFit.cover))
                  : Container(
                      height: 160,
                      width: double.infinity,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.directions_car, size: 60, color: Colors.white),
                    ),
              
              // ป้ายสถานะ
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, color: Colors.greenAccent, size: 10),
                      const SizedBox(width: 4),
                      Text(vehicle.status, style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // 📋 ข้อมูล
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vehicle.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF003E75))),
                const SizedBox(height: 4),
                Text(vehicle.plate, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                const SizedBox(height: 12),
                
                // Tags
                Row(
                  children: [
                    _buildTag(vehicle.type),
                    const SizedBox(width: 8),
                    _buildTag('${vehicle.capacity} ที่นั่ง', icon: Icons.people_outline),
                  ],
                ),
                const SizedBox(height: 16),
                
                // ปุ่มแก้ไข / ลบ
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () { 
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditVehiclePage(
                              vehicle: vehicle, 
                              index: index,
                            ),
                          ),
                        ).then((_) {
                          // 🟢 แก้ไขตรงนี้: สั่งให้รีเฟรชหน้าจอเสมอเวลากลับมาจากหน้า Edit/Success
                          setState(() {});
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF009CB4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('แก้ไขรถ', style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        // 🟢 เรียก Popup ยืนยันการลบ
                        _showDeleteConfirmDialog(context, index);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB20000),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('ลบรถ', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ป้าย Tag เล็กๆ
  Widget _buildTag(String text, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: const Color(0xFF0056A0)), const SizedBox(width: 4)],
          Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF0056A0), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}