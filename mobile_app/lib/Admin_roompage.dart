import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb; // 💡 นำเข้าเพื่อเช็กระบบ Web จำลองอัจฉริยะ ป้องกันหน้าจอสีแดง
import 'package:flutter/material.dart';
import 'Admin_addroom.dart';
import 'Admin_editroom.dart'; // เชื่อมไปหาหน้าแก้ไขห้องประชุมของคุณ

// 💡 1. คลาสเก็บข้อมูลห้องประชุม
class MeetingRoom {
  final String id;
  final String floor;
  final String side;
  final int capacity;
  final String? imagePath;
  final String status;

  MeetingRoom({
    required this.id,
    required this.floor,
    required this.side,
    required this.capacity,
    this.imagePath,
    this.status = 'ว่างพร้อมใช้งาน',
  });
}

// 💡 2. รายการข้อมูลส่วนกลาง (Static List)
List<MeetingRoom> globalMeetingRooms = [
  MeetingRoom(id: 'A', floor: '1', side: 'A', capacity: 12, status: 'ว่างพร้อมใช้งาน'),
];

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MobileFrameContainer(),
    ),
  );
}

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
          child: const MeetingRoomListScreen(),
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
  // ฟังก์ชันสำหรับเปิด Popup ยืนยันการลบ
  void _showDeleteConfirmDialog(int index) {
    showDialog(
      context: context,
      barrierDismissible: false, // บังคับให้ต้องเลือกกดปุ่มใดปุ่มหนึ่งเท่านั้น
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.priority_high, color: Colors.white, size: 38),
                ),
                const SizedBox(height: 20),
                const Text('ยืนยันการลบห้อง', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1), fontFamily: 'Kanit')),
                const SizedBox(height: 6),
                const Text('คุณต้องการลบห้องนี้ใช่หรือไม่?', style: TextStyle(fontSize: 13, color: Color(0xFF0D47A1), fontFamily: 'Kanit'), textAlign: TextAlign.center),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            setState(() { globalMeetingRooms.removeAt(index); });
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB70000), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text('ลบห้อง', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0096C7), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text('ยกเลิก', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('ห้องประชุม', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Kanit')),
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
                  backgroundColor: const Color(0xFF4CB8C4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MobileFrameAddRoomContainer()),
                  ).then((_) => setState(() {}));
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('เพิ่มห้องประชุม', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: globalMeetingRooms.isEmpty
                ? const Center(child: Text('ยังไม่มีห้องประชุมในระบบ', style: TextStyle(fontFamily: 'Kanit', color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: globalMeetingRooms.length,
                    itemBuilder: (context, index) {
                      return _buildRoomCard(globalMeetingRooms[index], index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // 💡 ฟังก์ชันสร้าง Card ห้องประชุม
  Widget _buildRoomCard(MeetingRoom room, int index) {
    // 💡 จุดปรับปรุง: ตรวจเช็กและเปลี่ยนสี Badge ตามสถานะแปรผันที่ดึงมาจากหน้า Edit จริงอัตโนมัติ
    bool isAvailable = room.status == 'ว่างพร้อมใช้งาน';
    Color statusColor = isAvailable ? const Color(0xFF2EC4B6) : const Color(0xFFE11D48);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              // 💡 จุดปรับปรุง: แก้ระบบดึงภาพแยกโหมด Web และ Mobile เพื่อแก้ไขปัญหารูปพังจอแดง
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: room.imagePath != null
                    ? (kIsWeb 
                        ? Image.network(room.imagePath!, height: 180, width: double.infinity, fit: BoxFit.cover)
                        : Image.file(File(room.imagePath!), height: 180, width: double.infinity, fit: BoxFit.cover))
                    : Container(height: 180, color: Colors.grey[300], child: const Icon(Icons.image, size: 50)),
              ),
              
              // 💡 ป้ายสถานะห้องขึ้นมุมขวาบน (จะเปลี่ยนข้อความและสีตามโครงสร้างที่ส่งกลับมา)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: statusColor, size: 10),
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
              children: [
                Text('Meeting Room ${room.id}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontFamily: 'Kanit')),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildIconDetail(Icons.location_on_outlined, 'ชั้น ${room.floor} ฝั่ง ${room.side}'),
                    _buildIconDetail(Icons.people_outline, 'รองรับสูงสุด ${room.capacity} ท่าน'),
                  ],
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [_buildTag('กระดานไวท์บอร์ด')],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        'แก้ไขห้อง',
                        const Color(0xFF4CB8C4),
                        () {
                          // 💡 เชื่อมไปหน้าแก้ไขพร้อมส่งข้อมูลวัตถุห้องประชุมปัจจุบัน
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MobileFrameEditRoomContainer(
                                room: room,
                                index: index,
                              ),
                            ),
                          ).then((_) => setState(() {})); // รีเฟรชอัปเดตสถานะทันทีเมื่อกลับมาหน้าหลัก
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        'ลบห้อง',
                        const Color(0xFFE11D48),
                        () => _showDeleteConfirmDialog(index),
                      ),
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
      children: [
        Icon(icon, size: 16, color: Colors.blueGrey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontFamily: 'Kanit')),
      ],
    );
  }

  static Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'Kanit')),
    );
  }

  static Widget _buildActionButton(String text, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(backgroundColor: color, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
      ),
    );
  }
}