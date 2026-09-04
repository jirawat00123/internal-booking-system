import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'Vehicleout.dart';
import 'Vehiclein.dart';
import 'SecurityGroupPage.dart'; // นำเข้าหน้า SecurityGroupPage เพื่อใช้ในการย้อนกลับไปหน้า Welcome Security

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
        List<dynamic> allBookings = data['data'] ?? data['bookings'] ?? [];

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

        // 🎯 ดึงข้อมูล Logs สำหรับเวลาเข้า-ออกจริง (รองรับทั้ง Map และ List)
        var vehicleLogs = booking['vehicleLogs'];
        var log = (vehicleLogs is List && vehicleLogs.isNotEmpty)
            ? vehicleLogs.last
            : (vehicleLogs is Map
                  ? vehicleLogs
                  : (booking['vehicleLog'] ?? {}));

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
            booking['checkOutImages'] ??
            booking['check_out_images'] ??
            booking['checkoutImages'] ??
            booking['releasePhotos'];

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

        // 🎯 ดึงรูปภาพปล่อยรถเพิ่มเติมจาก vehicleLogs (checkoutFrontPhoto, checkoutBackPhoto, checkoutMileagePhoto)
        if (log is Map) {
          for (var field in [
            'checkoutFrontPhoto',
            'checkoutBackPhoto',
            'checkoutMileagePhoto',
          ]) {
            if (log[field] != null && log[field].toString().isNotEmpty) {
              String imgUrl = _getFullImageUrl(log[field].toString());
              if (imgUrl.isNotEmpty && !checkOutImages.contains(imgUrl)) {
                checkOutImages.add(imgUrl);
              }
            }
          }
        }

        // 🎯 ดึงรูปภาพรับรถเข้า (Return Images) จาก returnImages ลำดับแรก แล้วจึง fallback ไปที่ attachments
        List<String> checkInImages = [];
        var rawReturn =
            booking['returnImages'] ??
            booking['checkInImages'] ??
            booking['check_in_images'] ??
            booking['receiveImages'] ??
            booking['returnPhotos'];

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

        // 🎯 ดึงรูปภาพรับรถเข้าเพิ่มเติมจาก vehicleLogs (returnFrontPhoto, returnBackPhoto, returnMileagePhoto)
        if (log is Map) {
          for (var field in [
            'returnFrontPhoto',
            'returnBackPhoto',
            'returnMileagePhoto',
          ]) {
            if (log[field] != null && log[field].toString().isNotEmpty) {
              String imgUrl = _getFullImageUrl(log[field].toString());
              if (imgUrl.isNotEmpty && !checkInImages.contains(imgUrl)) {
                checkInImages.add(imgUrl);
              }
            }
          }
        }

        // 🎯 ปรับลำดับให้ใช้ bookingRef นำหน้าก่อน bookingCode
        String bookingRef =
            (booking['bookingRef'] ??
                    booking['bookingCode'] ??
                    booking['id'] ??
                    '')
                .toString();

        dynamic relObj =
            booking['checkoutByName'] ??
            log['checkoutByName'] ??
            log['releasedBy'] ??
            log['checkoutBy'] ??
            log['releaseBy'] ??
            booking['releasedBy'] ??
            booking['checkoutBy'] ??
            booking['releaseBy'];
        String releasedBy = '-';
        if (relObj is String) {
          // เพิ่มการกรองเพื่อป้องกันกรณีที่ค่าเป็นว่าง หรือ Backend ส่งกลับมาเป็น ObjectId (ไอดีความยาว 24 ตัวอักษร)
          releasedBy =
              (relObj.trim().isEmpty ||
                  (relObj.length == 24 && !relObj.contains(' ')))
              ? '-'
              : relObj;
        } else if (relObj is Map) {
          releasedBy =
              relObj['fullName'] ??
              relObj['name'] ??
              relObj['employee']?['fullName'] ??
              relObj['employee']?['name'] ??
              '-';
        }

        dynamic retObj =
            booking['returnByName'] ??
            log['returnByName'] ??
            log['returnedBy'] ??
            log['checkinBy'] ??
            log['returnBy'] ??
            booking['returnedBy'] ??
            booking['checkinBy'] ??
            booking['returnBy'];
        String returnedBy = '-';
        if (retObj is String) {
          // เพิ่มการกรองเพื่อป้องกันกรณีที่ค่าเป็นว่าง หรือ Backend ส่งกลับมาเป็น ObjectId (ไอดีความยาว 24 ตัวอักษร)
          returnedBy =
              (retObj.trim().isEmpty ||
                  (retObj.length == 24 && !retObj.contains(' ')))
              ? '-'
              : retObj;
        } else if (retObj is Map) {
          returnedBy =
              retObj['fullName'] ??
              retObj['name'] ??
              retObj['employee']?['fullName'] ??
              retObj['employee']?['name'] ??
              '-';
        }

        return _buildVehicleCard(
          bookingId: (booking['id'] ?? booking['bookingId'] ?? '').toString(),
          bookingRef: bookingRef,
          carName:
              vehicle['vehicleName'] ?? vehicle['model'] ?? 'ไม่ระบุรุ่นรถ',
          plate: vehicle['plateNumber'] ?? vehicle['licensePlate'] ?? '-',
          booker: user['fullName'] ?? user['name'] ?? 'ไม่ระบุชื่อ',
          releasedBy: releasedBy,
          returnedBy: returnedBy,
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

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Kanit',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 300,
              child: PageView.builder(
                itemCount: imageUrls.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrls[index],
                        headers: {
                          'Authorization': 'Bearer $_token',
                        }, // 🎯 แนบ Token
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                              child: Text(
                                'ไม่สามารถโหลดรูปภาพได้',
                                style: TextStyle(fontFamily: 'Kanit'),
                              ),
                            ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'จำนวนทั้งหมด ${imageUrls.length} รูป (เลื่อนซ้าย-ขวาเพื่อดูรูป)',
                style: const TextStyle(fontFamily: 'Kanit'),
              ),
            ),
          ],
        ),
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
    String? releasedBy,
    String? returnedBy,
    required String imageUrl,
    String? startDate,
    String? endDate,
    String? createdAt,
    String? actualCheckoutTime,
    String? actualReturnTime,
    List<String>? checkOutImages,
    List<String>? checkInImages,
  }) {
    bool isPending = _selectedIndex == 0;
    bool isInUse = _selectedIndex == 1;
    bool isHistory = _selectedIndex == 2;

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

            if (isHistory) ...[
              _buildDetailRow('ผู้ปล่อยรถ :', releasedBy ?? '-'),
              _buildDetailRow('ผู้รับรถเข้า :', returnedBy ?? '-'),
            ],

            const SizedBox(height: 8),

            // 🎯 แสดงปุ่มปล่อยรถออก / รับรถเข้า เฉพาะตอนอยู่หน้าที่เกี่ยวข้อง (ซ่อนตอนอยู่หน้าประวัติ)
            if (isPending || isInUse) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () {
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
