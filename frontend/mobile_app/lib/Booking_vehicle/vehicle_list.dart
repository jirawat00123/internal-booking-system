import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'vehicle_bookingstep2.dart';
import '../../Booking_vehicle/Vehicle_model.dart'; // 💡 เช็ก Path ให้ตรงโฟลเดอร์โปรเจกต์คุณนะครับ

class VehicleBooking extends StatefulWidget {
  const VehicleBooking({super.key});

  @override
  State<VehicleBooking> createState() => _VehicleBookingStep1PageState();
}

class _VehicleBookingStep1PageState extends State<VehicleBooking> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF004381),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'จองรถบริษัท',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Kanit',
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Container(
            width: double.infinity,
            color: const Color(0xFF004381),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: const Text(
              'เลือกรถที่ต้องการ',
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
            child: ValueListenableBuilder<List<VehicleModel>>(
              valueListenable: globalVehicles,
              builder: (context, vehicles, child) {
                // กรองเอารถที่ยัง "ไม่ถูกลบ" (isDeleted == false) มาแสดงเท่านั้น
                final activeVehicles = vehicles
                    .where((v) => !v.isDeleted)
                    .toList();

                if (activeVehicles.isEmpty) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.directions_car,
                        size: 80,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'ไม่มีรถยนต์ในระบบ',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 16,
                          fontFamily: 'Kanit',
                        ),
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: activeVehicles.length,
                  itemBuilder: (context, index) {
                    return _buildVehicleCard(activeVehicles[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
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
          _buildStepItem(step: '1', title: 'เลือกรถ', isActive: true),
          _buildStepLine(),
          _buildStepItem(step: '2', title: 'กรอกข้อมูล', isActive: false),
          _buildStepLine(),
          _buildStepItem(step: '3', title: 'ยืนยัน', isActive: false),
        ],
      ),
    );
  }

  Widget _buildStepItem({
    required String step,
    required String title,
    required bool isActive,
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
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF003865),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'Kanit',
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine() {
    return Container(
      margin: const EdgeInsets.only(top: 17, left: 4, right: 4),
      width: 80,
      height: 2,
      color: const Color(0xFFAAB6C7),
    );
  }

  // 🔴 ฟังก์ชันแสดง Popup แจ้งเตือนเมื่อกดรถที่กำลังใช้งาน
  void _showInUseErrorDialog(BuildContext context) {
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
                  'รถคันนี้ถูกใช้งานอยู่\nโปรดเลือกรถคันที่ว่าง',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003E75),
                    fontFamily: 'Kanit',
                  ),
                  textAlign: TextAlign.center,
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

  // 🖼️ ฟังก์ชันโหลดรูปภาพแบบดัก Error (กันรูปพัง)
  Widget _buildVehicleImage(String path) {
    Widget fallbackIcon = Container(
      height: 160,
      width: double.infinity,
      color: Colors.grey.shade200,
      child: const Icon(Icons.directions_car, size: 60, color: Colors.grey),
    );

    if (path.isEmpty) return fallbackIcon;

    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallbackIcon,
      );
    } else if (kIsWeb) {
      return Image.network(
        path,
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallbackIcon,
      );
    } else {
      return Image.file(
        File(path),
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallbackIcon,
      );
    }
  }

  Widget _buildVehicleCard(VehicleModel vehicle) {
    // 🟢 ตรวจสอบสถานะ และบังคับแสดงผลเป็นภาษาอังกฤษ
    bool isAvailable = [
      'AVAILABLE',
      'Available',
      'ว่างพร้อมใช้งาน',
    ].contains(vehicle.status);

    String displayStatus;
    Color statusColor;
    Color statusBgColor;

    if (isAvailable) {
      displayStatus = 'Available';
      statusColor = const Color(0xFF2EC4B6);
      statusBgColor = const Color(0xFFE6F8F5);
    } else {
      displayStatus = 'In Use';
      statusColor = const Color(0xFFF05252);
      statusBgColor = const Color(0xFFFDE8E8);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🖼️ เรียกใช้ฟังก์ชันรูปภาพแบบมีกันพัง
            _buildVehicleImage(vehicle.imagePath),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          vehicle.name.isNotEmpty
                              ? vehicle.name
                              : 'ไม่ระบุรุ่น',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                            fontFamily: 'Kanit',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: statusColor, size: 8),
                            const SizedBox(width: 6),
                            Text(
                              displayStatus,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Kanit',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    vehicle.plate.isNotEmpty ? vehicle.plate : 'ไม่ระบุทะเบียน',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      fontFamily: 'Kanit',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          vehicle.type.isNotEmpty ? vehicle.type : 'Sedan',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1D4ED8),
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Kanit',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.people_alt_outlined,
                            size: 16,
                            color: Color(0xFF1D4ED8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${vehicle.capacity} ที่นั่ง',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1D4ED8),
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Kanit',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      // 💡 เปลี่ยนตรงนี้: ให้ปุ่มกดได้เสมอ แต่แยกเงื่อนไขการทำงาน
                      onPressed: () {
                        if (isAvailable) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  VehicleBookingStep2Page(vehicle: vehicle),
                            ),
                          );
                        } else {
                          // ถ้ารถ In Use ให้โชว์ Error Popup
                          _showInUseErrorDialog(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAvailable
                            ? const Color(0xFF009CB4)
                            : Colors.grey.shade300,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'เลือกรถคันนี้',
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
          ],
        ),
      ),
    );
  }
}
