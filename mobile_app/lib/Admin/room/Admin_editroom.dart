import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'Admin_roompage.dart';
import 'Admin_editsuccess.dart';
import '../../Booking_room/Room_model.dart';
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
    return AdminEditRoomScreen(room: room, index: index);
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
  late TextEditingController
  _descriptionController; // 🟢 เพิ่ม Controller สำหรับรับค่ารายละเอียดห้อง
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
    _descriptionController = TextEditingController(
      text: widget.room.description ?? '',
    ); // 🟢 ดึงข้อมูล Description เดิมมาแสดงถ้ามี

    // 🟢 ดึงค่าชั้นจากตัวแปร floor โดยตรง และดึงฝั่งจาก location ให้สอดคล้องกับหน้า Add Room
    floorNumber = int.tryParse(widget.room.floor ?? '1') ?? 1;
    List<String> locationParts = widget.room.location.split(' ');
    selectedSide = locationParts.isNotEmpty ? locationParts.last : 'สำนักงาน';

    capacity = widget.room.capacity;
    // 🟢 กำหนดค่าสถานะเริ่มต้นให้รองรับ 3 สถานะใหม่ (AVAILABLE, MAINTENANCE, INACTIVE)
    String rawStatus =
        (widget.room.availabilityStatus ?? widget.room.status ?? 'AVAILABLE')
            .toUpperCase();
    if (rawStatus == 'MAINTENANCE' || rawStatus == 'ปิดปรับปรุง') {
      selectedStatus = 'MAINTENANCE';
    } else if (rawStatus == 'INACTIVE' || rawStatus == 'ระงับการใช้งาน') {
      selectedStatus = 'INACTIVE';
    } else {
      selectedStatus = 'AVAILABLE';
    }
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
    // 🟢 1. สร้าง State จำลองเพื่อดักจับสถานะการโหลด ป้องกันการกดปุ่มซ้ำ
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        // 🟢 2. ครอบด้วย StatefulBuilder เพื่อให้อัปเดต UI ภายใน Dialog ได้
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
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
                              // 🟢 3. ถ้ากำลังโหลดอยู่ให้ปิดปุ่ม (null)
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      setStateDialog(() {
                                        isSubmitting = true; // เปิด Loading
                                      });

                                      try {
                                        final prefs =
                                            await SharedPreferences.getInstance();
                                        final token =
                                            prefs.getString('token') ?? '';

                                        if (token.isEmpty) {
                                          debugPrint(
                                            '❌ Error: ไม่พบ Token ในระบบ!',
                                          );
                                        }

                                        final String baseUrl = kIsWeb
                                            ? 'http://192.168.88.25:3001'
                                            : 'http://192.168.88.25:3001';
                                        final uri = Uri.parse(
                                          '$baseUrl/api/rooms/${widget.room.id}',
                                        );
                                        var request = http.MultipartRequest(
                                          'PUT',
                                          uri,
                                        );

                                        request.headers.addAll({
                                          'Accept': 'application/json',
                                          'Authorization': 'Bearer $token',
                                        });

                                        request.fields['roomName'] =
                                            roomNameController.text;
                                        request.fields['location'] =
                                            'ฝั่ง $selectedSide';
                                        request.fields['capacity'] = capacity
                                            .toString();
                                        request.fields['status'] =
                                            selectedStatus;

                                        // 🟢 เพิ่มส่งข้อมูล Description และ Floor ไปยัง Backend ตอนแก้ไข
                                        request.fields['description'] =
                                            _descriptionController.text;
                                        request.fields['floor'] = floorNumber
                                            .toString();

                                        if (_imageFile != null) {
                                          final imageBytes = await _imageFile!
                                              .readAsBytes();

                                          // 🟢 ตรวจสอบและกำหนดย่อรหัสไฟล์รูปภาพเพื่อความปลอดภัยบน Web
                                          String finalFileName =
                                              _imageFile!.name;
                                          String lowerName = finalFileName
                                              .toLowerCase();
                                          if (!lowerName.endsWith('.png') &&
                                              !lowerName.endsWith('.jpg') &&
                                              !lowerName.endsWith('.jpeg')) {
                                            finalFileName = 'room_image.png';
                                          }

                                          request.files.add(
                                            http.MultipartFile.fromBytes(
                                              'image',
                                              imageBytes,
                                              filename: finalFileName,
                                            ),
                                          );
                                        }

                                        var response = await request.send();

                                        if (response.statusCode == 200 ||
                                            response.statusCode == 201) {
                                          final respStr = await response.stream
                                              .bytesToString();
                                          final jsonResp = json.decode(respStr);

                                          // 🟢 ดึง URL รูปภาพใหม่อย่างปลอดภัย ป้องกัน crash ถ้า data เป็น null
                                          String? newImageUrl;
                                          if (jsonResp
                                              is Map<String, dynamic>) {
                                            if (jsonResp['data'] != null &&
                                                jsonResp['data'] is Map) {
                                              newImageUrl =
                                                  jsonResp['data']['uploadUrl'] ??
                                                  jsonResp['data']['imagePath'];
                                            } else {
                                              newImageUrl =
                                                  jsonResp['uploadUrl'] ??
                                                  jsonResp['imagePath'];
                                            }
                                          }
                                          newImageUrl ??= widget.room.imagePath;

                                          final updatedList =
                                              List<MeetingRoom>.from(
                                                globalMeetingRooms.value,
                                              );

                                          // 🟢 4. ค้นหา Index จาก ID โดยตรงเพื่อความปลอดภัย 100% (กัน List เลื่อน)
                                          final targetIndex = updatedList
                                              .indexWhere(
                                                (r) => r.id == widget.room.id,
                                              );

                                          if (targetIndex != -1) {
                                            updatedList[targetIndex] = MeetingRoom(
                                              id: widget.room.id,
                                              roomName: roomNameController.text,
                                              location: 'ฝั่ง $selectedSide',
                                              capacity: capacity,
                                              imagePath: newImageUrl,
                                              status: selectedStatus,
                                              availabilityStatus:
                                                  selectedStatus,
                                              // 🟢 อัปเดตข้อมูลฟิลด์ใหม่กลับเข้าไปใน Model หน้า UI
                                              description:
                                                  _descriptionController.text,
                                              floor: floorNumber.toString(),
                                              roomCode: widget.room.roomCode,
                                            );
                                            globalMeetingRooms.value =
                                                updatedList; // อัปเดตข้อมูลให้หน้า List
                                          }

                                          if (context.mounted) {
                                            Navigator.pop(
                                              dialogContext,
                                            ); // ปิด Dialog
                                            Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                // 🟢 เปลี่ยนมาเรียกใช้ชื่อคลาสใหม่ที่เราเพิ่งแก้ไปใน Admin_editsuccess
                                                builder: (context) =>
                                                    const MobileFrameEditSuccessContainer(),
                                              ),
                                            );
                                          }
                                        } else {
                                          final responseBody = await response
                                              .stream
                                              .bytesToString();
                                          String errorMessage =
                                              'อัปเดตไม่สำเร็จ (Code: ${response.statusCode})';
                                          try {
                                            final errorData = jsonDecode(
                                              responseBody,
                                            );
                                            errorMessage =
                                                errorData['message'] ??
                                                errorMessage;
                                          } catch (_) {}

                                          debugPrint(
                                            '❌ Update failed: $errorMessage',
                                          );
                                          if (context.mounted) {
                                            Navigator.pop(
                                              dialogContext,
                                            ); // ปิด Dialog
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  errorMessage,
                                                  style: const TextStyle(
                                                    fontFamily: 'Kanit',
                                                  ),
                                                ),
                                                backgroundColor: const Color(
                                                  0xFFB70000,
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      } catch (e) {
                                        debugPrint('❌ Exception: $e');
                                        if (context.mounted) {
                                          Navigator.pop(dialogContext);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'เกิดข้อผิดพลาดในการเชื่อมต่อเซิร์ฟเวอร์ โปรดตรวจสอบอินเทอร์เน็ต',
                                                style: TextStyle(
                                                  fontFamily: 'Kanit',
                                                ),
                                              ),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                        }
                                      } finally {
                                        // ปิดสถานะ Loading หากเกิด Error
                                        if (mounted) {
                                          setStateDialog(() {
                                            isSubmitting = false;
                                          });
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0096C7),
                                disabledBackgroundColor:
                                    Colors.grey, // สีตอนโดนล็อกปุ่ม
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              // 🟢 5. สลับแสดงข้อความ กับ อนิเมชัน Loading
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
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
                              // 🟢 ล็อกปุ่มยกเลิกเวลาโหลดด้วย
                              onPressed: isSubmitting
                                  ? null
                                  : () => Navigator.pop(dialogContext),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB70000),
                                disabledBackgroundColor: Colors.grey,
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF003E75),
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
                                    // 🟢 5. เปลี่ยน URL ดึงภาพเป็น Dynamic ตาม Platform (Web หรือ Emulator)
                                    : '${kIsWeb ? "http://192.168.88.25:3001" : "http://192.168.88.25:3001"}${widget.room.imagePath!.startsWith('/') ? widget.room.imagePath! : '/${widget.room.imagePath!}'}',
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ชื่อห้องประชุม',
            style: TextStyle(
              color: Color(0xFF9BB1BD),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Kanit',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: roomNameController,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF0D47A1)),
              ),
            ),
            style: const TextStyle(
              fontFamily: 'Kanit',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 25),
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

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 25),
            child: Divider(color: Color(0xFFE8EFF2)),
          ),

          // 🟢 เพิ่ม UI ช่องกรอกแก้ไขรายละเอียดห้อง
          const Text(
            'รายละเอียดห้อง (Description)',
            style: TextStyle(
              color: Color(0xFF9BB1BD),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Kanit',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'กรอกรายละเอียดเพิ่มเติม เช่น มีโปรเจคเตอร์...',
              hintStyle: const TextStyle(
                color: Colors.black26,
                fontFamily: 'Kanit',
                fontSize: 14,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF0D47A1)),
              ),
            ),
            style: const TextStyle(
              fontFamily: 'Kanit',
              fontWeight: FontWeight.bold,
            ),
          ),
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
        children: ['สำนักงาน', 'โรงงาน']
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
    final statuses = [
      {'label': 'ว่าง', 'value': 'AVAILABLE', 'color': const Color(0xFF2EC4B6)},
      {'label': 'ปิดปรับปรุง', 'value': 'MAINTENANCE', 'color': Colors.orange},
      {
        'label': 'ระงับการใช้งาน',
        'value': 'INACTIVE',
        'color': const Color(0xFFE11D48),
      },
    ];

    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: statuses.map((item) {
          final String statusValue = item['value'] as String;
          final String statusLabel = item['label'] as String;
          final Color statusColor = item['color'] as Color;
          bool isSelected = selectedStatus == statusValue;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => selectedStatus = statusValue),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? statusColor.withOpacity(0.12)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: isSelected ? statusColor : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Kanit',
                        fontWeight: FontWeight.bold,
                        color: isSelected ? statusColor : Colors.black54,
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
