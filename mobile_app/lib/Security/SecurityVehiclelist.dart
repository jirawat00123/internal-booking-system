import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'Vehicleout.dart';
import 'Vehiclein.dart';
import 'SecurityGroupPage.dart'; // นำเข้าหน้า SecurityGroupPage เพื่อใช้ในการย้อนกลับไปหน้า Welcome Security
import '../Calendar/calendar_page.dart'; // 🎯 นำเข้าหน้าปฏิทิน

class SecurityVehicleListScreen extends StatefulWidget {
  const SecurityVehicleListScreen({Key? key}) : super(key: key);

  @override
  _SecurityVehicleListScreenState createState() =>
      _SecurityVehicleListScreenState();
}

class _SecurityVehicleListScreenState extends State<SecurityVehicleListScreen> {
  int _selectedIndex = 0;
  bool isLoading = true;
  List<dynamic> pendingVehicles = []; // รอปล่อยออก
  List<dynamic> inUseVehicles = []; // กำลังใช้งาน (รอรับเข้า)
  List<dynamic> historyVehicles = []; // 🎯 ประวัติ (เสร็จสิ้น)
  String _token = ''; // 🎯 เพิ่มตัวแปรสำหรับเก็บ Token

  // 🎯 กำหนด IP/Domain ของ Backend
  final String baseUrl = kIsWeb
      ? 'https://192.168.88.25:3002'
      : 'https://192.168.88.25:3002';

  // 💡 ฟังก์ชันช่วยเติม Base URL ให้พาธรูปภาพ
  String _getFullImageUrl(String path) {
    if (path.isEmpty) return '';

    // แปลง Backslash ให้เป็น Slash
    String normalizedPath = path.replaceAll('\\', '/');

    if (normalizedPath.startsWith('http://') ||
        normalizedPath.startsWith('https://')) {
      return normalizedPath;
    }

    // 🎯 ถ้ามีชื่อโฟลเดอร์เต็มจากฝั่ง Server (เช่น /Internal Booking System/...)
    // ให้ตัดทิ้งแล้วเริ่มที่ /attachments/ เพื่อให้ตรงกับ Static Route ของ API
    if (normalizedPath.contains('/attachments/')) {
      normalizedPath = normalizedPath.substring(
        normalizedPath.indexOf('/attachments/'),
      );
    }

    return '$baseUrl${normalizedPath.startsWith('/') ? '' : '/'}$normalizedPath';
  }

  @override
  void initState() {
    super.initState();
    fetchSecurityVehicleList();
  }

