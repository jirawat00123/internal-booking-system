// mobile_app/lib/Dashboard/dashboard_chart.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardPieChartWidget extends StatelessWidget {
  final String title;
  final Map<String, int> dataMap;

  const DashboardPieChartWidget({
    Key? key,
    required this.title,
    required this.dataMap,
  }) : super(key: key);

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return Colors.green;
      case 'PENDING':
        return Colors.orange;
      case 'REJECTED':
      case 'CANCELLED':
        return Colors.red;
      case 'IN_USE':
        return Colors.blue;
      case 'COMPLETED':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (dataMap.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              const Center(
                child: Text(
                  'ไม่มีข้อมูลสถิติ',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      );
    }

    final total = dataMap.values.fold(0, (sum, val) => sum + val);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 30,
                        sections: dataMap.entries.map((entry) {
                          final double percentage = total > 0
                              ? (entry.value / total) * 100
                              : 0;
                          return PieChartSectionData(
                            color: _getStatusColor(entry.key),
                            value: entry.value.toDouble(),
                            title: '${percentage.toStringAsFixed(0)}%',
                            radius: 35,
                            titleStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: dataMap.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _getStatusColor(entry.key),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${entry.key}: ${entry.value}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
