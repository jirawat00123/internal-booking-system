// Room_model.dart

// คลาสโมเดลสำหรับเก็บข้อมูลห้องประชุม
class MeetingRoom {
  final String id;
  final String floor;
  final String side;
  final int capacity;
  final String? imagePath; // รองรับค่า null กรณีที่ยังไม่มีการอัปโหลดรูปภาพ
  final String
  status; // ปรับเป็น final เพื่อให้เป็น Immutable Data ป้องกันบั๊กการแก้ไขข้อมูลผิดพลาด

  MeetingRoom({
    required this.id,
    required this.floor,
    required this.side,
    required this.capacity,
    this.imagePath, // ไม่ต้องบังคับ required เพราะสามารถเป็นค่าว่างได้
    this.status = 'ว่างพร้อมใช้งาน', // ค่าเริ่มต้น
  });

  // ฟังก์ชันสำหรับก๊อปปี้ข้อมูลและเปลี่ยนบางค่า (Best Practice สำหรับการแก้ไข State)
  MeetingRoom copyWith({
    String? id,
    String? floor,
    String? side,
    int? capacity,
    String? imagePath,
    String? status,
  }) {
    return MeetingRoom(
      id: id ?? this.id,
      floor: floor ?? this.floor,
      side: side ?? this.side,
      capacity: capacity ?? this.capacity,
      imagePath: imagePath ?? this.imagePath,
      status: status ?? this.status,
    );
  }
}
