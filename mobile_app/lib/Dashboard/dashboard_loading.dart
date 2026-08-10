// mobile_app/lib/Dashboard/dashboard_loading.dart

import 'package:flutter/material.dart';

class DashboardLoadingWidget extends StatelessWidget {
  const DashboardLoadingWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'กำลังโหลดข้อมูลแดชบอร์ด...',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
