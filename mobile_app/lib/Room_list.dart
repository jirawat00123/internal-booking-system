import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'Room_model.dart';
import 'Admin_roompage.dart';
import 'Room_bookingA.dart'; // เรียกใช้ globalMeetingRooms ตัวเดียวกันที่เป็น ValueNotifier

class RoomListScreen extends StatefulWidget {
  const RoomListScreen({Key? key}) : super(key: key);

  @override
  _RoomListScreenState createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF004AAD),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'จองห้องประชุม',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            fontFamily: 'Kanit',
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildStepIndicator(),

          // 💡 ซิงค์การรับข้อมูลเรียลไทม์จากระบบเพิ่ม/ลบ/แก้ไขของ Admin
          Expanded(
            child: ValueListenableBuilder<List<MeetingRoom>>(
              valueListenable: globalMeetingRooms,
              builder: (context, rooms, child) {
                if (rooms.isEmpty) {
                  return const Center(
                    child: Text(
                      'ไม่มีห้องประชุมที่พร้อมใช้งาน',
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    return _buildRoomCard(rooms[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ส่วนสร้าง Step Indicator (1 เลือกห้อง -> 2 กรอกข้อมูล -> 3 ยืนยัน)
  Widget _buildStepIndicator() {
    return Container(
      color: const Color(0xFF004AAD),
      padding: const EdgeInsets.only(bottom: 20, top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStepCircle('1', 'เลือกห้อง', isActive: true),
            _buildStepLine(),
            _buildStepCircle('2', 'กรอกข้อมูล', isActive: false),
            _buildStepLine(),
            _buildStepCircle('3', 'ยืนยัน', isActive: false),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCircle(String step, String label, {required bool isActive}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF00A8CC) : const Color(0xFFE2E8F0),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey,
              fontWeight: FontWeight.bold,
              fontFamily: 'Kanit',
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? const Color(0xFF004AAD) : Colors.grey,
            fontFamily: 'Kanit',
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine() {
    return Expanded(
      child: Container(
        height: 2,
        color: const Color(0xFFE2E8F0),
        margin: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  // ส่วนสร้าง Card ห้องประชุมสำหรับ User (มีเฉพาะปุ่มเลือกห้อง)
  Widget _buildRoomCard(MeetingRoom room) {
    bool isAvailable = room.status == 'ว่างพร้อมใช้งาน';
    Color statusColor = isAvailable
        ? const Color(0xFF2EC4B6)
        : const Color(0xFFE11D48);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: room.imagePath != null
                    ? (kIsWeb
                          ? Image.network(
                              room.imagePath!,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(room.imagePath!),
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ))
                    : Container(
                        height: 180,
                        width: double
                            .infinity, // 💡 เพิ่มตรงนี้เพื่อให้สีเทาเต็มความกว้างการ์ด
                        color: Colors.grey[300],
                        alignment: Alignment
                            .center, // 💡 เพิ่มตรงนี้เพื่อให้ Icon อยู่ตรงกลางเป๊ะ
                        child: const Icon(
                          Icons.image,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
              ),
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
                      Icon(Icons.circle, color: statusColor, size: 8),
                      const SizedBox(width: 6),
                      Text(
                        room.status,
                        style: TextStyle(
                          fontSize: 10,
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'ห้องประชุม ชั้น ${room.floor}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    fontFamily: 'Kanit',
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildIconDetail(
                        Icons.location_on_outlined,
                        'ชั้น ${room.floor} ฝั่ง ${room.side}',
                      ),
                      const SizedBox(height: 6),
                      _buildIconDetail(
                        Icons.people_outline,
                        'รองรับสูงสุด ${room.capacity} ท่าน',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTag('โปรเจคเตอร์'),
                    const SizedBox(width: 8),
                    _buildTag('สมาร์ททีวี'),
                  ],
                ),
                const SizedBox(height: 6),
                _buildTag('กระดานไวท์บอร์ด'),
                const SizedBox(height: 20),

                // ปุ่มแอคชันสำหรับ User ทั่วไป (พาไปทำรายการต่อที่ Step 2)
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: isAvailable
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RoomBookingAScreen(
                                  room: room,
                                ), // ส่งข้อมูลห้องมาหน้านี้เรียลไทม์
                              ),
                            );
                          }
                        : null, // ถูกปิดการใช้งานอัตโนมัติหากห้องไม่ว่าง
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A8CC),
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'เลือกห้องนี้',
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
        ],
      ),
    );
  }

  Widget _buildIconDetail(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF004AAD)),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.blueGrey,
            fontFamily: 'Kanit',
          ),
        ),
      ],
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.grey,
          fontFamily: 'Kanit',
        ),
      ),
    );
  }
}
