import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../Booking_vehicle/Vehicle_model.dart'; // 💡 อย่าลืมเช็ก Path ให้ตรงนะครับ

class VehicleBookingStep2Page extends StatefulWidget {
  final VehicleModel? vehicle;

  const VehicleBookingStep2Page({super.key, this.vehicle});

  @override
  State<VehicleBookingStep2Page> createState() =>
      _VehicleBookingStep2PageState();
}

class _VehicleBookingStep2PageState extends State<VehicleBookingStep2Page> {
  @override
  void dispose() {
    destinationController.dispose();
    super.dispose();
  }

  final _formKey = GlobalKey<FormState>();
  final TextEditingController destinationController = TextEditingController();

  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now().add(const Duration(days: 2));
  TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);

  int passengerCount = 4;
  int driveType = 0; // 0 = ขับขี่เอง, 1 = พนักงานขับรถ

  late VehicleModel selectedVehicle;

  @override
  void initState() {
    super.initState();
    // ถ้าไม่มีข้อมูลส่งมา ให้ใช้ข้อมูลจำลองกันแอปพัง
    if (widget.vehicle == null) {
      Navigator.pop(context);
      return;
    }

    selectedVehicle = widget.vehicle!;
  }

  // 🗓️ ฟังก์ชันแปลงวันที่ให้เป็น ปี พ.ศ. (บวก 543)
  String _formatDateThai(DateTime date) {
    int thaiYear = date.year + 543;
    String shortYear = thaiYear.toString().substring(
      2,
    ); // เอาแค่ 2 ตัวท้าย เช่น 69
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/$shortYear";
  }

  // ⏰ ฟังก์ชันแปลงเวลา
  String _formatTime(TimeOfDay time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} น.";
  }

  // 🔥 ฟังก์ชันกดปุ่ม "ต่อไป"
  void _onNextPressed() {
    if (_formKey.currentState!.validate()) {
      // 1. สร้างประวัติการจองก้อนใหม่

      // 2. แอดเข้าประวัติส่วนกลาง

      // 3. แสดงแจ้งเตือนสำเร็จและเด้งกลับหน้าแรก
      // (ถ้าอนาคตมีหน้า Step 3 ยืนยัน ให้เปลี่ยนตรงนี้เป็น Navigator.push ไปหน้า Step 3 แทนครับ)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            'บันทึกข้อมูลสำเร็จ!',
            style: TextStyle(fontFamily: 'Kanit'),
          ),
        ),
      );
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  // 📅 เลือกวันที่
  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? startDate : endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF009CB4)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
          if (endDate.isBefore(startDate)) endDate = startDate;
        } else {
          endDate = picked;
        }
      });
    }
  }

  // ⏰ เลือกเวลา (บังคับใช้ 24 ชั่วโมง และธีมสีม่วง Material 3)
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: startTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.light,
            ),
          ),
          // 🔥 ใช้ MediaQuery ครอบอีกชั้น เพื่อบังคับให้แสดงแบบ 24 ชั่วโมง (เอา AM/PM ออก)
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        startTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA), // สีพื้นหลังเทาอ่อนตามรูป
      appBar: AppBar(
        backgroundColor: const Color(0xFF004381), // สีน้ำเงินเข้ม
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
          // 📍 1. แถบสถานะ (Step Indicator)
          _buildStepIndicator(),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // 🚙 2. การ์ดแสดงรถที่ถูกเลือก
                    _buildSelectedVehicleCard(),
                    const SizedBox(height: 16),

                    // 📝 3. กล่องฟอร์มกรอกข้อมูล
                    Container(
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
                          _buildLabel('จุดหมายปลายทาง', isRequired: true),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: destinationController,
                            style: const TextStyle(
                              fontFamily: 'Kanit',
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'นิคมอุตสาหกรรมอมตะ',
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
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF009CB4),
                                ),
                              ),
                            ),
                            validator: (value) => value!.isEmpty
                                ? 'กรุณากรอกจุดหมายปลายทาง'
                                : null,
                          ),
                          const SizedBox(height: 20),

                          // วันที่ใช้งาน & วันที่คืนรถ
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('วันที่ใช้งาน'),
                                    const SizedBox(height: 8),
                                    _buildClickableField(
                                      text: _formatDateThai(startDate),
                                      leftIcon: Icons.calendar_today_outlined,
                                      rightIcon: Icons.calendar_month,
                                      onTap: () => _selectDate(context, true),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('วันที่คืนรถ'),
                                    const SizedBox(height: 8),
                                    _buildClickableField(
                                      text: _formatDateThai(endDate),
                                      leftIcon: Icons.calendar_today_outlined,
                                      rightIcon: Icons.calendar_month,
                                      onTap: () => _selectDate(context, false),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // เวลาที่ต้องการใช้งาน
                          _buildLabel('เวลาที่ต้องการใช้งาน'),
                          const SizedBox(height: 8),
                          _buildClickableField(
                            text: _formatTime(startTime),
                            rightIcon: Icons.access_time,
                            onTap: () => _selectTime(context),
                          ),
                          const SizedBox(height: 30),

                          // จำนวนผู้โดยสาร
                          Center(
                            child: Column(
                              children: [
                                const Text(
                                  'จำนวนผู้โดยสาร (คน)',
                                  style: TextStyle(
                                    fontFamily: 'Kanit',
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E2841),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildStepperBtn(Icons.remove, () {
                                        if (passengerCount > 1)
                                          setState(() => passengerCount--);
                                      }),
                                      const SizedBox(width: 24),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.people_outline,
                                            color: Colors.grey,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '$passengerCount',
                                            style: const TextStyle(
                                              fontFamily: 'Kanit',
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 24),
                                      _buildStepperBtn(Icons.add, () {
                                        if (passengerCount <
                                            selectedVehicle.capacity) {
                                          setState(() {
                                            passengerCount++;
                                          });
                                        }
                                      }),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),

                          // รูปแบบการขับ
                          _buildLabel('รูปแบบการขับ'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildDriveTypeToggle(
                                title: 'ขับขี่เอง',
                                index: 0,
                              ),
                              const SizedBox(width: 12),
                              _buildDriveTypeToggle(
                                title: 'พนักงานขับรถ',
                                index: 1,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      // 🟢 4. ปุ่ม "ต่อไป" ติดขอบล่าง
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7FA), // กลืนไปกับพื้นหลัง
        ),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _onNextPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF009CB4), // สีฟ้าตามแบบ
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

  // ---------------------------------------------------------
  // 🎨 Widget ย่อยสำหรับตกแต่ง UI
  // ---------------------------------------------------------

  // แถบสถานะด้านบน
  Widget _buildStepIndicator() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 10, bottom: 10),
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
          width: 40,
          height: 40,
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
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'Kanit',
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine() {
    return Container(
      margin: const EdgeInsets.only(top: 27, left: 2, right: 2),
      width: 90,
      height: 2.5,
      color: const Color(0xFFE6EDF5),
    );
  }

  // การ์ดแสดงรถที่เลือก
  Widget _buildSelectedVehicleCard() {
    return Container(
      padding: const EdgeInsets.all(12),
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
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: selectedVehicle.imagePath.isNotEmpty
                ? (selectedVehicle.imagePath.startsWith('assets/')
                      ? Image.asset(
                          selectedVehicle.imagePath,
                          width: 100,
                          height: 70,
                          fit: BoxFit.cover,
                        )
                      : (kIsWeb
                            ? Image.network(
                                selectedVehicle.imagePath,
                                width: 100,
                                height: 70,
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                File(selectedVehicle.imagePath),
                                width: 100,
                                height: 70,
                                fit: BoxFit.cover,
                              )))
                : Container(
                    width: 100,
                    height: 70,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.directions_car, color: Colors.grey),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${selectedVehicle.name} ${selectedVehicle.type}',
                  style: const TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E2841),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  selectedVehicle.plate,
                  style: const TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 14,
                    color: Color(0xFF8F9BB3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ป้ายกำกับฟิลด์
  Widget _buildLabel(String text, {bool isRequired = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
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
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  // กล่องกดเลือกวันที่ / เวลา
  Widget _buildClickableField({
    required String text,
    IconData? leftIcon,
    IconData? rightIcon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            if (leftIcon != null) ...[
              Icon(leftIcon, color: Colors.grey.shade500, size: 18),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4B5563),
                  fontFamily: 'Kanit',
                ),
                textAlign: leftIcon != null ? TextAlign.left : TextAlign.left,
              ),
            ),
            if (rightIcon != null)
              Icon(rightIcon, color: Colors.grey.shade500, size: 18),
          ],
        ),
      ),
    );
  }

  // ปุ่มบวก ลบ ผู้โดยสาร
  Widget _buildStepperBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
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

  // ปุ่ม Toggle รูปแบบการขับ
  Widget _buildDriveTypeToggle({required String title, required int index}) {
    bool isSelected = driveType == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => driveType = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF65A4B9)
                : Colors.white, // สีฟ้าอมเทา
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF65A4B9)
                  : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade600,
              fontSize: 14,
              fontFamily: 'Kanit',
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
