import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'Admin_addsuccess.dart';
import 'Admin_roompage.dart';
import '../../Booking_room/Room_model.dart';
import 'package:flutter/foundation.dart';

class MobileFrameAddRoomContainer extends StatelessWidget {
  const MobileFrameAddRoomContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return const AddMeetingRoomScreen();
  }
}

class AddMeetingRoomScreen extends StatefulWidget {
  const AddMeetingRoomScreen({Key? key}) : super(key: key);

  @override
  _AddMeetingRoomScreenState createState() => _AddMeetingRoomScreenState();
}

class _AddMeetingRoomScreenState extends State<AddMeetingRoomScreen> {
  int floorNumber = 1;
  String selectedSide = 'สำนักงาน';
  int capacity = 4;
  String selectedStatus = 'AVAILABLE';
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  XFile? _imageFile;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageFile = pickedFile;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('เกิดข้อผิดพลาดในการเลือกรูปภาพ: $e');
    }
  }

  void _showAddRoomConfirmDialog() {
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
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
                      Icons.note_add_outlined,
                      size: 64,
                      color: Color(0xFF0D47A1),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'ยืนยันการเพิ่มห้อง',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                        fontFamily: 'Kanit',
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'คุณต้องการเพิ่มห้องใช่หรือไม่?',
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
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      setStateDialog(() {
                                        isSubmitting = true;
                                      });

                                      try {
                                        final String baseUrl = kIsWeb
                                            ? 'https://192.168.88.25:3002'
                                            : 'https://192.168.88.25:3002';
                                        var uri = Uri.parse(
                                          '$baseUrl/api/rooms',
                                        );
                                        var request = http.MultipartRequest(
                                          'POST',
                                          uri,
                                        );

                                        final prefs =
                                            await SharedPreferences.getInstance();
                                        final token =
                                            prefs.getString('token') ?? '';

                                        request.headers.addAll({
                                          'Accept': 'application/json',
                                          'Authorization': 'Bearer $token',
                                        });

                                        request.fields['roomName'] =
                                            _roomNameController.text
                                                .trim()
                                                .isEmpty
                                            ? 'ห้องประชุมใหม่'
                                            : _roomNameController.text.trim();
                                        request.fields['location'] =
                                            'ฝั่ง $selectedSide';
                                        request.fields['capacity'] = capacity
                                            .toString();
                                        request.fields['status'] =
                                            selectedStatus;

                                        request.fields['description'] =
                                            _descriptionController.text;
                                        request.fields['floor'] = floorNumber
                                            .toString();
                                        request.fields['room_code'] =
                                            'RM$floorNumber$selectedSide-${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}';

                                        if (_imageBytes != null &&
                                            _imageFile != null) {
                                          String finalFileName =
                                              _imageFile!.name;
                                          String lowerName = finalFileName
                                              .toLowerCase();
                                          if (!lowerName.endsWith('.png') &&
                                              !lowerName.endsWith('.jpg') &&
                                              !lowerName.endsWith('.jpeg')) {
                                            finalFileName = 'room_image.png';
                                          }

                                          var multipartFile =
                                              http.MultipartFile.fromBytes(
                                                'image',
                                                _imageBytes!,
                                                filename: finalFileName,
                                              );
                                          request.files.add(multipartFile);
                                        }

                                        var response = await request.send();

                                        if (response.statusCode == 201 ||
                                            response.statusCode == 200) {
                                          final respStr = await response.stream
                                              .bytesToString();
                                          try {
                                            final jsonResp = json.decode(
                                              respStr,
                                            );
                                            final roomData =
                                                jsonResp['data'] ?? jsonResp;

                                            if (roomData != null) {
                                              final newRoom = MeetingRoom(
                                                id:
                                                    roomData['id']
                                                        ?.toString() ??
                                                    DateTime.now()
                                                        .millisecondsSinceEpoch
                                                        .toString(),
                                                roomName:
                                                    roomData['roomName'] ??
                                                    _roomNameController.text
                                                        .trim(),
                                                location:
                                                    roomData['location'] ??
                                                    'ฝั่ง $selectedSide',
                                                capacity:
                                                    roomData['capacity'] is int
                                                    ? roomData['capacity']
                                                    : (int.tryParse(
                                                            roomData['capacity']
                                                                .toString(),
                                                          ) ??
                                                          capacity),
                                                imagePath:
                                                    roomData['uploadUrl'] ??
                                                    roomData['imagePath'] ??
                                                    '',
                                                status:
                                                    roomData['status'] ??
                                                    selectedStatus,
                                                availabilityStatus:
                                                    roomData['availability_status'] ??
                                                    roomData['availabilityStatus'] ??
                                                    roomData['status'] ??
                                                    selectedStatus,
                                                description:
                                                    roomData['description'],
                                                floor: roomData['floor'],
                                                roomCode: roomData['room_code'],
                                              );

                                              final updatedList =
                                                  List<MeetingRoom>.from(
                                                    globalMeetingRooms.value,
                                                  );
                                              updatedList.add(newRoom);
                                              globalMeetingRooms.value =
                                                  updatedList;
                                            }
                                          } catch (e) {
                                            debugPrint(
                                              '⚠️ [Flutter] Parse Room Error: $e',
                                            );
                                          }

                                          if (mounted) {
                                            Navigator.pop(dialogContext);
                                            Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const MobileFrameSuccessContainer(),
                                              ),
                                            );
                                          }
                                        } else {
                                          String errorMessage =
                                              'เกิดข้อผิดพลาดจากเซิร์ฟเวอร์ (Code: ${response.statusCode})';
                                          try {
                                            final responseBody = await response
                                                .stream
                                                .bytesToString();
                                            final errorData = jsonDecode(
                                              responseBody,
                                            );
                                            errorMessage =
                                                errorData['message'] ??
                                                errorMessage;
                                          } catch (_) {}

                                          if (mounted) {
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
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้',
                                                style: TextStyle(
                                                  fontFamily: 'Kanit',
                                                ),
                                              ),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (mounted) {
                                          setStateDialog(() {
                                            isSubmitting = false;
                                          });
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0096C7),
                                disabledBackgroundColor: Colors.grey,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
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
                                        fontSize: 14,
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
                              onPressed: isSubmitting
                                  ? null
                                  : () => Navigator.pop(dialogContext),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB70000),
                                disabledBackgroundColor: Colors.grey,
                                foregroundColor: Colors.white,
                                elevation: 0,
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
          'เพิ่มห้องประชุม',
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
                  _buildImagePickerCard(),
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
                onPressed: () {
                  _showAddRoomConfirmDialog();
                },
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

  Widget _buildImagePickerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'เลือกรูปห้องประชุม',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
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
                    : null,
              ),
              child: _imageBytes == null
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
            controller: _roomNameController,
            decoration: InputDecoration(
              hintText: 'เช่น ห้องประชุมสายน้ำ ชั้น 1',
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
                        fontFamily: 'Kanit',
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
}
