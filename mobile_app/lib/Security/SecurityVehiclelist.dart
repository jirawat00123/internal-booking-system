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
      return 'วันที่ $day $month $year';
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

      final String baseUrl = kIsWeb
          ? 'http://localhost:3001'
          : 'http://localhost:3001';

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
              // 🟢 เจ้าหน้าที่รักษาความปลอดภัยควรเห็นเฉพาะรายการที่ "อนุมัติแล้ว" (APPROVED) เพื่อทำการปล่อยรถ
              // ไม่ควรดึงรายการที่ยัง "รออนุมัติ" (PENDING) มาให้ รปภ. กดปล่อยรถได้
              return status == 'APPROVED';
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
        var user = booking['user']?['employee'] ?? {};

        return _buildVehicleCard(
          bookingId: booking['id'].toString(),
          carName: vehicle['vehicleName'] ?? 'ไม่ระบุรุ่นรถ',
          plate: vehicle['plateNumber'] ?? '-',
          booker: user['fullName'] ?? 'ไม่ระบุชื่อ',
          imageUrl: vehicle['uploadUrl'] ?? '',
          startDate: booking['startDatetime'], // ส่งวันที่ไปแปลง
          endDate: booking['endDatetime'], // ส่งวันที่ไปแปลง
        );
      },
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
    required String carName,
    required String plate,
    required String booker,
    required String imageUrl,
    String? startDate,
    String? endDate,
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
                            '${kIsWeb ? "http://localhost:3001" : "http://localhost:3001"}$imageUrl',
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

            // 🎯 สลับการแสดงผลข้อมูลระหว่าง "หน้าปกติ" กับ "หน้าประวัติ"
            if (isHistory) ...[
              const Divider(),
              const SizedBox(height: 8),
              _buildDetailRow('วันที่ใช้ :', _formatThaiDate(startDate)),
              _buildDetailRow('ถึงวันที่ :', _formatThaiDate(endDate)),
              _buildDetailRow('ผู้ขับขี่ :', booker),
            ] else ...[
              Text(
                'ผู้จอง : $booker',
                style: const TextStyle(
                  color: Colors.blueGrey,
                  fontSize: 13,
                  fontFamily: 'Kanit',
                ),
              ),
            ],

            const SizedBox(height: 8),

            // 🎯 แสดงปุ่มถ่ายรูปเฉพาะตอน "ปล่อยรถออก" และ "รับรถเข้า" (ซ่อนตอนอยู่หน้าประวัติ)
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
                  child: const Text(
                    'ถ่ายรูป',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: 'Kanit',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
