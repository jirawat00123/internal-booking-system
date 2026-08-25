import 'package:flutter/material.dart';
import 'dart:convert'; // 🟢 เพิ่มสำหรับจัดการ JSON
import 'package:http/http.dart' as http; // 🟢 เพิ่มสำหรับยิง API
import 'auth_service.dart'; // 🟢 เพิ่มการนำเข้า AuthService เพื่อล้างเซสชันตอนกดออกจากระบบ

// 🏢 ฟีเจอร์จองห้องประชุม (User)
import 'package:mobile_app/Booking_room/Room_list.dart';

// 🚗 ฟีเจอร์จองยานพาหนะ (User)
import 'package:mobile_app/Booking_vehicle/vehicle_list.dart';

// 📦 ไฟล์แกนหลักและหน้าตั้งค่า
import 'package:mobile_app/Book_history.dart';
import 'package:mobile_app/Manage.dart';
import 'package:mobile_app/Select.dart';
import 'package:mobile_app/user_setting_page.dart';
import 'Dashboard/dashboard_page.dart';

class UserMenuPage extends StatelessWidget {
  // 🟢 รองรับการเข้าใช้งานในฐานะ Guest
  final bool isGuest;

  const UserMenuPage({super.key, this.isGuest = false});

  // ==============================================================
  // 🟢 1. ฟังก์ชันตรวจสอบคำขอรับรถก่อนเวลาเมื่อกดปุ่มกระดิ่งแจ้งเตือน
  // ==============================================================
  Future<void> _checkEarlyRelease(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    debugPrint(
      '[${DateTime.now().toIso8601String()}] ⏱️ [CheckEarlyRelease] Start triggered',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      debugPrint(
        '[${DateTime.now().toIso8601String()}] ⏱️ [CheckEarlyRelease] Fetching token...',
      );
      final token = await AuthService.instance.getToken();

      // 🟢 ถอดรหัส JWT Token เพื่อดึง userId ออกมาโดยตรง
      int? userId;
      if (token != null && token.isNotEmpty) {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payloadStr = utf8.decode(
            base64Url.decode(base64Url.normalize(parts[1])),
          );
          userId = jsonDecode(payloadStr)['userId'];
        }
      }
      debugPrint(
        '[${DateTime.now().toIso8601String()}] ⏱️ [CheckEarlyRelease] Parsed userId: $userId',
      );

      final String baseUrl = '${AuthService.baseUrl}/api/vehicle-bookings';
      final String notifUrl = '${AuthService.baseUrl}/api/notifications';

      Map<String, dynamic>? pendingEarlyRequest;
      int? notificationId;

      // 🟢 1. ดึงข้อมูลจาก Notification API ก่อนเพื่อตรวจคำขอที่ส่งมาจาก Backend
      debugPrint(
        '[${DateTime.now().toIso8601String()}] ⏱️ [CheckEarlyRelease] Requesting notifications API...',
      );
      final notifRes = await http.get(
        Uri.parse('$notifUrl?filter=UNREAD'),
        headers: {'Authorization': 'Bearer $token'},
      );
      debugPrint(
        '[${DateTime.now().toIso8601String()}] ⏱️ [CheckEarlyRelease] Notifications API status: ${notifRes.statusCode}',
      );

      if (notifRes.statusCode == 200) {
        final notifData = jsonDecode(notifRes.body);
        final List notifications = notifData is List
            ? notifData
            : (notifData is Map && notifData['data'] is List
                  ? notifData['data']
                  : []);

        final earlyNotif = notifications.firstWhere(
          (n) =>
              (n['title']?.toString().contains('ก่อนเวลา') == true ||
                  n['title']?.toString().contains('ขอปล่อยรถ') == true ||
                  n['title']?.toString().contains('ขอคืนรถ') == true ||
                  n['message']?.toString().contains('ก่อนเวลา') == true ||
                  n['message']?.toString().contains('ปล่อยรถ') == true ||
                  n['message']?.toString().contains('คืนรถ') == true ||
                  n['type'] == 'EARLY_RELEASE' ||
                  n['type'] == 'EARLY_RELEASE_REQUEST' ||
                  n['type'] == 'EARLY_RETURN' ||
                  n['type'] == 'EARLY_RETURN_REQUEST' ||
                  (n['type'] == 'APPROVAL' &&
                      (n['entityType'] == 'VEHICLE_BOOKING' ||
                          n['entity_id'] != null)) ||
                  n['action'] == 'EARLY_RELEASE' ||
                  n['action'] == 'EARLY_RELEASE_REQUEST' ||
                  n['action'] == 'EARLY_RETURN' ||
                  n['action'] == 'EARLY_RETURN_REQUEST') &&
              (n['isRead'] != true && n['is_read'] != true),
          orElse: () => null,
        );

        if (earlyNotif != null) {
          debugPrint(
            '[${DateTime.now().toIso8601String()}] ⏱️ [CheckEarlyRelease] Early notification matched! ID: ${earlyNotif['id']}',
          );
          notificationId = earlyNotif['id'];
          final bookingId = earlyNotif['entityId'] ?? earlyNotif['entity_id'];
          if (bookingId != null) {
            debugPrint(
              '[${DateTime.now().toIso8601String()}] ⏱️ [CheckEarlyRelease] Requesting booking detail for ID: $bookingId',
            );
            final detailRes = await http.get(
              Uri.parse('$baseUrl/$bookingId'),
              headers: {'Authorization': 'Bearer $token'},
            );
            if (detailRes.statusCode == 200) {
              final body = jsonDecode(detailRes.body);
              pendingEarlyRequest = body is Map && body.containsKey('data')
                  ? body['data']
                  : body;
            }
          }
        }
      }

      // 🟢 2. หากไม่พบใน Notification ให้ Fallback ไปเช็คที่ Vehicle Booking History
      if (pendingEarlyRequest == null) {
        debugPrint(
          '[${DateTime.now().toIso8601String()}] ⏱️ [CheckEarlyRelease] Fallback to History API...',
        );
        final historyRes = await http.get(
          Uri.parse('$baseUrl/history?userId=$userId'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (historyRes.statusCode == 200) {
          final historyData = jsonDecode(historyRes.body);
          final List bookings = historyData is List
              ? historyData
              : (historyData is Map && historyData['data'] is List
                    ? historyData['data']
                    : []);

          final activeBookings = bookings
              .where(
                (b) =>
                    b['status'] != 'CANCELLED' &&
                    b['status'] != 'COMPLETED' &&
                    b['status'] != 'REJECTED',
              )
              .toList();

          for (var booking in activeBookings) {
            if (booking['isEarlyReleaseRequested'] == true ||
                booking['is_early_release_requested'] == true ||
                booking['isEarlyReturnRequested'] == true ||
                booking['is_early_return_requested'] == true) {
              pendingEarlyRequest = booking;
              break;
            }
            debugPrint(
              '[${DateTime.now().toIso8601String()}] ⏱️ [CheckEarlyRelease] Fallback fetching booking detail ID: ${booking['id']}',
            );
            final detailRes = await http.get(
              Uri.parse('$baseUrl/${booking['id']}'),
              headers: {'Authorization': 'Bearer $token'},
            );
            if (detailRes.statusCode == 200) {
              final detailData = jsonDecode(detailRes.body);
              final data = detailData is Map && detailData.containsKey('data')
                  ? detailData['data']
                  : detailData;
              if (data['isEarlyReleaseRequested'] == true ||
                  data['is_early_release_requested'] == true ||
                  data['isEarlyReturnRequested'] == true ||
                  data['is_early_return_requested'] == true) {
                pendingEarlyRequest = data;
                break;
              }
            }
          }
        }
      }

      debugPrint(
        '[${DateTime.now().toIso8601String()}] ⏱️ [CheckEarlyRelease] Completed checking. Dismissing loader...',
      );
      if (navigator.canPop()) navigator.pop(); // ปิด Loading

      if (pendingEarlyRequest != null) {
        if (!context.mounted) return;
        debugPrint(
          '[${DateTime.now().toIso8601String()}] ⏱️ [CheckEarlyRelease] Displaying Approval Dialog',
        );
        _showApprovalDialog(
          context,
          pendingEarlyRequest,
          token,
          baseUrl,
          notificationId: notificationId,
        );
      } else {
        if (!context.mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'ไม่มีการแจ้งเตือนคำขอรับรถก่อนเวลาในขณะนี้',
              style: TextStyle(fontFamily: 'Kanit'),
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint(
        '[${DateTime.now().toIso8601String()}] ❌ [CheckEarlyRelease] Exception: $e',
      );
      debugPrint(stackTrace.toString());
      if (navigator.canPop()) navigator.pop();
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    }
  }

  // ==============================================================
  // 🟢 2. ฟังก์ชันแสดง Dialog ให้ผู้จองกด ยินยอม / ปฏิเสธ
  // ==============================================================
  void _showApprovalDialog(
    BuildContext context,
    Map<String, dynamic> booking,
    String? token,
    String baseUrl, {
    int? notificationId,
  }) {
    bool isEarlyReturn = booking['isEarlyReturnRequested'] == true || booking['is_early_return_requested'] == true;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isEarlyReturn ? '⚠️ คำขอคืนรถก่อนเวลา' : '⚠️ คำขอรับรถก่อนเวลา',
          style: const TextStyle(fontFamily: 'Kanit', fontWeight: FontWeight.bold),
        ),
        content: Text(
          isEarlyReturn
              ? 'รปภ. แจ้งขอคืนรถคันนี้ก่อนเวลาที่กำหนดไว้\n\nรหัสการจอง: ${booking['id']}\nปลายทาง: ${booking['destination'] ?? 'ไม่ระบุ'}\n\nคุณต้องการยินยอมคืนรถก่อนเวลาหรือไม่?'
              : 'รปภ. แจ้งขอปล่อยรถคันนี้ก่อนเวลาที่กำหนดไว้\n\nรหัสการจอง: ${booking['id']}\nปลายทาง: ${booking['destination'] ?? 'ไม่ระบุ'}\n\nคุณต้องการยินยอมรับรถก่อนเวลาหรือไม่?',
          style: const TextStyle(fontFamily: 'Kanit'),
        ),
        actions: [
          TextButton(
            onPressed: () => _respondEarlyRelease(
              context,
              booking['id'],
              'REJECT',
              token,
              baseUrl,
              notificationId: notificationId,
              isEarlyReturn: isEarlyReturn,
            ),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(
              'ปฏิเสธ (รอเวลาเดิม)',
              style: TextStyle(
                fontFamily: 'Kanit',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => _respondEarlyRelease(
              context,
              booking['id'],
              'APPROVE',
              token,
              baseUrl,
              notificationId: notificationId,
              isEarlyReturn: isEarlyReturn,
            ),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(
              isEarlyReturn ? 'ยินยอม (คืนรถทันที)' : 'ยินยอม (รับรถทันที)',
              style: const TextStyle(
                fontFamily: 'Kanit',
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // 🟢 3. ฟังก์ชันยิง API ส่งคำตอบกลับไปหา Backend
  // ==============================================================
  Future<void> _respondEarlyRelease(
    BuildContext context,
    int bookingId,
    String action,
    String? token,
    String baseUrl, {
    int? notificationId,
    bool isEarlyReturn = false,
  }) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    debugPrint(
      '[${DateTime.now().toIso8601String()}] ⏱️ [RespondEarlyRelease] Action: $action, BookingID: $bookingId, isEarlyReturn: $isEarlyReturn',
    );
    if (navigator.canPop()) navigator.pop(); // ปิด Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 🟢 1. หากมี notificationId ให้ส่งคำตอบกลับไปยัง Notification API
      if (notificationId != null) {
        debugPrint(
          '[${DateTime.now().toIso8601String()}] ⏱️ [RespondEarlyRelease] Responding to Notification API ID: $notificationId',
        );
        await http.post(
          Uri.parse(
            '${AuthService.baseUrl}/api/notifications/$notificationId/respond',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'action': action}),
        );
      }

      // 🟢 2. ส่งคำตอบกลับไปยัง Vehicle Booking API
      debugPrint(
        '[${DateTime.now().toIso8601String()}] ⏱️ [RespondEarlyRelease] Posting early response to Booking API',
      );
      
      String endpoint = isEarlyReturn ? 'early-return-respond' : 'early-respond';
      final res = await http.post(
        Uri.parse('$baseUrl/$bookingId/$endpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'action': action}),
      );

      debugPrint(
        '[${DateTime.now().toIso8601String()}] ⏱️ [RespondEarlyRelease] Booking API status: ${res.statusCode}',
      );
      if (navigator.canPop()) navigator.pop(); // ปิด Loading

      if (!context.mounted) return;
      if (res.statusCode == 200) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              action == 'APPROVE'
                  ? (isEarlyReturn ? 'อนุมัติการคืนรถก่อนเวลาสำเร็จ!' : 'อนุมัติการรับรถก่อนเวลาสำเร็จ!')
                  : 'ปฏิเสธคำขอสำเร็จ!',
              style: const TextStyle(fontFamily: 'Kanit'),
            ),
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('ทำรายการไม่สำเร็จ กรุณาลองใหม่')),
        );
      }
    } catch (e, stackTrace) {
      debugPrint(
        '[${DateTime.now().toIso8601String()}] ❌ [RespondEarlyRelease] Exception: $e',
      );
      debugPrint(stackTrace.toString());
      if (navigator.canPop()) navigator.pop();
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ==========================================
          // Layer 1: Background Image
          // ==========================================
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF00529B),
              image: DecorationImage(
                image: AssetImage('assets/images/bgmmk.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // ==========================================
          // Layer 2: Main Content
          // ==========================================
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Image.asset(
                              'assets/images/MMK_logo.png',
                              height: 100,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: 300,
                              height: 2,
                              color: Colors.white.withOpacity(0.7),
                            ),
                            const SizedBox(height: 40),
                            const Text(
                              'ยินดีต้อนรับ',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'Kanit',
                              ),
                            ),
                            const SizedBox(height: 6),
                            // 🟢 ข้อความต้อนรับปรับเปลี่ยนตามสถานะ Guest
                            Text(
                              isGuest
                                  ? 'โหมดผู้เยี่ยมชม (ดูได้อย่างเดียว)'
                                  : 'โปรดเลือกรายการเข้าทำเพื่อดำเนินการต่อ',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.8),
                                fontFamily: 'Kanit',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 🏢 เมนูที่ 1: ห้องประชุม
                    SelectionCard(
                      icon: Icons.groups_outlined,
                      title: 'ห้องประชุม',
                      subtitle: isGuest
                          ? 'ตารางการใช้ห้องประชุม'
                          : 'จองห้องประชุม',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                RoomListScreen(isGuest: isGuest),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // 🚗 เมนูที่ 2: ยานพาหนะ
                    SelectionCard(
                      icon: Icons.directions_car_filled_outlined,
                      title: 'ยานพาหนะ',
                      subtitle: isGuest ? 'ตารางการใช้ยานพาหนะ' : 'จองรถ',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                VehicleBooking(isGuest: isGuest),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // 📜 เมนูที่ 3: ประวัติการจอง (โชว์เฉพาะผู้ใช้งานปกติ)
                    if (!isGuest) ...[
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const BookingHistoryScreen(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.history,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text(
                            'ประวัติการจอง',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontFamily: 'Kanit',
                            ),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.3),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 50),
                    ] else ...[
                      const SizedBox(height: 30),
                    ],

                    // Footer
                    Center(
                      child: Column(
                        children: [
                          Container(
                            height: 1.5,
                            width: 300,
                            color: Colors.white.withOpacity(0.4),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'MENAM MECHANIKA © 2026',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                              fontFamily: 'Kanit',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),

          // ==========================================
          // Layer 3: Top Right Actions (Setting & Logout)
          // ==========================================
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0, top: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🔔 ปุ่มแจ้งเตือน (เช็คคำขอรับรถก่อนเวลา)
                    if (!isGuest)
                      IconButton(
                        icon: const Icon(
                          Icons.notifications_active,
                          color: Colors.amber, // สีเหลืองทองให้สังเกตเห็นชัดเจน
                          size: 28,
                        ),
                        onPressed: () => _checkEarlyRelease(context),
                      ),
                    // ⚙️ ปุ่มตั้งค่า (โชว์เฉพาะผู้ใช้งานปกติ)
                    if (!isGuest)
                      IconButton(
                        icon: const Icon(
                          Icons.settings_outlined,
                          color: Colors.white,
                          size: 26,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UserSettingPage(),
                            ),
                          );
                        },
                      ),
                    // 🚪 ปุ่ม Logout
                    IconButton(
                      icon: const Icon(
                        Icons.logout,
                        color: Colors.white,
                        size: 26,
                      ),
                      onPressed: () async {
                        // 🟢 1. เคลียร์ข้อมูลเซสชันทั้งหมดแบบ 100% (ล้างทั้ง Memory และ Storage)
                        await AuthService.instance.logout();

                        if (!context.mounted) return;

                        // 🟢 2. กลับไปหน้าแรกและเคลียร์ Stack ทิ้งป้องกัน State ค้าง
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginSelectionPage(),
                          ),
                          (route) => false,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// Custom Widget: SelectionCard
// ==========================================
class SelectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const SelectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 14.0,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F1F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 28, color: const Color(0xFF00529B)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontFamily: 'Kanit',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontFamily: 'Kanit',
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F1F5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Color(0xFF00529B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
