// lib/Notification/widgets/notification_empty.dart

import 'package:flutter/material.dart';

class NotificationEmpty extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const NotificationEmpty({
    Key? key,
    this.title = 'ไม่มีการแจ้งเตือน',
    this.message =
        'คุณอ่านการแจ้งเตือนทั้งหมดแล้ว\nหรือยังไม่มีรายการใหม่ในขณะนี้',
    this.icon = Icons.notifications_off_outlined,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ใช้ Layout แบบ Center เพื่อให้อยู่ตรงกลางหน้าจอเสมอ
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ไอคอนขนาดใหญ่สีเทาอ่อน (Muted)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                  0.5,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 24),

            // หัวข้อหลัก
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // คำอธิบายเพิ่มเติม
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
