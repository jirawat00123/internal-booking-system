// lib/Notification/notification_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'notification_repository.dart';
import 'notification_model.dart';
import 'notification_constants.dart';
import 'notification_card.dart';
import 'notification_loading.dart';
import 'notification_empty.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({Key? key}) : super(key: key);

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final NotificationRepository _repository = NotificationRepository();
  final ScrollController _scrollController = ScrollController();

  List<NotificationModel> _notifications = [];
  int _currentPage = 1;
  final int _limit = 15;

  bool _isLoading = true; // โหลดครั้งแรกหรือดึงใหม่ทั้งหมด
  bool _isFetchingMore = false; // โหลดหน้าถัดไป (Pagination)
  bool _hasMore = true; // มีข้อมูลหน้าถัดไปอีกหรือไม่

  @override
  void initState() {
    super.initState();
    _fetchNotifications(isRefresh: true);

    // ดักจับ Event การ Scroll เพื่อทำ Infinite Scroll
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100) {
        _fetchNotifications(isRefresh: false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// ดึงข้อมูลการแจ้งเตือนจาก Repository
  Future<void> _fetchNotifications({bool isRefresh = false}) async {
    if (isRefresh) {
      _currentPage = 1;
      _hasMore = true;
      setState(() => _isLoading = true);
    } else {
      if (!_hasMore || _isFetchingMore || _isLoading) return;
      setState(() => _isFetchingMore = true);
    }

    try {
      final newItems = await _repository.getNotifications(
        page: _currentPage,
        limit: _limit,
        forceRefresh: isRefresh,
      );

      setState(() {
        if (isRefresh) {
          _notifications = newItems;
        } else {
          _notifications.addAll(newItems);
        }

        // ถ้าข้อมูลที่ได้มาน้อยกว่า limit แปลว่าหมดแล้ว
        if (newItems.length < _limit) {
          _hasMore = false;
        } else {
          _currentPage++;
        }
      });
    } catch (e) {
      // จัดการ Error (เช่น แสดง SnackBar)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ไม่สามารถโหลดการแจ้งเตือนได้: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFetchingMore = false;
        });
      }
    }
  }

  /// เมื่อผู้ใช้กดที่การแจ้งเตือน
  Future<void> _onNotificationTap(
    NotificationModel notification,
    int index,
  ) async {
    // 1. Update UI ทันทีว่าอ่านแล้ว (Optimistic Update) เพื่อ UX ที่ลื่นไหล
    if (!notification.isRead) {
      setState(() {
        _notifications[index] = NotificationModel(
          id: notification.id,
          title: notification.title,
          message: notification.message,
          type: notification.type,
          entityType: notification.entityType,
          entityId: notification.entityId,
          isRead: true, // ตั้งเป็นอ่านแล้ว
          createdAt: notification.createdAt,
          permissions: notification.permissions,
        );
      });
      // ยิง API อัปเดตสถานะ (ไม่รอดูก็ได้ เพราะเราอัปเดต UI ไปแล้ว)
      _repository.markAsRead(notification.id.toString());
    }

    // 2. Navigation ไปยังหน้าที่ถูกต้องโดยอ้างอิงจาก Entity Type
    // (Flutter = Dumb UI: ให้ Constants แปลง Type เป็น Route ห้าม if(role=="ADMIN") ที่นี่)
    final targetRoute = NotificationConstants.getRouteForEntity(
      notification.entityType,
    );

    // ส่ง entityId ผ่าน arguments ไปยังหน้า Detail
    Navigator.pushNamed(context, targetRoute, arguments: notification.entityId);
  }

  /// Mark all as read
  Future<void> _markAllAsRead() async {
    final success = await _repository.markAllAsRead();
    if (success) {
      _fetchNotifications(isRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('การแจ้งเตือน'),
        actions: [
          // ปุ่มสำหรับอ่านทั้งหมด
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'ทำเครื่องหมายว่าอ่านแล้วทั้งหมด',
              onPressed: _markAllAsRead,
            ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Future<void> _respondEarlyRelease(
    dynamic bookingId,
    bool approved, {
    bool isEarlyReturn = false,
  }) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      String token =
          prefs.getString('token') ?? prefs.getString('jwt_token') ?? '';

      String baseUrl = kIsWeb
          ? 'https://192.168.88.25:3002'
          : 'https://192.168.88.25:3002';

      String endpoint = isEarlyReturn
          ? 'early-return-respond'
          : 'early-respond';
      final response = await http.post(
        Uri.parse('$baseUrl/api/vehicle-bookings/$bookingId/$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'approved': approved}),
      );

      if (navigator.canPop()) navigator.pop();
      if (!mounted) return;

      final resData = json.decode(response.body);
      if (response.statusCode == 200) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              resData['message'] ?? 'บันทึกคำตอบเรียบร้อยแล้ว',
              style: const TextStyle(fontFamily: 'Kanit'),
            ),
            backgroundColor: approved ? Colors.green : Colors.red,
          ),
        );
        _fetchNotifications(isRefresh: true);
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              resData['error'] ?? 'เกิดข้อผิดพลาด',
              style: const TextStyle(fontFamily: 'Kanit'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (navigator.canPop()) navigator.pop();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'เชื่อมต่อเซิร์ฟเวอร์ผิดพลาด',
            style: TextStyle(fontFamily: 'Kanit'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const NotificationLoading();
    }

    if (_notifications.isEmpty) {
      return const NotificationEmpty();
    }

    return RefreshIndicator(
      onRefresh: () => _fetchNotifications(isRefresh: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _notifications.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          // ถ้าเป็นรายการสุดท้ายและยังมีหน้าถัดไป ให้แสดง Loading Indicator เล็กๆ ท้ายลิสต์
          if (index == _notifications.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final notification = _notifications[index];

          // 🟢 เปลี่ยนมาเช็คด้วย type ที่ Backend ส่งมาให้รัดกุม 100%
          final bool isEarlyReleaseRequest =
              notification.type == 'EARLY_RELEASE_REQUEST' ||
              notification.title.contains('คำขอรับรถก่อนเวลา');

          final bool isEarlyReturnRequest =
              notification.type == 'EARLY_RETURN_REQUEST' ||
              notification.title.contains('คำขอคืนรถก่อนเวลา');

          return Column(
            children: [
              NotificationCard(
                notification: notification,
                onTap: () => _onNotificationTap(notification, index),
              ),
              // 🟢 แก้ไข .entityId != null เป็น .isNotEmpty เพราะใน Model เป็น String
              if ((isEarlyReleaseRequest || isEarlyReturnRequest) &&
                  notification.entityId.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 4.0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _respondEarlyRelease(
                            notification
                                .entityId, // 🟢 เอาเครื่องหมาย ! ออก ป้องกัน Compile Error
                            true,
                            isEarlyReturn: isEarlyReturnRequest,
                          ),
                          icon: const Icon(Icons.check, size: 18),
                          label: Text(
                            isEarlyReturnRequest
                                ? 'ยินยอมคืนรถ'
                                : 'ยินยอมรับรถ',
                            style: const TextStyle(fontFamily: 'Kanit'),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _respondEarlyRelease(
                            notification.entityId, // 🟢 เอาเครื่องหมาย ! ออก
                            false,
                            isEarlyReturn: isEarlyReturnRequest,
                          ),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text(
                            'ปฏิเสธ',
                            style: TextStyle(fontFamily: 'Kanit'),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
