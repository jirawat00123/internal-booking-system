import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'Admin_roompage.dart';
import 'Admin_editsuccess.dart';
import 'Room_model.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class MobileFrameEditRoomContainer extends StatelessWidget {
  final MeetingRoom room;
  final int index;

  const MobileFrameEditRoomContainer({
    super.key,
    required this.room,
    required this.index,
  });

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
          child: AdminEditRoomScreen(room: room, index: index),
        ),
      ),
    );
  }
}

class AdminEditRoomScreen extends StatefulWidget {
  final MeetingRoom room;
  final int index;

  const AdminEditRoomScreen({Key? key, required this.room, required this.index})
    : super(key: key);

  @override
  _AdminEditRoomScreenState createState() => _AdminEditRoomScreenState();
}

class _AdminEditRoomScreenState extends State<AdminEditRoomScreen> {
  late TextEditingController roomNameController;
  late int floorNumber;
  late String selectedSide;
  late int capacity;
  late String selectedStatus;
  XFile? _imageFile;
  Uint8List?
  _imageBytes; // 💡 เพิ่มตัวแปรเก็บ Bytes ป้องกันปัญหาตระกูล dart:io บน Web เบราว์เซอร์
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    roomNameController = TextEditingController(text: widget.room.roomName);
    floorNumber = int.tryParse(widget.room.location.split(' ')[1]) ?? 1;
    selectedSide = widget.room.location.split(' ').last;
    capacity = widget.room.capacity;
    selectedStatus = widget.room.status == 'AVAILABLE'
        ? 'ว่างพร้อมใช้งาน'
        : 'ปิดปรับปรุง';
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile
            .readAsBytes(); // 💡 อ่านข้อมูลรูปภาพเป็นก้อน Bytes เข้าแรมทันที
        setState(() {
          _imageFile = pickedFile;
          _imageBytes =
              bytes; // 💡 บันทึกลงหน่วยความจำเพื่อให้พร้อมเรนเดอร์และส่ง API
        });
      }
    } catch (e) {
      debugPrint('เกิดข้อผิดพลาดในการเลือกรูปภาพ: $e');
    }
  }

  void _showEditConfirmDialog() {
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
                const Icon(
                  Icons.edit_note_outlined,
                  size: 64,
                  color: Color(0xFF0D47A1),
                ),
                const SizedBox(height: 16),
                const Text(
                  'ยืนยันการแก้ไข',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                    fontFamily: 'Kanit',
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'คุณต้องการบันทึกการแก้ไขใช่หรือไม่?',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF0D47A1),
                    fontFamily: 'Kanit',
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              // 1. ดึง Token จาก SharedPreferences ที่เก็บไว้ตอน Login
                              // 1. ดึง Token จาก SharedPreferences ที่เก็บไว้ตอน Login
                              final prefs =
                                  await SharedPreferences.getInstance();
                              final token = prefs.getString('token') ?? '';

                              debugPrint(
                                '🔑 Token ที่ดึงได้ก่อนส่ง API: $token',
                              ); // 💡 พิมพ์เช็กว่า Token หายไปหรือไม่
                              if (token.isEmpty) {
                                debugPrint(
                                  '❌ Error: ไม่พบ Token ในระบบ! ตรวจสอบหน้า Login ว่าได้ทำการบันทึก prefs.setString(\'token\', ...) แล้วหรือยัง',
                                );
                              }

                              // 📌 แก้ไข IP:
                              // - ใช้ 127.0.0.1 สำหรับรันผ่าน Chrome Web หรือ Windows/Mac Desktop
                              // - ถ้าจะรันบนมือถือเครื่องจริง ต้องแก้เป็น IP ของ Wi-Fi เครื่องเซิร์ฟเวอร์ (เช่น 192.168.1.45)
                              final uri = Uri.parse(
                                'http://127.0.0.1:3001/api/rooms/${widget.room.id}',
                              );
                              var request = http.MultipartRequest('PUT', uri);

                              // 2. 📌 แนบ Token ไปใน Headers เพื่อให้ผ่านด่าน authenticateToken
                              // 2. 📌 แนบ Token ไปใน Headers เพื่อให้ผ่านด่าน authenticateToken
                              // 2. 📌 แนบ Token ไปใน Headers เพื่อให้ผ่านด่าน authenticateToken
                              request.headers['Authorization'] =
                                  'Bearer $token';

                              // 💡 เพิ่ม roomName เข้าไปด้วย เพราะ API ฝั่ง Prisma บังคับให้ใช้
                              request.fields['roomName'] = widget.room.roomName;

                              request.fields['location'] =
                                  'ชั้น $floorNumber ฝั่ง $selectedSide';
                              request.fields['capacity'] = capacity.toString();
                              request.fields['status'] =
                                  selectedStatus == 'ว่างพร้อมใช้งาน'
                                  ? 'AVAILABLE'
                                  : 'MAINTENANCE'; // 💡 เปลี่ยนคำนี้ให้ตรงกับในไฟล์ schema.prisma ของหลังบ้าน

                              if (_imageFile != null) {
                                final imageBytes = await _imageFile!
                                    .readAsBytes();
                                request.files.add(
                                  http.MultipartFile.fromBytes(
                                    'image',
                                    imageBytes,
                                    filename: _imageFile!.name,
                                  ),
                                );
                              }

                              var response = await request.send();

                              if (response.statusCode == 200 ||
                                  response.statusCode == 201) {
                                final respStr = await response.stream
                                    .bytesToString();
                                final jsonResp = json.decode(respStr);
                                final newImageUrl =
                                    jsonResp['data']['uploadUrl'] ??
                                    widget.room.imagePath;

                                final updatedList = List<MeetingRoom>.from(
                                  globalMeetingRooms.value,
                                );
                                updatedList[widget.index] = MeetingRoom(
                                  id: widget.room.id,
                                  roomName: widget.room.roomName,
                                  location:
                                      'ชั้น $floorNumber ฝั่ง $selectedSide',
                                  capacity: capacity,
                                  imagePath: newImageUrl,
                                  status: selectedStatus == 'ว่างพร้อมใช้งาน'
                                      ? 'AVAILABLE'
                                      : 'MAINTENANCE',
                                );
                                globalMeetingRooms.value = updatedList;

                                if (context.mounted) {
                                  Navigator.pop(dialogContext);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const MobileFrameSuccessContainer(),
                                    ),
                                  );
                                }
                              } else {
                                // 3. 📌 เพิ่ม UI แจ้งเตือนเวลามี Error จะได้รู้ว่าเกิดอะไรขึ้นแทนที่จะนิ่งไปเฉยๆ
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'อัปเดตไม่สำเร็จ (Code: ${response.statusCode}) กรุณาล็อกอินใหม่',
                                      ),
                                    ),
                                  );
                                }
                                debugPrint(
                                  '❌ Update failed: ${response.statusCode}',
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'เกิดข้อผิดพลาดในการเชื่อมต่อเซิร์ฟเวอร์: $e',
                                    ),
                                  ),
                                );
                              }
                              debugPrint('❌ Exception: $e');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0096C7),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'ตกลง',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Kanit',
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB70000),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'ยกเลิก',
                            style: TextStyle(
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'แก้ไขห้องประชุม',
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  _buildImageEditCard(),
                  const SizedBox(height: 40),
                  _buildFormCard(),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: 24.0,
              right: 24.0,
              bottom: 24.0,
            ),
            child: SizedBox(
              width: 220,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0096C7),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.0),
                  ),
                ),
                onPressed: _showEditConfirmDialog,
                child: const Text(
                  'ต่อไป',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Kanit',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageEditCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF0096C7).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'เปลี่ยนรูปห้องประชุม',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              fontFamily: 'Kanit',
            ),
          ),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 110,
              height: 65,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(14),
                image: _imageBytes != null
                    ? DecorationImage(
                        image: MemoryImage(_imageBytes!),
                        fit: BoxFit.cover,
                      )
                    : (widget.room.imagePath != null &&
                              widget.room.imagePath!.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(
                                widget.room.imagePath!.startsWith('http')
                                    ? widget.room.imagePath!
                                    : 'http://127.0.0.1:3001${widget.room.imagePath!}',
                              ),
                              fit: BoxFit.cover,
                              onError: (exception, stackTrace) {
                                debugPrint('โหลดรูปภาพล้มเหลว: $exception');
                              },
                            )
                          : null),
              ),
              child:
                  _imageBytes == null &&
                      (widget.room.imagePath == null ||
                          widget.room.imagePath!.isEmpty)
                  ? const Center(
                      child: Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.black38,
                        size: 24,
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.camera_alt,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'ชั้นที่',
                      style: TextStyle(
                        color: Color(0xFF9BB1BD),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kanit',
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildStepper(
                      floorNumber,
                      (val) => setState(() => floorNumber = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'ฝั่ง',
                      style: TextStyle(
                        color: Color(0xFF9BB1BD),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kanit',
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSideToggle(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          const Text(
            'สถานะห้องประชุม',
            style: TextStyle(
              color: Color(0xFF9BB1BD),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Kanit',
            ),
          ),
          const SizedBox(height: 10),
          _buildStatusToggle(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 25),
            child: Divider(color: Color(0xFFE8EFF2)),
          ),
          const Text(
            'รองรับได้ทั้งหมด (คน)',
            style: TextStyle(
              color: Color(0xFF9BB1BD),
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'Kanit',
            ),
          ),
          const SizedBox(height: 14),
          _buildCapacityStepper(),
        ],
      ),
    );
  }

  Widget _buildStepper(int val, Function(int) onChange) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 14),
            onPressed: () => val > 1 ? onChange(val - 1) : null,
          ),
          Text('$val', style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.add, size: 14),
            onPressed: () => onChange(val + 1),
          ),
        ],
      ),
    );
  }

  Widget _buildSideToggle() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: ['A', 'B']
            .map(
              (s) => Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => selectedSide = s),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selectedSide == s
                          ? const Color(0xFFEBF3F9)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      s,
                      style: TextStyle(
                        color: selectedSide == s
                            ? const Color(0xFF0D47A1)
                            : Colors.black54,
                        fontWeight: FontWeight.bold,
                        fontFamily:
                            'Kanit', // 💡 เพิ่มเพื่อให้ Font กลมกลืนกับส่วนอื่น
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildStatusToggle() {
    final statuses = ['ว่างพร้อมใช้งาน', 'ไม่ว่างพร้อมใช้งาน'];

    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: statuses.map((status) {
          bool isSelected = selectedStatus == status;
          Color activeColor = status == 'ว่างพร้อมใช้งาน'
              ? const Color(0xFF2EC4B6)
              : const Color(0xFFE11D48);

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => selectedStatus = status),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withOpacity(0.12)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: isSelected ? activeColor : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Kanit',
                        fontWeight: FontWeight.bold,
                        color: isSelected ? activeColor : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCapacityStepper() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, color: Color(0xFF0D47A1)),
            onPressed: () => capacity > 1 ? setState(() => capacity--) : null,
          ),
          Row(
            children: [
              const Icon(Icons.people_alt_outlined, color: Color(0xFF9BB1BD)),
              const SizedBox(width: 10),
              Text(
                '$capacity',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF0D47A1)),
            onPressed: () => setState(() => capacity++),
          ),
        ],
      ),
    );
  }
}
