import 'package:flutter/material.dart';
import 'notification_repository.dart';
import 'notification_constants.dart';

class NotificationBadge extends StatefulWidget {
  final VoidCallback? onTap;
  final Color? iconColor;

  const NotificationBadge({Key? key, this.onTap, this.iconColor})
    : super(key: key);

  @override
  State<NotificationBadge> createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<NotificationBadge> {
  final NotificationRepository _repository = NotificationRepository();
  int _unreadCount = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchUnreadCount();
  }

  /// ดึงจำนวน Unread Count จาก Repository
  Future<void> _fetchUnreadCount({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final count = await _repository.getUnreadCount(
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _unreadCount = count;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// แปลงตัวเลขเป็น String ตามเงื่อนไข (ถ้าเกิน 99 แสดง '99+')
  String get _badgeText {
    if (_unreadCount > NotificationConstants.maxBadgeCount) {
      return NotificationConstants.badgePlusText;
    }
    return '$_unreadCount';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: Icon(
            Icons.notifications_outlined,
            color: widget.iconColor ?? theme.colorScheme.onSurface,
            size: 26,
          ),
          tooltip: 'Notifications',
          onPressed: () async {
            if (widget.onTap != null) {
              widget.onTap!();
            } else {
              // Navigation ไปหน้า Notification Center
              await Navigator.pushNamed(context, '/notifications');
              // เมื่อกดกลับมาจากหน้า Notification ให้ Refresh จำนวน Unread Count
              if (mounted) {
                _fetchUnreadCount(forceRefresh: true);
              }
            }
          },
        ),
        if (_unreadCount > 0)
          Positioned(
            top: 6,
            right: 6,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  _badgeText,
                  style: TextStyle(
                    color: theme.colorScheme.onError,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
