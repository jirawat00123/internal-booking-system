import 'package:flutter/material.dart';
import 'notification_model.dart';
import 'notification_constants.dart';

class NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const NotificationCard({
    Key? key,
    required this.notification,
    required this.onTap,
  }) : super(key: key);

  /// Helper แปลงวันที่เป็น Relative Time (เช่น '2 ชั่วโมงที่แล้ว')
  String _formatRelativeTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 7) {
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    }
    if (difference.inDays > 0) return '${difference.inDays} วันที่แล้ว';
    if (difference.inHours > 0) return '${difference.inHours} ชั่วโมงที่แล้ว';
    if (difference.inMinutes > 0) return '${difference.inMinutes} นาทีที่แล้ว';
    return 'เมื่อสักครู่';
  }

  /// Helper เลือก Icon ตาม Entity Type หรือ Action
  IconData _getIconData() {
    switch (notification.entityType.toUpperCase()) {
      case NotificationConstants.entityRoom:
        return Icons.meeting_room_outlined;
      case NotificationConstants.entityVehicle:
        return Icons.directions_car_outlined;
      case NotificationConstants.entitySystem:
        return Icons.system_update_alt_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  /// Helper เลือกสี Icon (สามารถนำไปผูกกับ Theme ได้)
  Color _getIconColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (notification.type == NotificationConstants.actionApproval) {
      return colorScheme.error; // แจ้งเตือนรอการอนุมัติมักต้องการความสนใจ
    }
    return colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnread = !notification.isRead;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      // ถ้ายังไม่ได้อ่าน ให้สีพื้นหลังแตกต่างเล็กน้อย
      color: isUnread
          ? theme.colorScheme.primaryContainer.withOpacity(0.3)
          : theme.colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Icon ของ Notification
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getIconColor(context).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIconData(),
                  color: _getIconColor(context),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // 2. เนื้อหา (Title, Message, Time)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: isUnread
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatRelativeTime(notification.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),

              // 3. จุดสี (Unread Indicator)
              if (isUnread) ...[
                const SizedBox(width: 8),
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
