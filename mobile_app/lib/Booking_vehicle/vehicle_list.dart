import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import 'vehicle_bookingstep_a.dart';
import '../../Booking_vehicle/Vehicle_model.dart';

class VehicleBooking extends StatefulWidget {
  final bool isGuest;

  const VehicleBooking({super.key, this.isGuest = false});

  @override
  State<VehicleBooking> createState() => _VehicleBookingStep1PageState();
}

class _VehicleBookingStep1PageState extends State<VehicleBooking> {
  bool isLoading = true;

  int _selectedFilterIndex = 0;
  // 🟢 เพิ่มตัวกรอง รถกระบะ
  final List<String> _filterOptions = [
    'ทั้งหมด',
    'ว่างเท่านั้น',
    'รถตู้',
    'รถกระบะ',
  ];

  @override
  void initState() {
    super.initState();
    _fetchVehicles();
  }

  Future<void> _fetchVehicles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');

      final headers = {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final vehicleFuture = http.get(
        Uri.parse('http://192.168.88.25:3001/api/vehicles'),
        headers: headers,
      );
      final bookingFuture = http.get(
        Uri.parse('http://192.168.88.25:3001/api/vehicle-bookings'),
        headers: headers,
      );

      final responses = await Future.wait([vehicleFuture, bookingFuture]);

      if (responses[0].statusCode == 200) {
        final decodedData = jsonDecode(responses[0].body);
        List<dynamic> vehiclesData = [];

        if (decodedData is List) {
          vehiclesData = decodedData;
        } else if (decodedData is Map) {
          vehiclesData = decodedData['data'] ?? [];
        }

        List<VehicleModel> fetchedList = vehiclesData
            .map((json) => VehicleModel.fromJson(json))
            .toList();

        if (responses[1].statusCode == 200) {
          final bData = jsonDecode(responses[1].body);
          List<dynamic> bookingsData = [];

          if (bData is List) {
            bookingsData = bData;
          } else if (bData is Map) {
            bookingsData = bData['data'] ?? bData['bookings'] ?? [];
          }

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          for (int i = 0; i < fetchedList.length; i++) {
            var vehicle = fetchedList[i];

            if ((vehicle.status ?? '').toString().toUpperCase() ==
                'MAINTENANCE') {
              continue;
            }

            var vBookings = bookingsData.where((b) {
              int bVid =
                  int.tryParse(
                    b['vehicleId']?.toString() ??
                        b['vehicle']?['id']?.toString() ??
                        '0',
                  ) ??
                  0;
              return bVid == vehicle.id;
            }).toList();

            if (vBookings.isNotEmpty) {
              bool isInUse = vBookings.any((b) {
                String s = (b['status'] ?? '')
                    .toString()
                    .toLowerCase()
                    .replaceAll(' ', '_')
                    .replaceAll('-', '_');
                return s == 'in_use' || s == 'approved' || s == 'กำลังใช้งาน';
              });

              if (isInUse) {
                fetchedList[i] = vehicle.copyWith(status: 'IN_USE');
                continue;
              }

              bool isReservedToday = vBookings.any((b) {
                String s = (b['status'] ?? '')
                    .toString()
                    .toLowerCase()
                    .replaceAll(' ', '_')
                    .replaceAll('-', '_');
                if (s == 'cancelled' ||
                    s == 'completed' ||
                    s == 'ยกเลิกแล้ว' ||
                    s == 'เสร็จสิ้น')
                  return false;

                try {
                  String startStr =
                      b['startDatetime']?.toString() ??
                      b['startDate']?.toString() ??
                      '';
                  String endStr =
                      b['endDatetime']?.toString() ??
                      b['endDate']?.toString() ??
                      '';
                  if (startStr.isEmpty || endStr.isEmpty) return false;

                  DateTime start = DateTime.parse(startStr).toLocal();
                  DateTime end = DateTime.parse(endStr).toLocal();
                  DateTime startDate = DateTime(
                    start.year,
                    start.month,
                    start.day,
                  );
                  DateTime endDate = DateTime(end.year, end.month, end.day);

                  if ((today.isAtSameMomentAs(startDate) ||
                          today.isAfter(startDate)) &&
                      (today.isAtSameMomentAs(endDate) ||
                          today.isBefore(endDate))) {
                    return true;
                  }
                } catch (e) {
                  return false;
                }
                return false;
              });

              if (isReservedToday) {
                fetchedList[i] = vehicle.copyWith(status: 'RESERVED');
              }
            }
          }
        }

        globalVehicles.value = fetchedList;
      } else {
        print('ดึงข้อมูลล้มเหลว Code: ${responses[0].statusCode}');
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการดึงข้อมูล: $e');
    } finally {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() => isLoading = false);
        });
      }
    }
  }

  Widget _buildFilterBar() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_filterOptions.length, (index) {
            bool isSelected = _selectedFilterIndex == index;
            return Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: ChoiceChip(
                  label: Text(
                    _filterOptions[index],
                    style: TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF003865),
                    ),
                  ),
                  selected: isSelected,
                  showCheckmark: false,
                  selectedColor: const Color(0xFF009CB4),
                  backgroundColor: Colors.white,
                  elevation: isSelected ? 4 : 1,
                  shadowColor: Colors.black.withOpacity(0.1),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF009CB4)
                        : Colors.grey.shade300,
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  onSelected: (bool selected) {
                    setState(() {
                      _selectedFilterIndex = index;
                    });
                  },
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

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

          if (!isLoading) _buildFilterBar(),

          Expanded(
            child: isLoading
                ? ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 4,
                    itemBuilder: (context, index) => _buildShimmerCard(),
                  )
                : ValueListenableBuilder<List<VehicleModel>>(
                    valueListenable: globalVehicles,
                    builder: (context, vehicles, child) {
                      final activeVehicles = vehicles.where((v) {
                        if (v.isDeleted == true) return false;

                        if (_selectedFilterIndex == 1) {
                          // ว่างเท่านั้น
                          String rawStatus = (v.status ?? '')
                              .toString()
                              .trim()
                              .toUpperCase();
                          bool isAvailable =
                              (rawStatus == 'AVAILABLE' ||
                              rawStatus == 'ว่างพร้อมใช้งาน');
                          if (!isAvailable) return false;
                        } else if (_selectedFilterIndex == 2) {
                          // รถตู้
                          String vName = (v.vehicleName ?? '').toLowerCase();
                          bool isVan =
                              v.seats >= 7 ||
                              vName.contains('ตู้') ||
                              vName.contains('van') ||
                              vName.contains('commuter');
                          if (!isVan) return false;
                        }
                        // 🟢 เพิ่มลอจิกกรอง รถกระบะ
                        else if (_selectedFilterIndex == 3) {
                          String vName = (v.vehicleName ?? '').toLowerCase();
                          bool isPickup =
                              vName.contains('กระบะ') ||
                              vName.contains('pickup') ||
                              vName.contains('revo') ||
                              vName.contains('vigo') ||
                              vName.contains('d-max') ||
                              vName.contains('triton') ||
                              vName.contains('ranger');
                          if (!isPickup) return false;
                        }

                        return true;
                      }).toList();

                      if (activeVehicles.isEmpty) {
                        return ShowUp(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 80,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'ไม่พบรถที่ตรงกับเงื่อนไข',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 16,
                                  fontFamily: 'Kanit',
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: activeVehicles.length,
                        itemBuilder: (context, index) {
                          return ShowUp(
                            delay: index * 100,
                            child: _buildVehicleCard(activeVehicles[index]),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade50,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 160,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(width: 150, height: 20, color: Colors.white),
                      Container(
                        width: 80,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(width: 100, height: 16, color: Colors.white),
                  const SizedBox(height: 16),
                  Container(width: 60, height: 16, color: Colors.white),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
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

  Widget _buildVehicleImage(String path) {
    Widget fallbackIcon = Container(
      height: 160,
      width: double.infinity,
      color: Colors.grey.shade200,
      child: const Icon(Icons.directions_car, size: 60, color: Colors.grey),
    );

    if (path.isEmpty) return fallbackIcon;

    if (path.startsWith('/uploads')) {
      return Image.network(
        'http://192.168.88.25:3001$path',
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => fallbackIcon,
      );
    } else if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => fallbackIcon,
      );
    } else if (kIsWeb) {
      return Image.network(
        path,
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => fallbackIcon,
      );
    } else {
      return Image.file(
        File(path),
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => fallbackIcon,
      );
    }
  }

  Widget _buildVehicleCard(VehicleModel vehicle) {
    String rawStatus = (vehicle.status ?? '').toString().trim().toUpperCase();
    bool isAvailable = false;

    String displayStatus = 'Available';
    Color statusColor = const Color(0xFF10B981);
    Color statusBgColor = const Color(0xFFD1FAE5);
    String buttonText = 'เลือกรถคันนี้';

    if (rawStatus == 'MAINTENANCE' || rawStatus == 'ส่งซ่อม') {
      displayStatus = 'Maintenance';
      statusColor = const Color(0xFFE65100);
      statusBgColor = const Color(0xFFFFF3E0);
      buttonText = 'รถส่งซ่อม';
    } else if (rawStatus == 'IN_USE' ||
        rawStatus == 'IN USE' ||
        rawStatus == 'IN-USE' ||
        rawStatus == 'กำลังใช้งาน') {
      displayStatus = 'In Use';
      statusColor = const Color(0xFFEF4444);
      statusBgColor = const Color(0xFFFEE2E2);
      buttonText = 'รถกำลังใช้งาน';
    } else if (rawStatus == 'RESERVED' ||
        rawStatus == 'RESERVE' ||
        rawStatus == 'PENDING' ||
        rawStatus == 'จองแล้ว') {
      displayStatus = 'Reserve';
      statusColor = const Color(0xFFF59E0B);
      statusBgColor = const Color(0xFFFEF3C7);
      buttonText = 'ถูกจองแล้ว';
    } else {
      isAvailable = true;
      displayStatus = 'Available';
      statusColor = const Color(0xFF10B981);
      statusBgColor = const Color(0xFFD1FAE5);
      buttonText = 'เลือกรถคันนี้';
    }

    String vName = vehicle.vehicleName?.toString() ?? '';
    String vPlate = vehicle.plateNumber?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
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
            Hero(
              tag: 'vehicle_img_${vehicle.id}',
              child: _buildVehicleImage(vehicle.uploadUrl ?? ''),
            ),
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
                          vName.isNotEmpty ? vName : 'ไม่ระบุรุ่น',
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
                    vPlate.isNotEmpty ? vPlate : 'ไม่ระบุทะเบียน',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      fontFamily: 'Kanit',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.people_alt_outlined,
                        size: 16,
                        color: Color(0xFF1D4ED8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${vehicle.seats} ที่นั่ง',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1D4ED8),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Kanit',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: (widget.isGuest || !isAvailable)
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      VehicleBookingStep2Page(vehicle: vehicle),
                                ),
                              );
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
                      child: Text(
                        buttonText,
                        style: TextStyle(
                          color: isAvailable ? Colors.white : Colors.white,
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

// ==========================================
// 🚀 WIDGET: ShowUp Animation
// ==========================================
class ShowUp extends StatefulWidget {
  final Widget child;
  final int delay;

  const ShowUp({super.key, required this.child, this.delay = 0});

  @override
  State<ShowUp> createState() => _ShowUpState();
}

class _ShowUpState extends State<ShowUp> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animOffset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _animOffset = Tween<Offset>(
      begin: const Offset(0.0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    if (widget.delay == 0) {
      _controller.forward();
    } else {
      Timer(Duration(milliseconds: widget.delay), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: SlideTransition(position: _animOffset, child: widget.child),
    );
  }
}
