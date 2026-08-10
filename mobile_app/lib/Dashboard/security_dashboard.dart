// mobile_app/lib/Dashboard/security_dashboard.dart

import 'package:flutter/material.dart';
import 'dashboard_model.dart';
import 'dashboard_card.dart';

class SecurityDashboardView extends StatelessWidget {
  final SecurityDashboardData data;
  final VoidCallback onRefresh;

  const SecurityDashboardView({
    Key? key,
    required this.data,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'การจัดการยานพาหนะประจำวัน (Security)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Security Metrics
            GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.9,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                DashboardCardWidget(
                  title: 'กำลังใช้งาน',
                  value: '${data.vehiclesInUse}',
                  icon: Icons.time_to_leave,
                  color: Colors.blue,
                ),
                DashboardCardWidget(
                  title: 'เบิกออกวันนี้',
                  value: '${data.todayCheckoutCount}',
                  icon: Icons.output,
                  color: Colors.orange,
                ),
                DashboardCardWidget(
                  title: 'รอส่งคืน',
                  value: '${data.waitingReturnCount}',
                  icon: Icons.input,
                  color: Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Today Activity Logs
            const Text(
              'รายการเบิก-คืนวันนี้',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (data.todayLogs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text(
                    'ไม่มีรายการเบิก-คืนในวันนี้',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: data.todayLogs.length,
                itemBuilder: (context, index) {
                  final log = data.todayLogs[index];
                  final vehicle = log['vehicle']?['model'] ?? 'ไม่ระบุยานพาหนะ';
                  final license = log['vehicle']?['licensePlate'] ?? '';
                  final user = log['user']?['username'] ?? 'ไม่ระบุผู้ใช้';
                  final status = log['status'] ?? '';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: status == 'IN_USE'
                            ? Colors.blue.shade100
                            : Colors.green.shade100,
                        child: Icon(
                          status == 'IN_USE'
                              ? Icons.directions_car
                              : Icons.check,
                          color: status == 'IN_USE'
                              ? Colors.blue
                              : Colors.green,
                        ),
                      ),
                      title: Text('$vehicle ($license)'),
                      subtitle: Text('ผู้เบิก: $user | สถานะ: $status'),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
