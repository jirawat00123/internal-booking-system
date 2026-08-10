import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'Admin_addroom.dart';
import 'Admin_editroom.dart';
import '../../Booking_room/Room_model.dart';
import '../../AdminGroupPage.dart'; // ดึงเข้ามารองรับปุ่มออกจากระบบ เพื่อกลับไปหน้าเลือกสิทธิ์
import '../../auth_service.dart'; // นำเข้าคลาส AuthService เพื่อดึง Token สำหรับการลบห้องประชุม
// 💡 รายการข้อมูลส่วนกลาง ValueNotifier

class MobileFrameContainer extends StatelessWidget {
  const MobileFrameContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey[900],
      child: Center(
        child: Container(
          width: 400,
          height: 800,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 5),
            ],
          ),
          child: ValueListenableBuilder<List<MeetingRoom>>(
            valueListenable: globalMeetingRooms,
            builder: (context, rooms, child) {
              return const MeetingRoomListScreen();
            },
          ),
        ),
      ),
    );
  }
}

class MeetingRoomListScreen extends StatefulWidget {
  const MeetingRoomListScreen({Key? key}) : super(key: key);

  @override
  _MeetingRoomListScreenState createState() => _MeetingRoomListScreenState();
}

class _MeetingRoomListScreenState extends State<MeetingRoomListScreen> {
  @override
  void initState() {
    super.initState();
    loadRooms();
  }

  Future<void> _deleteRoomFromServer(int roomId) async {
    // ⚠️ หมายเหตุ: เปลี่ยน localhost เป็น IP ของฝั่งเซิร์ฟเวอร์ตามที่ระบบจำลองคุณตั้งไว้
    final url = Uri.parse('http://localhost:3001/api/rooms/$roomId');

    try {
      // 💡 1. ดึง Token จากตัวแปรส่วนกลางเพื่อใช้ในการยืนยันสิทธิ์
      String? token = await AuthService.instance.getToken();

      // 💡 2. แนบ Authorization Header ไปพร้อมกับ HTTP DELETE request เพื่อผ่านด่านหลังบ้าน
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // 🔥 ยืนยันสิทธิ์ความเป็น ADMIN
        },
      );

