import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../Booking_vehicle/Vehicle_model.dart';
import 'vehicle_bookingstep_b.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth_service.dart';

class VehicleBookingStep2Page extends StatefulWidget {
  final VehicleModel? vehicle;

  const VehicleBookingStep2Page({super.key, this.vehicle});

  @override
  State<VehicleBookingStep2Page> createState() =>
      _VehicleBookingStep2PageState();
}

class _VehicleBookingStep2PageState extends State<VehicleBookingStep2Page> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController destinationController = TextEditingController();

  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now().add(const Duration(days: 2));
  TimeOfDay useTime = TimeOfDay.now();
  TimeOfDay returnTime = TimeOfDay.now();

  int passengerCount = 4;
  final List<TextEditingController> passengerControllers = [];
  String _driverType = 'ขับขี่เอง'; // เพิ่มตัวแปรเก็บประเภทผู้ขับขี่

  late VehicleModel selectedVehicle;

  List<DateTimeRange> bookedDateRanges = [];

  List<String> _allEmployeeNames = [];
  List<String> _driverEmployeeNames = [];
  Map<String, int?> _employeeIdMap = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    startDate = DateTime(now.year, now.month, now.day);
    endDate = startDate.add(const Duration(days: 2));

    selectedVehicle =
        widget.vehicle ??
        VehicleModel(
          id: 0,
          vehicleName: 'ไม่ระบุรุ่น',
          plateNumber: '-',
          brand: '-',
          model: '-',
          seats: 0,
          status: 'AVAILABLE',
          uploadUrl: '',
        );

    _updatePassengerControllers();
    _fetchBookedDates();
    _fetchEmployees();
  }

  @override
  void dispose() {
    destinationController.dispose();
    for (var controller in passengerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updatePassengerControllers() {
    while (passengerControllers.length < passengerCount) {
      passengerControllers.add(TextEditingController());
    }
    while (passengerControllers.length > passengerCount) {
      passengerControllers.removeLast().dispose();
    }
  }

  // ==========================================
  // 📥 ฟังก์ชันดึงรายชื่อพนักงานทั้งหมดล่วงหน้า (ตามต้นแบบ user_page.dart)
  // ==========================================
  Future<void> _fetchEmployees() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token =
          prefs.getString('token') ?? prefs.getString('accessToken');

      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/api/users'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty && token != 'undefined')
            'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final List users = body['data'];
          final List<String> names = [];
          final List<String> driverNames = [];
          final Map<String, int?> empIdMap = {};

          for (var u in users) {
            final emp = u['employee'];
            String name = '';
            int? empId = emp != null ? emp['id'] : null;

            if (emp != null &&
                emp['fullName'] != null &&
                emp['fullName'].toString().isNotEmpty) {
              name = emp['fullName'].toString();
            } else if (emp != null &&
                (emp['firstName'] != null || emp['lastName'] != null)) {
              name = '${emp['firstName'] ?? ''} ${emp['lastName'] ?? ''}'
                  .trim();
            } else if (u['fullName'] != null &&
                u['fullName'].toString().isNotEmpty) {
              name = u['fullName'].toString();
            } else if (u['name'] != null && u['name'].toString().isNotEmpty) {
              name = u['name'].toString();
            }

            if (name.isNotEmpty) {
              names.add(name);
              if (empId != null) {
                empIdMap[name] = empId;
              }
              bool isDriver = false;
              if (emp != null && emp['isDriver'] == true) {
                isDriver = true;
              } else if (u['isDriver'] == true) {
                isDriver = true;
              }
              if (isDriver) {
                driverNames.add(name);
              }
            }
          }

          if (mounted) {
            setState(() {
              _allEmployeeNames = names;
              _driverEmployeeNames = driverNames;
              _employeeIdMap = empIdMap;
            });
          }
        }
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการดึงรายชื่อพนักงาน: $e');
    }
  }

  // ==========================================
  // 📥 ฟังก์ชันดึงประวัติการจองเฉพาะคันนี้ เพื่อเอามาล็อควัน
  // ==========================================
  Future<void> _fetchBookedDates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/api/vehicle-bookings'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty && token != 'undefined')
            'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final bData = jsonDecode(response.body);
        List<dynamic> bookingsData = bData['data'] ?? bData['bookings'] ?? [];

        List<DateTimeRange> ranges = [];
        for (var booking in bookingsData) {
          String bStatus = booking['status'] ?? 'Pending';

          // กรองเอาเฉพาะ "รถคันนี้" และ สถานะที่ "ยังมีผล"
          if (booking['vehicleId'] == selectedVehicle.id &&
              bStatus != 'Cancelled' &&
              bStatus != 'Completed' &&
              bStatus != 'ยกเลิกแล้ว' &&
              bStatus != 'เสร็จสิ้น') {
            DateTime start = DateTime.parse(booking['startDatetime']).toLocal();
            DateTime end = DateTime.parse(booking['endDatetime']).toLocal();
            ranges.add(DateTimeRange(start: start, end: end));
          }
        }

        if (mounted) {
          setState(() {
            bookedDateRanges = ranges;
            // ถ้าระบบเปิดมาเจอกลางวันที่โดนจอง ให้ขยับวันเริ่มต้นไปหาวันที่ว่างอัตโนมัติ
            startDate = _getFirstAvailableDate(DateTime.now());
            if (endDate.isBefore(startDate) || !_isSelectable(endDate)) {
              endDate = _getFirstAvailableDate(startDate);
            }
          });
        }
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการดึงคิวจอง: $e');
    }
  }

  // ==========================================
  // 🔒 ฟังก์ชันเช็กว่า วันนี้โดนจองเต็มวันหรือไม่?
  // ==========================================
  bool _isSelectable(DateTime day) {
    DateTime dayStart = DateTime(day.year, day.month, day.day, 0, 0, 0);
    DateTime dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);

    for (var range in bookedDateRanges) {
      // บล็อกวันเฉพาะเมื่อมีรายการจองที่ครอบคลุมทั้งวัน (ตั้งแต่ก่อน/เท่ากับ 00:00:00 ถึง หลัง/เท่ากับ 23:59:59)
      if ((range.start.isBefore(dayStart) ||
              range.start.isAtSameMomentAs(dayStart)) &&
          (range.end.isAfter(dayEnd) || range.end.isAtSameMomentAs(dayEnd))) {
        return false;
      }
    }
    return true;
  }

  // ฟังก์ชันเลื่อนหาวันว่างวันแรก (กรณีวันที่ปัจจุบันโดนจอง)
  DateTime _getFirstAvailableDate(DateTime startFrom) {
    DateTime check = DateTime(startFrom.year, startFrom.month, startFrom.day);
    while (!_isSelectable(check)) {
      check = check.add(
        const Duration(days: 1),
      ); // เลื่อนไปทีละวันจนกว่าจะเจอวันว่าง
    }
    return check;
  }

  String _formatDateThai(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  // 👈 เพิ่มฟังก์ชันจัดการเวลาที่ต้องการใช้งาน
  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: useTime,
      initialEntryMode: TimePickerEntryMode.input,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF009CB4)),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
      },
    );
    if (!mounted) return;
    if (picked != null) {
      setState(() {
        useTime = picked;
      });
    }
  }

  Future<void> _selectReturnTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: returnTime,
      initialEntryMode: TimePickerEntryMode.input,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF009CB4)),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
      },
    );
    if (!mounted) return;
    if (picked != null) {
      setState(() {
        returnTime = picked;
      });
    }
  }

  void _onNextPressed() {
    if (_formKey.currentState!.validate()) {
      // 1. รวมวันและเวลาที่ผู้ใช้เลือกจริง
      final DateTime startDateTime = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
        useTime.hour,
        useTime.minute,
      );
      final DateTime endDateTime = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        returnTime.hour,
        returnTime.minute,
      );

      // 2. ตรวจสอบว่าเวลาคืนรถต้องอยู่หลังเวลาเริ่มใช้งาน
      if (endDateTime.isBefore(startDateTime) ||
          endDateTime.isAtSameMomentAs(startDateTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('วันและเวลาคืนรถ ต้องอยู่หลังวันและเวลาเริ่มใช้งาน'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 3. ตรวจสอบการชนกันของช่วงเวลา (Overlap Check)
      for (var range in bookedDateRanges) {
        if (startDateTime.isBefore(range.end) &&
            endDateTime.isAfter(range.start)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'ช่วงเวลาที่คุณเลือกมีการใช้งานรถคันนี้อยู่แล้ว กรุณาเปลี่ยนช่วงเวลา',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      // 🟢 กรองเฉพาะชื่อที่ไม่ว่างเปล่าก่อนส่งไปยังหน้าต่อไป
      final List<String> passengerNames = passengerControllers
          .map((controller) => controller.text.trim())
          .where((name) => name.isNotEmpty)
          .toList();

      int? driverEmployeeId;
      if (_driverType == 'ขับขี่เอง' && passengerNames.isNotEmpty) {
        driverEmployeeId = _employeeIdMap[passengerNames[0]];
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VehicleBookingFormBPage(
            vehicle: selectedVehicle,
            destination: destinationController.text,
            startDate: startDate,
            endDate: endDate,
            timeRange: _formatTime(useTime),
            returnTime: _formatTime(returnTime),
            passengerCount:
                passengerNames.length, // ปรับให้ตรงกับจำนวนจริงที่กรอก
            passengerNames: passengerNames,
            driverType: _driverType, // เปลี่ยนมาส่งค่าจากตัวแปร State ที่เลือก
            driverEmployeeId: driverEmployeeId,
          ),
        ),
      );
    }
  }

  // 💡 พระเอกอยู่ตรงนี้: ปฏิทินที่ล็อควันที่ไม่ว่างได้
  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime initial = isStart ? startDate : endDate;

    if (!_isSelectable(initial)) {
      initial = _getFirstAvailableDate(today);
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 2)),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      selectableDayPredicate: _isSelectable,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF009CB4)),
          ),
          child: child!,
        );
      },
    );

    if (!mounted) return;
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

  List<String> _searchEmployees(
    String query, {
    bool driverOnly = false,
    int? currentIndex,
  }) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return [];

    final Set<int> selectedEmpIds = {};
    final Set<String> selectedNames = {};

    for (int i = 0; i < passengerControllers.length; i++) {
      if (currentIndex != null && i == currentIndex) continue;
      final text = passengerControllers[i].text.trim();
      if (text.isNotEmpty) {
        final empId = _employeeIdMap[text];
        if (empId != null) {
          selectedEmpIds.add(empId);
        }
        selectedNames.add(text.toLowerCase());
      }
    }

    final sourceList = driverOnly ? _driverEmployeeNames : _allEmployeeNames;
    return sourceList.where((name) {
      if (!name.toLowerCase().contains(cleanQuery)) return false;
      final empId = _employeeIdMap[name];
      if (empId != null) {
        return !selectedEmpIds.contains(empId);
      }
      return !selectedNames.contains(name.toLowerCase());
    }).toList();
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
                child: Column(
                  children: [
                    _buildSelectedVehicleCard(),
                    const SizedBox(height: 16),
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
                                      leftIcon: Icons.calendar_today_rounded,
                                      rightIcon:
                                          Icons.keyboard_arrow_down_rounded,
                                      onTap: () => _selectDate(context, true),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('วันที่สิ้นสุด'),
                                    const SizedBox(height: 8),
                                    _buildClickableField(
                                      text: _formatDateThai(endDate),
                                      leftIcon: Icons.calendar_today_rounded,
                                      rightIcon:
                                          Icons.keyboard_arrow_down_rounded,
                                      onTap: () => _selectDate(context, false),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('เวลาที่ต้องการใช้งาน'),
                                    const SizedBox(height: 8),
                                    _buildClickableField(
                                      text: '${_formatTime(useTime)} น.',
                                      leftIcon: Icons.access_time_rounded,
                                      rightIcon:
                                          Icons.keyboard_arrow_down_rounded,
                                      onTap: () => _selectTime(context),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('เวลาคืน'),
                                    const SizedBox(height: 8),
                                    _buildClickableField(
                                      text: '${_formatTime(returnTime)} น.',
                                      leftIcon: Icons.access_time_rounded,
                                      rightIcon:
                                          Icons.keyboard_arrow_down_rounded,
                                      onTap: () => _selectReturnTime(context),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),

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
                                        if (passengerCount > 1) {
                                          setState(() {
                                            passengerCount--;
                                            _updatePassengerControllers();
                                          });
                                        }
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
                                        setState(() {
                                          passengerCount++;
                                          _updatePassengerControllers();
                                        });
                                      }),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildLabel('ประเภทผู้ขับขี่', isRequired: true),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: RadioListTile<String>(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                    'ขับขี่เอง',
                                    style: TextStyle(
                                      fontFamily: 'Kanit',
                                      fontSize: 14,
                                    ),
                                  ),
                                  value: 'ขับขี่เอง',
                                  groupValue: _driverType,
                                  activeColor: const Color(0xFF009CB4),
                                  onChanged: (value) {
                                    setState(() {
                                      _driverType = value!;
                                    });
                                  },
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<String>(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                    'บริษัท',
                                    style: TextStyle(
                                      fontFamily: 'Kanit',
                                      fontSize: 14,
                                    ),
                                  ),
                                  value: 'บริษัท',
                                  groupValue: _driverType,
                                  activeColor: const Color(0xFF009CB4),
                                  onChanged: (value) {
                                    setState(() {
                                      _driverType = value!;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildPassengerFields(),
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
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(top: 17, left: 4, right: 4),
        height: 2,
        color: isActive ? const Color(0xFF009CB4) : const Color(0xFFE6EDF5),
      ),
    );
  }

  Widget _buildSelectedVehicleCard() {
    String imagePath = selectedVehicle.uploadUrl ?? '';
    String fullImageUrl = AuthService.getImageUrl(imagePath);

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
            child: fullImageUrl.isNotEmpty
                ? Image.network(
                    fullImageUrl,
                    width: 100,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                      width: 100,
                      height: 70,
                      color: Colors.grey.shade200,
                      child: const Icon(
                        Icons.directions_car,
                        color: Colors.grey,
                      ),
                    ),
                  )
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
                  '${selectedVehicle.vehicleName} ${selectedVehicle.model}'
                      .trim(),
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
                  selectedVehicle.plateNumber,
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

  Widget _buildClickableField({
    required String text,
    IconData? leftIcon,
    IconData? rightIcon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        highlightColor: const Color(0xFF009CB4).withOpacity(0.05),
        splashColor: const Color(0xFF009CB4).withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            children: [
              if (leftIcon != null) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF009CB4).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    leftIcon,
                    size: 18,
                    color: const Color(0xFF009CB4),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                    fontFamily: 'Kanit',
                  ),
                ),
              ),
              if (rightIcon != null)
                Icon(rightIcon, size: 20, color: const Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPassengerFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('รายชื่อผู้โดยสาร', isRequired: true),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: passengerCount,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (_driverType == 'ขับขี่เอง' && index == 0)
                        ? 'ผู้ขับขี่'
                        : 'ผู้โดยสาร ${index + 1}',
                    style: TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Autocomplete<String>(
                    key: ValueKey('passenger_$index'),
                    initialValue: TextEditingValue(
                      text: passengerControllers[index].text,
                    ),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.trim().isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return _searchEmployees(
                        textEditingValue.text,
                        driverOnly: false,
                        currentIndex: index,
                      );
                    },
                    onSelected: (String selection) {
                      passengerControllers[index].text = selection;
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            style: const TextStyle(
                              fontFamily: 'Kanit',
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'ชื่อ-นามสกุล',
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
                            onChanged: (value) {
                              passengerControllers[index].text = value;
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return (_driverType == 'ขับขี่เอง' &&
                                        index == 0)
                                    ? 'กรุณากรอกชื่อ-นามสกุลผู้ขับขี่'
                                    : 'กรุณากรอกชื่อ-นามสกุลผู้โดยสาร ${index + 1}';
                              }
                              final trimmedValue = value.trim();
                              final currentEmpId = _employeeIdMap[trimmedValue];
                              for (
                                int i = 0;
                                i < passengerControllers.length;
                                i++
                              ) {
                                if (i == index) continue;
                                final otherText = passengerControllers[i].text
                                    .trim();
                                if (otherText.isEmpty) continue;

                                final otherEmpId = _employeeIdMap[otherText];
                                if (currentEmpId != null &&
                                    otherEmpId != null) {
                                  if (currentEmpId == otherEmpId) {
                                    return 'ไม่สามารถเลือกผู้โดยสารซ้ำกันได้';
                                  }
                                } else if (trimmedValue.toLowerCase() ==
                                    otherText.toLowerCase()) {
                                  return 'ไม่สามารถเลือกผู้โดยสารซ้ำกันได้';
                                }
                              }
                              return null;
                            },
                          );
                        },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: MediaQuery.of(context).size.width - 80,
                            constraints: const BoxConstraints(maxHeight: 200),
                            color: Colors.white,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder:
                                  (BuildContext context, int optIndex) {
                                    final option = options.elementAt(optIndex);
                                    return ListTile(
                                      title: Text(
                                        option,
                                        style: const TextStyle(
                                          fontFamily: 'Kanit',
                                          fontSize: 14,
                                        ),
                                      ),
                                      onTap: () {
                                        onSelected(option);
                                      },
                                    );
                                  },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

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
}
