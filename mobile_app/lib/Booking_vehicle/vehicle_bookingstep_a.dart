import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../Booking_vehicle/Vehicle_model.dart'; 
import 'vehicle_bookingstep_b.dart'; 

class VehicleBookingStep2Page extends StatefulWidget {
  final VehicleModel? vehicle; 

  const VehicleBookingStep2Page({super.key, this.vehicle});

  @override
  State<VehicleBookingStep2Page> createState() => _VehicleBookingStep2PageState();
}

class _VehicleBookingStep2PageState extends State<VehicleBookingStep2Page> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController destinationController = TextEditingController();
  
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now().add(const Duration(days: 2));
  TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
  
  int passengerCount = 4;

  late VehicleModel selectedVehicle;

  @override
  void initState() {
    super.initState();
    selectedVehicle = widget.vehicle ?? VehicleModel(
      id: 0, vehicleName: 'ไม่ระบุรุ่น', plateNumber: '-', brand: '-', model: '-', seats: 0, status: 'AVAILABLE', uploadUrl: ''
    );
  }

  String _formatDateThai(DateTime date) {
    int thaiYear = date.year + 543;
    String shortYear = thaiYear.toString().substring(2); 
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/$shortYear";
  }

  String _formatTime(TimeOfDay time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  void _onNextPressed() {
    if (_formKey.currentState!.validate()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VehicleBookingFormBPage(
            vehicle: selectedVehicle,
            destination: destinationController.text,
            startDate: _formatDateThai(startDate),
            endDate: _formatDateThai(endDate),
            timeRange: "${_formatTime(startTime)} น.", 
            passengerCount: passengerCount,
            driverType: 'ขับขี่เอง', 
            // 💡 ส่งค่า "ขับขี่เอง" ไปหน้าต่อไปแบบเงียบๆ ไม่ต้องมีปุ่มให้กดแล้ว
          ), 
        ),
      );
    }
  }

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

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: startTime,
      initialEntryMode: TimePickerEntryMode.inputOnly,
      builder: (context, child) {
        return Theme(
          data: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF009CB4), brightness: Brightness.light),
          ),
          child: MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
        );
      },
    );
    
    if (picked != null) {
      setState(() { startTime = picked; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA), 
      appBar: AppBar(
        backgroundColor: const Color(0xFF004381), 
        title: const Text('จองรถบริษัท', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
        centerTitle: true, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildSelectedVehicleCard(),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('จุดหมายปลายทาง', isRequired: true),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: destinationController,
                            style: const TextStyle(fontFamily: 'Kanit', fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'นิคมอุตสาหกรรมอมตะ', hintStyle: TextStyle(fontFamily: 'Kanit', color: Colors.grey.shade400, fontSize: 14), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF009CB4))),
                            ),
                            validator: (value) => value!.isEmpty ? 'กรุณากรอกจุดหมายปลายทาง' : null,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('วันที่ใช้งาน'), const SizedBox(height: 8),
                                    _buildClickableField(text: _formatDateThai(startDate), leftIcon: Icons.calendar_today_outlined, rightIcon: Icons.calendar_month, onTap: () => _selectDate(context, true)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('วันที่คืนรถ'), const SizedBox(height: 8),
                                    _buildClickableField(text: _formatDateThai(endDate), leftIcon: Icons.calendar_today_outlined, rightIcon: Icons.calendar_month, onTap: () => _selectDate(context, false)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildLabel('เวลาที่ต้องการใช้งาน'), const SizedBox(height: 8),
                          _buildClickableField(text: "${_formatTime(startTime)} น.", rightIcon: Icons.access_time, onTap: () => _selectTime(context)),
                          const SizedBox(height: 30),
                          
                          // ลบส่วน "รูปแบบการขับ" ออก เหลือแค่จำนวนผู้โดยสารเป็นอันจบฟอร์ม
                          Center(
                            child: Column(
                              children: [
                                const Text('จำนวนผู้โดยสาร (คน)', style: TextStyle(fontFamily: 'Kanit', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E2841))),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildStepperBtn(Icons.remove, () { if (passengerCount > 1) setState(() => passengerCount--); }),
                                      const SizedBox(width: 24),
                                      Row(children: [const Icon(Icons.people_outline, color: Colors.grey, size: 20), const SizedBox(width: 8), Text('$passengerCount', style: const TextStyle(fontFamily: 'Kanit', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87))]),
                                      const SizedBox(width: 24),
                                      _buildStepperBtn(Icons.add, () { setState(() => passengerCount++); }),
                                    ],
                                  ),
                                ),
                              ],
                            ),
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Color(0xFFF4F7FA)),
        child: SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton(
            onPressed: _onNextPressed,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF009CB4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
            child: const Text('ต่อไป', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      color: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepItem(step: '1', title: 'เลือกรถ', isActive: true, isDone: true), _buildStepLine(isActive: true),
          _buildStepItem(step: '2', title: 'กรอกข้อมูล', isActive: true, isDone: false), _buildStepLine(isActive: false),
          _buildStepItem(step: '3', title: 'ยืนยัน', isActive: false, isDone: false),
        ],
      ),
    );
  }

  Widget _buildStepItem({required String step, required String title, required bool isActive, required bool isDone}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 70, height: 36, decoration: BoxDecoration(color: isActive ? const Color(0xFF009CB4) : const Color(0xFFE6EDF5), shape: BoxShape.circle), alignment: Alignment.center, child: Text(step, style: TextStyle(color: isActive ? Colors.white : const Color(0xFFAAB6C7), fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Kanit'))),
        const SizedBox(height: 8), Text(title, style: TextStyle(color: isActive ? const Color(0xFF004381) : const Color(0xFFAAB6C7), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
      ],
    );
  }

  Widget _buildStepLine({required bool isActive}) {
    return Container(margin: const EdgeInsets.only(top: 17, left: 4, right: 4), width: 80, height: 2, color: isActive ? const Color(0xFF009CB4) : const Color(0xFFE6EDF5));
  }

  Widget _buildSelectedVehicleCard() {
    String imagePath = selectedVehicle.uploadUrl ?? '';
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: imagePath.isNotEmpty
                ? (imagePath.startsWith('/uploads')
                    ? Image.network('http://localhost:3001$imagePath', width: 100, height: 70, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(width: 100, height: 70, color: Colors.grey.shade200, child: const Icon(Icons.directions_car, color: Colors.grey)))
                    : imagePath.startsWith('assets/')
                        ? Image.asset(imagePath, width: 100, height: 70, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(width: 100, height: 70, color: Colors.grey.shade200, child: const Icon(Icons.directions_car, color: Colors.grey)))
                        : (kIsWeb 
                            ? Image.network(imagePath, width: 100, height: 70, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(width: 100, height: 70, color: Colors.grey.shade200, child: const Icon(Icons.directions_car, color: Colors.grey)))
                            : Image.file(File(imagePath), width: 100, height: 70, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(width: 100, height: 70, color: Colors.grey.shade200, child: const Icon(Icons.directions_car, color: Colors.grey)))))
                : Container(width: 100, height: 70, color: Colors.grey.shade200, child: const Icon(Icons.directions_car, color: Colors.grey)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${selectedVehicle.vehicleName} ${selectedVehicle.model}'.trim(), style: const TextStyle(fontFamily: 'Kanit', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E2841)), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(selectedVehicle.plateNumber, style: const TextStyle(fontFamily: 'Kanit', fontSize: 14, color: Color(0xFF8F9BB3))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E2841), fontFamily: 'Kanit')), if (isRequired) const Text(' *', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold))]);
  }

  Widget _buildClickableField({required String text, IconData? leftIcon, IconData? rightIcon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
        child: Row(children: [if (leftIcon != null) ...[Icon(leftIcon, color: Colors.grey.shade500, size: 18), const SizedBox(width: 8)], Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563), fontFamily: 'Kanit'))), if (rightIcon != null) Icon(rightIcon, color: Colors.grey.shade500, size: 18)]),
      ),
    );
  }

  Widget _buildStepperBtn(IconData icon, VoidCallback onTap) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), shape: BoxShape.circle), child: Icon(icon, size: 16, color: const Color(0xFF75BBE1))));
  }
}