      // ตรวจสอบ Log ดูสเตตัสตอบกลับจากเซิร์ฟเวอร์
      if (response.statusCode == 200) {
        print('📱 [Flutter Delete] Response Status: ${response.statusCode}');
        print('📱 [Flutter Delete] Response Body: ${response.body}');

        // 🟢 3. เมื่อหลังบ้านแจ้งว่าลบสำเร็จ (Status 200) ค่อยสั่งเคลียร์ข้อมูลออกจาก UI ทันที
        final currentRooms = List<MeetingRoom>.from(globalMeetingRooms.value);

        // 🔥 ป้องกัน Bug ด้วยการแปลง id เป็น String (.toString()) ทั้งคู่ก่อนที่จะนำมาเปรียบเทียบกัน
        currentRooms.removeWhere(
          (room) => room.id.toString() == roomId.toString(),
        );

        // ส่งค่ากลับไปให้ ValueNotifier เพื่อสั่งให้หน้าจอรีเฟรชตัวเองแบบ Real-time
        // 🔔 แสดง SnackBar แจ้งเตือนเมื่อลบสำเร็จสำเร็จ

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'ลบห้องประชุมออกจากระบบสำเร็จแล้ว',
              style: TextStyle(fontFamily: 'Kanit'),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print(
          '🛑 [Flutter Delete] Failed to delete room. Status: ${response.statusCode}',
        );

        // 🔴 กรณีหลังบ้านปฏิเสธ (เช่น Token หมดอายุ หรือไม่มีสิทธิ์ความเป็น Admin)
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ไม่สามารถลบได้: ${errorData['message'] ?? 'เกิดข้อผิดพลาด'}',
              style: const TextStyle(fontFamily: 'Kanit'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      // 🚨 เกิดข้อผิดพลาดด้านเครือข่าย/การเชื่อมต่อ
      print('❌ Connection Error on Delete: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'เกิดข้อผิดพลาดในการเชื่อมต่อเครือข่าย',
            style: TextStyle(fontFamily: 'Kanit'),
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // 🟢 ฟังก์ชันยิง API อัปเดตสถานะห้องประชุม (PATCH /api/rooms/:id/status)
  Future<void> _updateRoomStatusQuickly(
    BuildContext dialogContext,
    MeetingRoom room,
    String newStatus,
  ) async {
    final String baseUrl = kIsWeb
        ? 'http://localhost:3001'
        : 'http://10.0.2.2:3001';
    final url = Uri.parse('$baseUrl/api/rooms/${room.id}/status');

    try {
      String? token = await AuthService.instance.getToken();
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': newStatus}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.pop(dialogContext);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'เปลี่ยนสถานะห้องประชุมเรียบร้อยแล้ว',
                style: TextStyle(fontFamily: 'Kanit'),
              ),
              backgroundColor: Colors.green,
            ),
          );
          loadRooms();
        }
      } else {
        if (mounted) {
          Navigator.pop(dialogContext);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'เกิดข้อผิดพลาด: ${response.statusCode}',
                style: const TextStyle(fontFamily: 'Kanit'),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(dialogContext);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'เกิดข้อผิดพลาดในการเชื่อมต่อเครือข่าย',
              style: TextStyle(fontFamily: 'Kanit'),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  // 🟢 แสดง Dialog เลือกสถานะห้องประชุม
  void _showQuickStatusDialog(BuildContext context, MeetingRoom room) {
    final Map<String, String> statusOptions = {
      'AVAILABLE': 'ว่างพร้อมใช้งาน (Available)',
      'RESERVED': 'ถูกจองแล้ว (Reserved)',
      'IN_USE': 'กำลังใช้งาน (In Use)',
    };

    String selectedStatus = statusOptions.containsKey(room.status)
        ? room.status
        : 'AVAILABLE';
    bool isUpdating = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: isUpdating
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF009CB4)),
                          SizedBox(height: 20),
                          Text(
                            'กำลังอัปเดตสถานะ...',
                            style: TextStyle(
                              color: Color(0xFF009CB4),
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Kanit',
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.swap_horiz,
                                color: Color(0xFF009CB4),
                                size: 28,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'เปลี่ยนสถานะด่วน',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0D47A1),
                                  fontFamily: 'Kanit',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'ห้อง: ${room.roomName}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontFamily: 'Kanit',
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: selectedStatus,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: statusOptions.entries.map((entry) {
                              return DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(
                                  entry.value,
                                  style: const TextStyle(fontFamily: 'Kanit'),
                                ),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              setStateDialog(() {
                                selectedStatus = newValue!;
                              });
                            },
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    setStateDialog(() => isUpdating = true);
                                    _updateRoomStatusQuickly(
                                      dialogContext,
                                      room,
                                      selectedStatus,
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF009CB4),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'บันทึก',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Kanit',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey.shade300,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'ยกเลิก',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontFamily: 'Kanit',
                                      fontWeight: FontWeight.bold,
                                    ),
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
      },
    );
  }

  Future<void> loadRooms() async {
    try {
      // 💡 ปรับ Base URL ให้รองรับ Web และ Emulator อัตโนมัติ (พอร์ต 3001)
      final String baseUrl = kIsWeb
          ? 'http://localhost:3001'
          : 'http://10.0.2.2:3001';
      String? token = await AuthService.instance
          .getToken(); // ดึง Token จาก AuthService

      final response = await http.get(
        Uri.parse('$baseUrl/api/rooms'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // 💡 แนบ Token เพื่อสิทธิ์ดึงข้อมูล
        },
      );

      print(response.statusCode);
      print(response.body);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);

        final List rooms = body is List ? body : (body['data'] ?? []);

        // 🟢 เพิ่มการกรองข้อมูล (Filter) เอาเฉพาะห้องที่ isDeleted เป็น false เท่านั้น
        final activeRooms = rooms.where((room) {
          // ดักจับกรณี backend ส่งมาเป็น boolean หรือ string
          return room['isDeleted'] == false || room['isDeleted'] == 'false';
        }).toList();

        // 🟢 นำข้อมูลที่กรองแล้ว (activeRooms) ไป Map เข้า Model
        globalMeetingRooms.value = activeRooms
            .map((e) => MeetingRoom.fromJson(e))
            .toList();
      } else {
        debugPrint('Load rooms failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Load rooms error: $e');
    }
  }

  void _showDeleteConfirmDialog(int index) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFBC0101),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.priority_high,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'ยืนยันการลบห้อง',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                    fontFamily: 'Kanit',
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'คุณต้องการลบห้องนี้ใช่หรือไม่?',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF0D47A1),
                    fontFamily: 'Kanit',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () async {
                            final room = globalMeetingRooms.value[index];
                            Navigator.pop(
                              dialogContext,
                            ); // ปิด Pop-up ก่อนเพื่อกันผู้ใช้กดเบิ้ล

                            // 🟢 ใช้ tryParse ป้องกันแอป Crash (Safe Parsing)
                            final parsedId = int.tryParse(room.id.toString());
                            if (parsedId != null) {
                              await _deleteRoomFromServer(parsedId);
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'ID ห้องประชุมไม่ถูกต้อง ไม่สามารถลบได้',
                                      style: TextStyle(fontFamily: 'Kanit'),
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            }
                          },
                          // 🟢 เติม style และ child คืนให้ปุ่มลบ
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB70000),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'ลบห้อง',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Kanit',
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // 🟢 นำปุ่ม "ยกเลิก" คืนมา
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0096C7),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'ยกเลิก',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Kanit',
                            ),
                          ),
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
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AdminGroupPage()),
            );
          },
        ),
        title: const Text(
          'ห้องประชุม',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            fontFamily: 'Kanit',
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 1, 148, 188),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MobileFrameAddRoomContainer(),
                    ),
                  ).then((_) => setState(() {}));
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'เพิ่มห้องประชุม',
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
          const SizedBox(height: 20),
          Expanded(
            // 🟢 ครอบ ValueListenableBuilder เพื่อให้ UI รีเฟรชทันทีที่ข้อมูลถูกลบ
            child: ValueListenableBuilder<List<MeetingRoom>>(
              valueListenable: globalMeetingRooms,
              builder: (context, roomsList, child) {
                if (roomsList.isEmpty) {
                  return const Center(
                    child: Text(
                      'ยังไม่มีห้องประชุมในระบบ',
                      style: TextStyle(fontFamily: 'Kanit', color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: roomsList.length,
                  itemBuilder: (context, index) {
                    // 🟢 ทำ Bounds Check ตรวจสอบความปลอดภัย 100% ป้องกันแอปเด้ง
                    if (index >= roomsList.length)
                      return const SizedBox.shrink();

                    final room = roomsList[index];
                    return _buildRoomCard(room, index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String displayStatus(String status) {
    switch (status) {
      case 'AVAILABLE':
        return 'ว่างพร้อมใช้งาน';
      case 'RESERVED': // 💡 เปลี่ยนตาม Schema ใหม่
        return 'จองแล้ว';
      case 'IN_USE': // 💡 เปลี่ยนตาม Schema ใหม่
        return 'กำลังใช้งาน';
      default:
        return status;
    }
  }

  Widget _buildRoomCard(MeetingRoom room, int index) {
    Color statusColor;
    if (room.status == 'AVAILABLE') {
      statusColor = const Color(0xFF2EC4B6);
    } else if (room.status == 'RESERVED') {
      statusColor = const Color(0xFFF59E0B);
    } else {
      statusColor = const Color(0xFFE11D48);
    }

    return Container(
      // 🟢 ตั้งค่าขอบด้านข้าง (Margin) ให้ตรงกับรูปเป๊ะๆ (ซ้าย-ขวา 16, บน-ล่าง 12)
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16), // ปรับขอบให้มนเท่ารูปต้นแบบ
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch, // ขยายให้เต็มความกว้างการ์ด
        children: [
          // 📸 1. ส่วนรูปภาพและป้ายสถานะ (จัดแบบ Flat ไม่ซ้อนทับเนื้อหาด้านล่าง)
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: room.imagePath != null && room.imagePath!.isNotEmpty
                    ? Image.network(
                        room.imagePath!.startsWith('http')
                            ? room.imagePath!
                            : '${kIsWeb ? "http://localhost:3001" : "http://10.0.2.2:3001"}${room.imagePath}',
                        height: 180, // ความสูงรูปภาพตามต้นแบบ
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 180,
                            width: double.infinity,
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.broken_image,
                              size: 50,
                              color: Colors.grey,
                            ),
                          );
                        },
                      )
                    : Container(
                        height: 180,
                        width: double.infinity,
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.image,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
              ),

              // ป้ายสถานะ มุมขวาบน
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: statusColor, size: 10),
                      const SizedBox(width: 4),
                      Text(
                        displayStatus(room.status),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                          fontFamily: 'Kanit',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 📝 2. ส่วนเนื้อหา (จัดให้อยู่ตรงกลางตามรูปต้นแบบ)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  room.roomName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    fontFamily: 'Kanit',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // ไอคอนสถานที่ และ จำนวนคน
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildIconDetail(Icons.location_on_outlined, room.location),
                    const SizedBox(width: 16),
                    _buildIconDetail(
                      Icons.people_outline,
                      'รองรับสูงสุด ${room.capacity} ท่าน',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ป้าย Tag เรียงตรงกลาง (ใช้ Wrap เผื่อป้ายยาวจะได้ไม่ล้นจอ)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8, // ระยะห่างแนวนอน
                  runSpacing: 8, // ระยะห่างแนวตั้ง (กรณีขึ้นบรรทัดใหม่)
                  children: [
                    _buildTag('โปรเจคเตอร์'),
                    _buildTag('สมาร์ททีวี'),
                    _buildTag('กระดานไวท์บอร์ด'),
                  ],
                ),
                const SizedBox(height: 24),

                // 🟢 ส่วนล่างสุด: ปุ่มเปลี่ยนสถานะ, แก้ไข และ ลบห้อง
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ปุ่มเปลี่ยนสถานะด่วน
                    OutlinedButton(
                      onPressed: () => _showQuickStatusDialog(context, room),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF009CB4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: const Text(
                        'เปลี่ยนสถานะ',
                        style: TextStyle(
                          color: Color(0xFF009CB4),
                          fontFamily: 'Kanit',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    MobileFrameEditRoomContainer(
                                      room: room,
                                      index: index,
                                    ),
                              ),
                            ).then((_) => setState(() {}));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF009CB4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          child: const Text(
                            'แก้ไข',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Kanit',
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          onPressed: () => _showDeleteConfirmDialog(index),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC60000),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          child: const Text(
                            'ลบ',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Kanit',
                            ),
                          ),
                        ),
                      ],
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

  static Widget _buildIconDetail(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min, // ให้หดตัวพอดีกับเนื้อหา
      children: [
        Icon(icon, size: 16, color: Colors.blueGrey),
        const SizedBox(width: 4),
        // 🔥 สิ่งที่เปลี่ยนไป 2.2: หุ้ม Flexible เพื่อให้ข้อความยอมตัดคำแทนการดันขอบจอ
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis, // ตัดคำเป็น ... ถ้ายาวเกิน
            style: const TextStyle(
              fontSize: 12,
              color: Colors.blueGrey,
              fontFamily: 'Kanit',
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.grey,
          fontFamily: 'Kanit',
        ),
      ),
    );
  }

  static Widget _buildActionButton(
    String text,
    Color color,
    VoidCallback onTap,
  ) {
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        onPressed: () {
          onTap();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Kanit',
          ),
        ),
      ),
    );
  }
}
