// mobile_app/lib/Dashboard/dashboard_empty.dart

import 'package:flutter/material.dart';

class DashboardEmptyWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRefresh;

  const DashboardEmptyWidget({
    Key? key,
    this.message = 'ไม่มีข้อมูลในระบบ',
    this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRefresh != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('ลองใหม่อีกครั้ง'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