  // 💡 ฟังก์ชันช่วยแปลงวันที่จาก 2026-06-05T00:00:00.000Z เป็น "วันที่ 05 มิ.ย. 2026"
  String _formatThaiDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '-';
    try {
      DateTime dt = DateTime.parse(isoDate).toLocal();
      List<String> months = [
        'ม.ค.',
        'ก.พ.',
        'มี.ค.',
        'เม.ย.',
        'พ.ค.',
        'มิ.ย.',
        'ก.ค.',
        'ส.ค.',
        'ก.ย.',
        'ต.ค.',
        'พ.ย.',
        'ธ.ค.',
      ];
      String day = dt.day.toString().padLeft(2, '0');
      String month = months[dt.month - 1];
      String year = dt.year.toString();
      String hour = dt.hour.toString().padLeft(2, '0');
      String minute = dt.minute.toString().padLeft(2, '0');
      return '$day $month $year เวลา $hour:$minute น.';
    } catch (e) {
      return isoDate;
    }
  }

  // 💡 ฟังก์ชันช่วยแปลงวันที่แสดงเฉพาะวันที่ (ไม่แสดงเวลา)
  String _formatThaiDateOnly(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '-';
    try {
      DateTime dt = DateTime.parse(isoDate).toLocal();
      List<String> months = [
        'ม.ค.',
        'ก.พ.',
        'มี.ค.',
        'เม.ย.',
        'พ.ค.',
        'มิ.ย.',
        'ก.ค.',
        'ส.ค.',
        'ก.ย.',
        'ต.ค.',
        'พ.ย.',
        'ธ.ค.',
      ];
      String day = dt.day.toString().padLeft(2, '0');
      String month = months[dt.month - 1];
      String year = dt.year.toString();
      return '$day $month $year';
    } catch (e) {
      return isoDate;
    }
  }

  Future<void> fetchSecurityVehicleList() async {
    if (mounted) setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      String token =
          prefs.getString('token') ?? prefs.getString('jwt_token') ?? '';

      if (token.isEmpty) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      // 🎯 บันทึก Token ลง State เพื่อนำไปแนบ Headers
      if (mounted) setState(() => _token = token);

      final String baseUrl = kIsWeb
          ? 'https://192.168.88.25:3002'
          : 'https://192.168.88.25:3002';

      final response = await http.get(
        Uri.parse('$baseUrl/api/vehicle-bookings?page=1&limit=100'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> rawBookings = data['data'] ?? data['bookings'] ?? [];

        // 🎯 ดึงรายละเอียดเต็มของแต่ละ Booking (เพื่อให้ได้ vehicleLogs, attachments, releaseImages ฯลฯ)
        List<dynamic> allBookings = await Future.wait(
          rawBookings.map((b) async {
            try {
              String bId = (b['id'] ?? b['bookingId'] ?? '').toString();
              if (bId.isNotEmpty) {
                final detailResponse = await http.get(
                  Uri.parse('$baseUrl/api/vehicle-bookings/$bId'),
                  headers: {'Authorization': 'Bearer $token'},
                );
                if (detailResponse.statusCode == 200) {
                  final detailData = jsonDecode(detailResponse.body);
                  return detailData['data'] ??
                      detailData['booking'] ??
                      detailData;
                }
              }
            } catch (e) {
              print("Error fetching detail for booking: $e");
            }
            return b;
          }),
        );

        if (mounted) {
          setState(() {
            // 1. รอปล่อยรถออก (คำขอที่ได้รับอนุมัติแล้ว หรือรอปล่อย)
            pendingVehicles = allBookings.where((b) {
              String status = b['status']?.toString().toUpperCase() ?? '';
              // 🟢 รองรับสถานะ APPROVED, PENDING, RESERVED และ PENDING_EARLY_RELEASE
              return status == 'APPROVED' ||
                  status == 'PENDING' ||
                  status == 'RESERVED' ||
                  status == 'PENDING_EARLY_RELEASE';
            }).toList();

            // 2. กำลังใช้งาน (รับรถเข้า)
            inUseVehicles = allBookings.where((b) {
              String status = b['status']?.toString().toUpperCase() ?? '';
              return status == 'IN_USE';
            }).toList();

            // 3. เสร็จสิ้น (ประวัติ)
            historyVehicles = allBookings.where((b) {
              String status = b['status']?.toString().toUpperCase() ?? '';
              return status == 'COMPLETED';
            }).toList();

            isLoading = false;
          });
        }
      } else {
        print("API Error: Status ${response.statusCode}");
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error fetching security list: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003E75),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () {
            // 🟢 เปลี่ยนจากการบังคับกลับหน้า SecurityGroupPage (Hardcode)
            // เป็นการใช้คำสั่ง Pop เพื่อย้อนกลับไปยัง "หน้าก่อนหน้า" อย่างถูกต้องตามลำดับชั้น
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'ระบบจัดการรถเข้า-ออก',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Kanit',
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CalendarPage(category: 'VEHICLE'),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTopTabs(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildVehicleList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildTabButton(0, 'ปล่อยรถออก'),
          _buildTabButton(1, 'รับรถเข้า'),
          _buildTabButton(2, 'ประวัติ'),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String title) {
    bool isActive = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF4A9EBD) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? Colors.transparent : Colors.grey.shade300,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey.shade600,
              fontWeight: FontWeight.bold,
              fontFamily: 'Kanit',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleList() {
    // 🎯 ดึง List ตามแท็บที่เลือก
    List<dynamic> currentList = _selectedIndex == 0
        ? pendingVehicles
        : (_selectedIndex == 1 ? inUseVehicles : historyVehicles);

    if (currentList.isEmpty) {
      return const Center(
        child: Text(
          'ไม่มีรายการรถในสถานะนี้',
          style: TextStyle(fontFamily: 'Kanit', color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: currentList.length,
      itemBuilder: (context, index) {
        var booking = currentList[index];
        var vehicle = booking['vehicle'] ?? {};
        var user = booking['user']?['employee'] ?? booking['user'] ?? {};

        // 🎯 ดึงข้อมูล Logs สำหรับเวลาเข้า-ออกจริง (รองรับทั้ง Map และ List และชื่อ Key หลายแบบ)
        var vehicleLogs =
            booking['vehicleLogs'] ??
            booking['vehicle_logs'] ??
            booking['vehicleLog'] ??
            booking['vehicle_log'] ??
            booking['logs'];
        var log = (vehicleLogs is List && vehicleLogs.isNotEmpty)
            ? vehicleLogs.last
            : (vehicleLogs is Map
                  ? vehicleLogs
                  : (booking['vehicleLog'] ?? booking['vehicle_log'] ?? {}));

        // 🎯 ปรับให้เรียกใช้ releaseTime / returnTime จาก Backend/Database ก่อนเสมอ
        String? actualCheckoutTime =
            log['releaseTime'] ??
            booking['releaseTime'] ??
            log['checkoutTime'] ??
            booking['checkoutTime'] ??
            booking['actualCheckoutTime'] ??
            booking['actual_checkout_time'] ??
            log['checkout_time'];

        String? actualReturnTime =
            log['returnTime'] ??
            booking['returnTime'] ??
            booking['actualReturnTime'] ??
            booking['actual_return_time'] ??
            log['return_time'];

        // 🎯 ดึง Array จาก attachments
        List<dynamic> attachments = booking['attachments'] is List
            ? booking['attachments']
            : [];

        // 🎯 ดึงรูปภาพปล่อยรถ (Release Images) จาก releaseImages ลำดับแรก แล้วจึง fallback ไปที่ attachments
        List<String> checkOutImages = [];
        var rawRelease =
            booking['releaseImages'] ??
            booking['release_images'] ??
            booking['checkOutImages'] ??
            booking['check_out_images'] ??
            booking['checkoutImages'] ??
            booking['checkout_images'] ??
            booking['releasePhotos'] ??
            booking['release_photos'];

        if (rawRelease is List && rawRelease.isNotEmpty) {
          checkOutImages = rawRelease
              .map<String>((e) {
                if (e is Map) {
                  return _getFullImageUrl(
                    (e['filePath'] ?? e['file_path'] ?? e['url'] ?? '')
                        .toString(),
                  );
                }
                return _getFullImageUrl(e.toString());
              })
              .where((p) => p.isNotEmpty)
              .toList();
        }

        if (checkOutImages.isEmpty) {
          checkOutImages = attachments
              .where((a) {
                String type =
                    (a['entityType'] ?? a['type'] ?? a['category'] ?? '')
                        .toString()
                        .toUpperCase();
                String path =
                    (a['filePath'] ?? a['file_path'] ?? a['url'] ?? '')
                        .toString()
                        .toLowerCase();
                return type.contains('RELEASE') || path.contains('/release');
              })
              .map<String>(
                (a) => _getFullImageUrl(
                  (a['filePath'] ??
                          a['file_path'] ??
                          a['url'] ??
                          a['fileName'] ??
                          '')
                      .toString(),
                ),
              )
              .where((p) => p.isNotEmpty)
              .toList();
        }

        // 🎯 ดึงรูปภาพปล่อยรถเพิ่มเติมจากทั้ง log และ booking (รองรับทั้ง camelCase และ snake_case)
        List<dynamic> targetsLogAndBooking = [log, booking];
        for (var source in targetsLogAndBooking) {
          if (source is Map) {
            for (var field in [
              'checkoutFrontPhoto',
              'checkout_front_photo',
              'checkoutBackPhoto',
              'checkout_back_photo',
              'checkoutMileagePhoto',
              'checkout_mileage_photo',
              'releaseFrontPhoto',
              'release_front_photo',
              'releaseBackPhoto',
              'release_back_photo',
              'releaseMileagePhoto',
              'release_mileage_photo',
              'releasePhoto',
              'release_photo',
              'checkoutPhoto',
              'checkout_photo',
            ]) {
              if (source[field] != null &&
                  source[field].toString().isNotEmpty) {
                String imgUrl = _getFullImageUrl(source[field].toString());
                if (imgUrl.isNotEmpty && !checkOutImages.contains(imgUrl)) {
                  checkOutImages.add(imgUrl);
                }
              }
            }
          }
        }

        // 🎯 ดึงรูปภาพรับรถเข้า (Return Images) จาก returnImages ลำดับแรก แล้วจึง fallback ไปที่ attachments
        List<String> checkInImages = [];
        var rawReturn =
            booking['returnImages'] ??
            booking['return_images'] ??
            booking['checkInImages'] ??
            booking['check_in_images'] ??
            booking['receiveImages'] ??
            booking['receive_images'] ??
            booking['returnPhotos'] ??
            booking['return_photos'];

        if (rawReturn is List && rawReturn.isNotEmpty) {
          checkInImages = rawReturn
              .map<String>((e) {
                if (e is Map) {
                  return _getFullImageUrl(
                    (e['filePath'] ?? e['file_path'] ?? e['url'] ?? '')
                        .toString(),
                  );
                }
                return _getFullImageUrl(e.toString());
              })
              .where((p) => p.isNotEmpty)
              .toList();
        }

        if (checkInImages.isEmpty) {
          checkInImages = attachments
              .where((a) {
                String type =
                    (a['entityType'] ?? a['type'] ?? a['category'] ?? '')
                        .toString()
                        .toUpperCase();
                String path =
                    (a['filePath'] ?? a['file_path'] ?? a['url'] ?? '')
                        .toString()
                        .toLowerCase();
                return type.contains('RETURN') || path.contains('/return');
              })
              .map<String>(
                (a) => _getFullImageUrl(
                  (a['filePath'] ??
                          a['file_path'] ??
                          a['url'] ??
                          a['fileName'] ??
                          '')
                      .toString(),
                ),
              )
              .where((p) => p.isNotEmpty)
              .toList();
        }

        // 🎯 ดึงรูปภาพรับรถเข้าเพิ่มเติมจากทั้ง log และ booking (รองรับทั้ง camelCase และ snake_case)
        for (var source in targetsLogAndBooking) {
          if (source is Map) {
            for (var field in [
              'returnFrontPhoto',
              'return_front_photo',
              'returnBackPhoto',
              'return_back_photo',
              'returnMileagePhoto',
              'return_mileage_photo',
              'returnPhoto',
              'return_photo',
            ]) {
              if (source[field] != null &&
                  source[field].toString().isNotEmpty) {
                String imgUrl = _getFullImageUrl(source[field].toString());
                if (imgUrl.isNotEmpty && !checkInImages.contains(imgUrl)) {
                  checkInImages.add(imgUrl);
                }
              }
            }
          }
        }

        // 🟢 Log ตรวจสอบ Key ทั้งหมดที่ Backend ส่งมาจริงเพื่อหาสาเหตุ
        print('================ [DEBUG BOOKING DATA] ================');
        print('Booking ID: ${booking['id'] ?? booking['bookingId']}');
        if (booking is Map) {
          print('Booking Keys ทั้งหมดจาก Backend: ${booking.keys.toList()}');
        }
        if (log is Map) {
          print('Log Keys ทั้งหมด: ${log.keys.toList()}');
        }
        print(
          'Result checkOutImages (${checkOutImages.length}): $checkOutImages',
        );
        print('Result checkInImages (${checkInImages.length}): $checkInImages');
        print('=====================================================');

        // 🎯 ปรับลำดับให้ใช้ bookingRef นำหน้าก่อน bookingCode
        String bookingRef =
            (booking['bookingRef'] ??
                    booking['bookingCode'] ??
                    booking['id'] ??
                    '')
                .toString();

        return _buildVehicleCard(
          bookingId: (booking['id'] ?? booking['bookingId'] ?? '').toString(),
          bookingRef: bookingRef,
          carName:
              vehicle['vehicleName'] ?? vehicle['model'] ?? 'ไม่ระบุรุ่นรถ',
          plate: vehicle['plateNumber'] ?? vehicle['licensePlate'] ?? '-',
          booker: user['fullName'] ?? user['name'] ?? 'ไม่ระบุชื่อ',
          imageUrl: _getFullImageUrl(
            vehicle['uploadUrl'] ?? vehicle['imageUrl'] ?? '',
          ),
          startDate: booking['startDatetime'] ?? booking['startDate'],
          endDate: booking['endDatetime'] ?? booking['endDate'],
          createdAt: booking['createdAt'] ?? booking['created_at'],
          actualCheckoutTime: actualCheckoutTime,
          actualReturnTime: actualReturnTime,
          checkOutImages: checkOutImages,
          checkInImages: checkInImages,
          driverType: booking['driverType']?.toString(),
          companyDriverId:
              booking['driverEmployeeId'] ?? booking['companyDriverId'],
        );
      },
    );
  }

  void _showImageGallery(
    BuildContext context,
    String title,
    List<String>? imageUrls,
  ) {
    if (imageUrls == null || imageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ไม่มีรูปภาพบันทึกไว้',
            style: TextStyle(fontFamily: 'Kanit'),
          ),
        ),
      );
      return;
    }

    int currentIndex = 0;
    final PageController pageController = PageController();

    // 🎯 ฟังก์ชันช่วยแปลชื่อประเภทรูปจาก URL เป็นภาษาไทย
    String getImageLabel(String url, String defaultTitle) {
      final lowerUrl = url.toLowerCase();
      if (lowerUrl.contains('front')) return 'ด้านหน้า';
      if (lowerUrl.contains('back')) return 'ด้านหลัง';
      if (lowerUrl.contains('mileage')) return 'เลขไมล์';
      if (defaultTitle == 'รูปรับรถเข้า') return 'รูปคืนรถ';
      return defaultTitle;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias, // ทำให้มุมมนคลุมเนื้อหาด้านในทั้งหมด
            child: ConstrainedBox(
              // 🎯 กำหนดขนาดสูงสุด ป้องกันล้นจอและรองรับ Responsive Web/Mobile
              constraints: BoxConstraints(
                maxWidth: 800,
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Header
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 20,
                      right: 8,
                      top: 8,
                      bottom: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Kanit',
                            color: Color(0xFF003E75),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // 2. Main Image Area
                  Flexible(
                    child: Container(
                      width: double.infinity,
                      color: const Color(
                        0xFF1E1E1E,
                      ), // 🎯 พื้นหลังสีเข้ม/neutral สำหรับแสดงรูป
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PageView.builder(
                            controller: pageController,
                            itemCount: imageUrls.length,
                            onPageChanged: (index) {
                              setState(() {
                                currentIndex = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              return InteractiveViewer(
                                // 🎯 ใส่ ValueKey ให้รีเซ็ตการ Zoom อัตโนมัติเมื่อเปลี่ยนภาพ
                                key: ValueKey(imageUrls[index]),
                                minScale: 1.0,
                                maxScale: 4.0,
                                child: Image.network(
                                  imageUrls[index],
                                  headers: {
                                    'Authorization': 'Bearer $_token',
                                  }, // แนบ Token
                                  fit: BoxFit
                                      .contain, // 🎯 ไม่ Crop รูป ให้เห็นทั้งหมดแบบรักษา Aspect Ratio
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return const Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                          ),
                                        );
                                      },
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.broken_image,
                                              color: Colors.white54,
                                              size: 48,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'ไม่สามารถแสดงรูปภาพได้',
                                              style: TextStyle(
                                                fontFamily: 'Kanit',
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                ),
                              );
                            },
                          ),
                          // 🎯 ปุ่มเลื่อนซ้าย (จะซ่อนเมื่ออยู่รูปแรก)
                          if (currentIndex > 0)
                            Positioned(
                              left: 12,
                              child: CircleAvatar(
                                backgroundColor: Colors.black54,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back_ios_new,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  onPressed: () {
                                    pageController.previousPage(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                ),
                              ),
                            ),
                          // 🎯 ปุ่มเลื่อนขวา (จะซ่อนเมื่ออยู่รูปสุดท้าย)
                          if (currentIndex < imageUrls.length - 1)
                            Positioned(
                              right: 12,
                              child: CircleAvatar(
                                backgroundColor: Colors.black54,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  onPressed: () {
                                    pageController.nextPage(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Image Label & Counter
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    color: Colors.white,
                    child: Column(
                      children: [
                        Text(
                          getImageLabel(imageUrls[currentIndex], title),
                          style: const TextStyle(
                            fontFamily: 'Kanit',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF003E75),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'รูปที่ ${currentIndex + 1} / ${imageUrls.length}',
                          style: const TextStyle(
                            fontFamily: 'Kanit',
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 4. Thumbnail Strip
                  if (imageUrls.length > 1)
                    Container(
                      height: 86,
                      width: double.infinity,
                      color: const Color(0xFFF4F7FA),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: imageUrls.length,
                        itemBuilder: (context, index) {
                          bool isSelected = index == currentIndex;
                          return GestureDetector(
                            onTap: () {
                              pageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 12),
                              width: 66,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF003E75)
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: Image.network(
                                  imageUrls[index],
                                  headers: {'Authorization': 'Bearer $_token'},
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.broken_image,
                                        color: Colors.grey,
                                        size: 24,
                                      ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 🎯 สร้าง Widget แถวสำหรับแสดง วันที่/ชื่อผู้จอง ในหน้าประวัติ
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
              fontFamily: 'Kanit',
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF003E75),
              fontWeight: FontWeight.bold,
              fontSize: 13,
              fontFamily: 'Kanit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard({
    required String bookingId,
    String? bookingRef,
    required String carName,
    required String plate,
    required String booker,
    required String imageUrl,
    String? startDate,
    String? endDate,
    String? createdAt,
    String? actualCheckoutTime,
    String? actualReturnTime,
    List<String>? checkOutImages,
    List<String>? checkInImages,
    String? driverType,
    dynamic companyDriverId,
  }) {
    bool isPending = _selectedIndex == 0;
    bool isInUse = _selectedIndex == 1;
    bool isHistory = _selectedIndex == 2;
    bool isUnassignedCompanyDriver =
        (driverType == 'COMPANY' || driverType == 'COMPANY_DRIVER') &&
        (companyDriverId == null ||
            companyDriverId.toString().isEmpty ||
            companyDriverId == 0);

    // 🎯 กำหนดสีและข้อความของ Badge มุมขวาบน
    Color badgeColor = isPending
        ? Colors.amber
        : (isInUse ? Colors.blue : Colors.grey.shade400);
    String badgeText = isPending
        ? 'รอปล่อยรถ' // 🟢 เปลี่ยนข้อความให้สอดคล้องกับสถานะ APPROVED
        : (isInUse ? 'กำลังใช้งาน' : 'เสร็จสิ้น');

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    color: Colors.grey.shade200,
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl, // 🎯 ใช้ imageUrl ที่ผ่าน _getFullImageUrl มาแล้วเพื่อไม่ให้ URL เบิ้ลซ้อนกัน
                            headers: {
                              'Authorization': 'Bearer $_token',
                            }, // 🎯 แนบ Token
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => const Icon(
                              Icons.directions_car,
                              size: 50,
                              color: Colors.grey,
                            ),
                          )
                        : const Icon(
                            Icons.directions_car,
                            size: 50,
                            color: Colors.grey,
                          ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      // 🎯 ถ้าเป็นหน้าประวัติ ให้พื้นหลังเป็นสีเทาขุ่นนิดๆ
                      color: isHistory
                          ? Colors.white.withOpacity(0.85)
                          : Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.circle, size: 10, color: badgeColor),
                        const SizedBox(width: 4),
                        Text(
                          badgeText,
                          style: TextStyle(
                            color: isHistory ? Colors.black87 : Colors.white,
                            fontSize: 12,
                            fontWeight: isHistory
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontFamily: 'Kanit',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              carName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                fontFamily: 'Kanit',
                color: Color(0xFF003E75),
              ),
            ),
            Text(
              'กท $plate',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontFamily: 'Kanit',
              ),
            ),
            const SizedBox(height: 12),

            const Divider(),
            const SizedBox(height: 8),

            _buildDetailRow('เวลาที่กดจอง :', _formatThaiDate(createdAt)),

            // 🟢 แสดงผลแยกตามสถานะ (ปล่อยรถ / รับรถเข้า / ประวัติ)
            if (isPending) ...[
              _buildDetailRow('เริ่มใช้งาน :', _formatThaiDateOnly(startDate)),
              _buildDetailRow('ถึงวัน :', _formatThaiDateOnly(endDate)),
            ] else if (isInUse) ...[
              _buildDetailRow('เริ่มใช้งาน :', _formatThaiDateOnly(startDate)),
              _buildDetailRow('ถึงวัน :', _formatThaiDateOnly(endDate)),
            ] else if (isHistory) ...[
              _buildDetailRow('เริ่มใช้งาน :', _formatThaiDateOnly(startDate)),
              _buildDetailRow('ถึงวันที่ :', _formatThaiDateOnly(endDate)),
            ],

            _buildDetailRow('ผู้ทำรายการ :', booker),

            const SizedBox(height: 8),

            // 🎯 แสดงปุ่มปล่อยรถออก / รับรถเข้า เฉพาะตอนอยู่หน้าที่เกี่ยวข้อง (ซ่อนตอนอยู่หน้าประวัติ)
            if (isPending || isInUse) ...[
              const SizedBox(height: 8),
              if (isPending && isUnassignedCompanyDriver) ...[
                const Text(
                  'ยังไม่ได้จัดสรรพนักงานขับรถ',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Kanit',
                  ),
                ),
                const SizedBox(height: 6),
              ],
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: (isPending && isUnassignedCompanyDriver)
                      ? null
                      : () {
                          if (isPending) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    VehicleOutScreen(bookingId: bookingId),
                              ),
                            ).then((_) {
                              fetchSecurityVehicleList();
                            });
                          } else if (isInUse) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    VehicleInScreen(bookingId: bookingId),
                              ),
                            ).then((_) {
                              fetchSecurityVehicleList();
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF009CB4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    isPending ? 'ปล่อยรถออก (ถ่ายรูป)' : 'รับรถเข้า (ถ่ายรูป)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: 'Kanit',
                    ),
                  ),
                ),
              ),
            ],

            // 🎯 แสดงปุ่มดูรูปภาพปล่อยรถ / รับรถเข้า ตามความจริงของข้อมูลที่มีอยู่ (รองรับการดูรูปปล่อยรถแม้ขณะอยู่ในแท็บกำลังใช้งาน)
            if ((checkOutImages != null && checkOutImages.isNotEmpty) ||
                (checkInImages != null && checkInImages.isNotEmpty)) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (checkOutImages != null && checkOutImages.isNotEmpty)
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.photo_camera_outlined, size: 16),
                        label: const Text(
                          'รูปปล่อยรถ',
                          style: TextStyle(fontFamily: 'Kanit', fontSize: 13),
                        ),
                        onPressed: () => _showImageGallery(
                          context,
                          'รูปปล่อยรถ',
                          checkOutImages,
                        ),
                      ),
                    ),
                  if (checkOutImages != null &&
                      checkOutImages.isNotEmpty &&
                      checkInImages != null &&
                      checkInImages.isNotEmpty)
                    const SizedBox(width: 8),
                  if (checkInImages != null && checkInImages.isNotEmpty)
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.image_outlined, size: 16),
                        label: const Text(
                          'รูปรับรถเข้า',
                          style: TextStyle(fontFamily: 'Kanit', fontSize: 13),
                        ),
                        onPressed: () => _showImageGallery(
                          context,
                          'รูปรับรถเข้า',
                          checkInImages,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
