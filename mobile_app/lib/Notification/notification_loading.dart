// lib/Notification/widgets/notification_loading.dart

import 'package:flutter/material.dart';

class NotificationLoading extends StatelessWidget {
  final int itemCount;

  const NotificationLoading({
    Key? key,
    this.itemCount = 5, // จำนวน Card จำลองที่จะแสดงตอนโหลด
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // ใช้สีเทาอ่อนๆ จาก Theme เพื่อทำเป็น Skeleton Box
    final skeletonColor = theme.colorScheme.onSurface.withOpacity(0.1);

    return ListView.builder(
      itemCount: itemCount,
      padding: const EdgeInsets.symmetric(vertical: 8),
      // ไม่ต้องสนใจ Scroll เพราะเป็นแค่ State ชั่วคราว
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Skeleton สำหรับ Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: skeletonColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                
                // 2. Skeleton สำหรับ Content (Title, Message, Time)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Container(
                        height: 16,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: skeletonColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Message (ความยาวประมาณ 60% ของจอ)
                      Container(
                        height: 14,
                        width: MediaQuery.of(context).size.width * 0.6,
                        decoration: BoxDecoration(
                          color: skeletonColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Time
                      Container(
                        height: 12,
                        width: 80,
                        decoration: BoxDecoration(
                          color: skeletonColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}