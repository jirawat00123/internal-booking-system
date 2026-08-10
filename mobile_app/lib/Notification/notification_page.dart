// lib/Notification/notification_page.dart

import 'package:flutter/material.dart';
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
          return NotificationCard(
            notification: notification,
            onTap: () => _onNotificationTap(notification, index),
          );
        },
      ),
    );
  }
}
