import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'Vehicleout.dart'; // โยงไปหน้าถ่ายรูปปล่อยรถ

class SecurityVehicleListScreen extends StatefulWidget {
  const SecurityVehicleListScreen({Key? key}) : super(key: key);

  @override
  _SecurityVehicleListScreenState createState() =>
      _SecurityVehicleListScreenState();
}

class _SecurityVehicleListScreenState extends State<SecurityVehicleListScreen> {
  int _selectedIndex = 0;
  bool isLoading = true;
  List<dynamic> pendingVehicles = []; // รถที่ถูกจองรอปล่อย
  List<dynamic> inUseVehicles = []; // รถที่กำลังใช้งานรอรับเข้า

  @override
  void initState() {
    super.initState();
    fetchSecurityVehicleList();
  }

  // 💡 ฟังก์ชันดึงข้อมูลจาก Booking History และคัดแยกสถานะ
  Future<void> fetchSecurityVehicleList() async {
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      // ✅ แก้ไข: เปลี่ยนคีย์เป็น 'jwt_token' ให้ตรงกับตอน Login
      String token = prefs.getString('jwt_token') ?? '';

      if (token.isEmpty) {
        print("Error: No JWT Token found in SharedPreferences.");
        setState(() => isLoading = false);
        return; // หยุดการทำงานหากไม่มี Token
      }

      // ดึงข้อมูลการจองรถทั้งหมด
      final response = await http.get(
        Uri.parse(
          'http://localhost:3001/api/vehicle-bookings?page=1&limit=100',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> allBookings = data['data'] ?? data['bookings'] ?? [];

        setState(() {
          // กรองเฉพาะ "ถูกจองไว้อยู่" (รออนุมัติ/Pending)
          pendingVehicles = allBookings.where((b) {
            String status = b['status']?.toString().toLowerCase() ?? '';
            return status == 'pending' || status == 'ถูกจองไว้อยู่';
          }).toList();

          // กรองเฉพาะ "กำลังใช้งาน" (In Use/Approved)
          inUseVehicles = allBookings.where((b) {
            String status = b['status']?.toString().toLowerCase() ?? '';
            return status == 'in_use' ||
                status == 'approved' ||
                status == 'กำลังใช้งาน';
          }).toList();

          isLoading = false;
        });
      } else {
        // ✅ เพิ่ม Error Handling หาก Backend ไม่ตอบ 200 จะได้รู้สาเหตุ
        print(
          "API Error: Status ${response.statusCode}, Body: ${response.body}",
        );
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error fetching security list: $e");
      setState(() => isLoading = false);
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
          onPressed: () => Navigator.pop(context),
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
    List<dynamic> currentList = _selectedIndex == 0
        ? pendingVehicles
        : (_selectedIndex == 1 ? inUseVehicles : []);

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
        );
      },
    );
  }

  Widget _buildVehicleCard({
    required String bookingId,
    required String carName,
    required String plate,
    required String booker,
    required String imageUrl,
  }) {
    bool isPending = _selectedIndex == 0;

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
                            'http://localhost:3001$imageUrl',
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
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 10,
                          color: isPending ? Colors.amber : Colors.blue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPending ? 'รออนุมัติ' : 'กำลังใช้งาน',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
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
            const SizedBox(height: 8),
            Text(
              'ผู้จอง : $booker',
              style: const TextStyle(
                color: Colors.blueGrey,
                fontSize: 13,
                fontFamily: 'Kanit',
              ),
            ),
            const SizedBox(height: 16),
            if (isPending) // แสดงปุ่มถ่ายรูปเฉพาะตอนปล่อยรถออก
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () {
                    // 🚀 โยน ID การจองไปหน้าถ่ายรูป
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            VehicleOutScreen(bookingId: bookingId),
                      ),
                    ).then((_) {
                      fetchSecurityVehicleList(); // รีเฟรชหน้าเมื่อกลับมา
                    });
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
        ),
      ),
    );
  }
}
