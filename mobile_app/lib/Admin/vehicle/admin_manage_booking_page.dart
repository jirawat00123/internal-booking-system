import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app/Booking_vehicle/driver_model.dart';

class AdminManageBookingPage extends StatefulWidget {
  const AdminManageBookingPage({super.key});

  @override
  State<AdminManageBookingPage> createState() => _AdminManageBookingPageState();
}

class _AdminManageBookingPageState extends State<AdminManageBookingPage> {
  bool _isLoading = false;
  List<dynamic> _pendingBookings = [];
  List<dynamic> _allBookings = [];
  List<CompanyDriver> _companyDrivers = [];
  final Map<int, int?> _selectedDrivers = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ??
        prefs.getString('jwt_token') ??
        prefs.getString('jwt') ??
        prefs.getString('accessToken') ??
        prefs.getString('auth_token') ??
        '';
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final token = await _getToken();
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final driverRes = await http.get(
        Uri.parse('https://192.168.88.25:3002/api/company-drivers'),
        headers: headers,
      );
      if (driverRes.statusCode == 200) {
        final driverData = json.decode(driverRes.body);
        final List dList =
            driverData['data'] ?? (driverData is List ? driverData : []);
        final parsedDrivers = dList
            .map((e) => CompanyDriver.fromJson(e))
            .toList();
        final seenIds = <int>{};
        _companyDrivers = parsedDrivers
            .where((d) => seenIds.add(d.id))
            .toList();
      }

      final bookingRes = await http.get(
        Uri.parse('https://192.168.88.25:3002/api/vehicle-bookings'),
        headers: headers,
      );

      if (bookingRes.statusCode == 200) {
        final bookingData = json.decode(bookingRes.body);
        final List bList =
            bookingData['data'] ??
            bookingData['bookings'] ??
            (bookingData is List ? bookingData : []);

        debugPrint('Total bookings from API: ${bList.length}');

        _allBookings = bList;

        _pendingBookings = bList.where((b) {
          final String driverType =
              b['driverType']?.toString().toUpperCase() ?? '';
          final String status = b['status']?.toString().toUpperCase() ?? '';
          final companyDriverId =
              b['driverEmployeeId'] ??
              b['companyDriverId'] ??
              b['driver_employee_id'] ??
              b['company_driver_id'] ??
              (b['driverEmployee'] is Map ? b['driverEmployee']['id'] : null) ??
              (b['companyDriver'] is Map ? b['companyDriver']['id'] : null);

          final bool isCompany =
              driverType.contains('COMPANY') ||
              driverType.contains('บริษัท') ||
              driverType.contains('พนักงานขับรถ');

          final bool isValidStatus =
              status == 'PENDING' ||
              status == 'APPROVED' ||
              status == 'RESERVED' ||
              status == 'ถูกจองไว้อยู่';

          final bool needsDriver =
              companyDriverId == null ||
              companyDriverId == 0 ||
              companyDriverId == '' ||
              companyDriverId.toString() == 'null';

          return isCompany && isValidStatus && needsDriver;
        }).toList();

        debugPrint('Filtered pending bookings: ${_pendingBookings.length}');
      }
    } catch (e) {
      debugPrint('Error loading manage booking data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<dynamic> _getDriverConflictingBookings(
    dynamic currentBooking,
    int driverId,
  ) {
    List<dynamic> conflicts = [];
    try {
      final String startStr =
          currentBooking['startDatetime'] ?? currentBooking['startDate'] ?? '';
      final String endStr =
          currentBooking['endDatetime'] ?? currentBooking['endDate'] ?? '';
      if (startStr.isEmpty || endStr.isEmpty) return conflicts;

      final DateTime newStart = DateTime.parse(startStr.toString()).toLocal();
      final DateTime newEnd = DateTime.parse(endStr.toString()).toLocal();

      for (var existing in _allBookings) {
        if (existing['id'] != null &&
            currentBooking['id'] != null &&
            existing['id'].toString() == currentBooking['id'].toString()) {
          continue;
        }

        final String status =
            existing['status']?.toString().toUpperCase() ?? '';
        if (status == 'CANCELLED' ||
            status == 'CANCEL' ||
            status == 'REJECTED' ||
            status == 'COMPLETED' ||
            status == 'ยกเลิกแล้ว' ||
            status == 'เสร็จสิ้น') {
          continue;
        }

        final existingDriverId =
            existing['companyDriverId'] ??
            existing['driverEmployeeId'] ??
            existing['driver_employee_id'] ??
            existing['company_driver_id'] ??
            (existing['driverEmployee'] is Map
                ? existing['driverEmployee']['id']
                : null) ??
            (existing['companyDriver'] is Map
                ? existing['companyDriver']['id']
                : null);

        if (existingDriverId != null &&
            existingDriverId.toString() == driverId.toString()) {
          final String exStartStr =
              existing['startDatetime'] ?? existing['startDate'] ?? '';
          final String exEndStr =
              existing['endDatetime'] ?? existing['endDate'] ?? '';
          if (exStartStr.isNotEmpty && exEndStr.isNotEmpty) {
            final DateTime existingStart = DateTime.parse(
              exStartStr.toString(),
            ).toLocal();
            final DateTime existingEnd = DateTime.parse(
              exEndStr.toString(),
            ).toLocal();

            if (newStart.isBefore(existingEnd) &&
                newEnd.isAfter(existingStart)) {
              conflicts.add(existing);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking driver conflict: $e');
    }
    return conflicts;
  }

  Future<void> _assignDriver(int bookingId, int companyDriverId) async {
    final currentBooking = _pendingBookings.firstWhere(
      (b) => b['id'] == bookingId,
      orElse: () => null,
    );

    if (currentBooking != null) {
      final conflicts = _getDriverConflictingBookings(
        currentBooking,
        companyDriverId,
      );
      if (conflicts.isNotEmpty) {
        final conflict = conflicts.first;
        final DateTime start = DateTime.parse(
          (conflict['startDatetime'] ?? conflict['startDate']).toString(),
        ).toLocal();
        final DateTime end = DateTime.parse(
          (conflict['endDatetime'] ?? conflict['endDate']).toString(),
        ).toLocal();

        String formatDateTime(DateTime dt) {
          return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year + 543} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        }

        final String detailMsg =
            'คนขับมีคิวงานซ้อนในช่วงเวลานี้\n(คิวเดิม: ${formatDateTime(start)} - ${formatDateTime(end)})';

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                detailMsg,
                style: const TextStyle(fontFamily: 'Kanit'),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    try {
      final token = await _getToken();
      final response = await http.put(
        Uri.parse(
          'https://192.168.88.25:3002/api/vehicle-bookings/$bookingId/assign-driver',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'driverType': 'COMPANY',
          'companyDriverId': companyDriverId,
          'driverEmployeeId': companyDriverId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'จัดสรรพนักงานขับรถเรียบร้อยแล้ว',
                style: TextStyle(fontFamily: 'Kanit'),
              ),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            _pendingBookings.removeWhere((item) => item['id'] == bookingId);
            _selectedDrivers.remove(bookingId);
          });
        }
        await _loadData();
      } else {
        final err = json.decode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                err['error'] ?? err['message'] ?? 'เกิดข้อผิดพลาดในการบันทึก',
                style: const TextStyle(fontFamily: 'Kanit'),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Assign driver error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'เกิดข้อผิดพลาดในการเชื่อมต่อเครือข่าย',
              style: TextStyle(fontFamily: 'Kanit'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'จัดการจองรถ (จัดสรรคนขับ)',
          style: TextStyle(
            fontFamily: 'Kanit',
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFF004381),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingBookings.isEmpty
          ? const Center(
              child: Text(
                'ไม่มีรายการที่รอจัดสรรคนขับรถบริษัท',
                style: TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _pendingBookings.length,
              itemBuilder: (context, index) {
                final booking = _pendingBookings[index];
                final bookingId = booking['id'];
                final vehicle = booking['vehicle'] ?? {};

                String formatThaiDate(dynamic dateVal) {
                  if (dateVal == null || dateVal.toString().isEmpty) return '-';
                  try {
                    final DateTime dt = DateTime.parse(
                      dateVal.toString(),
                    ).toLocal();
                    const thaiMonths = [
                      'ม.ค.',
                      'ก.พ.',
                      'มี.ค.',
                      'เม.ย.',
                      'พ.ค.',
                      'มิ.ย.',
                      'ก.ค.',
                      'ส.ค.',
                      'ก.ย.',
                      'ต.ค.',
                      'พ.ย.',
                      'ธ.ค.',
                    ];
                    return '${dt.day.toString().padLeft(2, '0')} ${thaiMonths[dt.month - 1]} ${dt.year + 543}';
                  } catch (_) {
                    return dateVal.toString();
                  }
                }

                final String startDateStr = formatThaiDate(
                  booking['startDatetime'] ?? booking['startDate'],
                );
                final String endDateStr = formatThaiDate(
                  booking['endDatetime'] ?? booking['endDate'],
                );
                final String dateText = '$startDateStr ถึง $endDateStr';

                final String vehicleName =
                    vehicle['vehicleName'] ??
                    vehicle['model'] ??
                    vehicle['name'] ??
                    '-';
                final String plateNumber =
                    vehicle['plateNumber'] ??
                    vehicle['licensePlate'] ??
                    vehicle['registration'] ??
                    '-';

                String bookerName = 'ไม่ระบุชื่อ';
                if (booking['userName'] != null &&
                    booking['userName'].toString().trim().isNotEmpty) {
                  bookerName = booking['userName'].toString().trim();
                } else if (booking['user'] != null && booking['user'] is Map) {
                  final u = booking['user'];
                  bookerName =
                      u['employee']?['fullName'] ??
                      u['fullName'] ??
                      u['firstName'] ??
                      u['name'] ??
                      u['username'] ??
                      'ไม่ระบุชื่อ';
                } else if (booking['employeeName'] != null) {
                  bookerName = booking['employeeName'].toString();
                } else if (booking['bookerName'] != null) {
                  bookerName = booking['bookerName'].toString();
                }

                String extractName(dynamic p) {
                  if (p == null) return '';
                  if (p is Map) {
                    final keys = [
                      'fullName',
                      'full_name',
                      'passengerName',
                      'passenger_name',
                      'name',
                      'employeeName',
                      'employee_name',
                      'userName',
                      'user_name',
                    ];
                    for (var k in keys) {
                      if (p[k] != null && p[k].toString().trim().isNotEmpty) {
                        return p[k].toString().trim();
                      }
                    }
                    if (p['user'] is Map) {
                      final u = p['user'];
                      if (u['employee'] is Map &&
                          u['employee']['fullName'] != null) {
                        return u['employee']['fullName'].toString().trim();
                      }
                      if (u['firstName'] != null)
                        return u['firstName'].toString().trim();
                      if (u['name'] != null) return u['name'].toString().trim();
                    }
                    if (p['employee'] is Map &&
                        p['employee']['fullName'] != null) {
                      return p['employee']['fullName'].toString().trim();
                    }
                    return '';
                  }
                  final str = p.toString().trim();
                  if (int.tryParse(str) != null) return '';
                  return str;
                }

                List<String> parseStringNames(String str) {
                  final trimmed = str.trim();
                  if (trimmed.isEmpty || int.tryParse(trimmed) != null)
                    return [];
                  try {
                    final decoded = json.decode(trimmed);
                    if (decoded is List) {
                      return decoded
                          .map((e) => extractName(e))
                          .where((n) => n.trim().isNotEmpty)
                          .toList();
                    }
                  } catch (_) {}
                  String cleaned = trimmed;
                  if (cleaned.startsWith('[') && cleaned.endsWith(']')) {
                    cleaned = cleaned.substring(1, cleaned.length - 1);
                  }
                  return cleaned
                      .split(',')
                      .map((e) {
                        String s = e.trim();
                        if ((s.startsWith('"') && s.endsWith('"')) ||
                            (s.startsWith("'") && s.endsWith("'"))) {
                          s = s.substring(1, s.length - 1).trim();
                        }
                        return extractName(s);
                      })
                      .where((n) => n.trim().isNotEmpty)
                      .toList();
                }

                List<String> passengerNames = [];
                final candidateSources = [
                  booking['vehicleBookingPassengers'],
                  booking['vehicle_booking_passengers'],
                  booking['vehicleBookingPassenger'],
                  booking['vehicle_booking_passenger'],
                  booking['VehicleBookingPassenger'],
                  booking['VehicleBookingPassengers'],
                  booking['passengerDetails'],
                  booking['passenger_details'],
                  booking['passengerList'],
                  booking['passenger_list'],
                  booking['passengerNames'],
                  booking['passenger_names'],
                  booking['passengersList'],
                  booking['passengers_list'],
                  booking['bookingPassengers'],
                  booking['booking_passengers'],
                  booking['passengers'],
                  booking['members'],
                  booking['participants'],
                ];

                for (var src in candidateSources) {
                  if (src == null) continue;
                  if (src is List && src.isNotEmpty) {
                    final list = src
                        .map((p) => extractName(p))
                        .where((n) => n.trim().isNotEmpty)
                        .toList();
                    if (list.isNotEmpty) {
                      passengerNames = list;
                      break;
                    }
                  } else if (src is String && src.trim().isNotEmpty) {
                    final list = parseStringNames(src);
                    if (list.isNotEmpty) {
                      passengerNames = list;
                      break;
                    }
                  }
                }

                final selectedDriverVal = _selectedDrivers[bookingId];
                final isValidSelectedDriver = _companyDrivers.any(
                  (d) => d.id == selectedDriverVal,
                );

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'การจอง #${booking['id'] ?? '-'}',
                          style: const TextStyle(
                            fontFamily: 'Kanit',
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF004381),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'รถ: $vehicleName ($plateNumber)',
                          style: const TextStyle(fontFamily: 'Kanit'),
                        ),
                        Text(
                          'ผู้จอง: $bookerName',
                          style: const TextStyle(fontFamily: 'Kanit'),
                        ),
                        Text(
                          'วัตถุประสงค์: ${booking['purpose'] ?? '-'}',
                          style: const TextStyle(fontFamily: 'Kanit'),
                        ),
                        Text(
                          'วันที่: $dateText',
                          style: const TextStyle(fontFamily: 'Kanit'),
                        ),
                        if (passengerNames.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'ผู้โดยสาร: ${passengerNames.join(', ')}',
                            style: const TextStyle(
                              fontFamily: 'Kanit',
                              color: Colors.grey,
                            ),
                          ),
                        ],
                        const Divider(height: 24),
                        DropdownButtonFormField<int>(
                          isExpanded: true,
                          value: isValidSelectedDriver
                              ? selectedDriverVal
                              : null,
                          decoration: InputDecoration(
                            labelText: 'เลือกพนักงานขับรถ *',
                            labelStyle: const TextStyle(fontFamily: 'Kanit'),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: _companyDrivers.map((driver) {
                            final conflicts = _getDriverConflictingBookings(
                              booking,
                              driver.id,
                            );

                            String label = driver.fullName;
                            Color textColor = Colors.black;

                            if (conflicts.isNotEmpty) {
                              const thaiMonths = [
                                'ม.ค.',
                                'ก.พ.',
                                'มี.ค.',
                                'เม.ย.',
                                'พ.ค.',
                                'มิ.ย.',
                                'ก.ค.',
                                'ส.ค.',
                                'ก.ย.',
                                'ต.ค.',
                                'พ.ย.',
                                'ธ.ค.',
                              ];

                              List<dynamic> sortedConflicts = List.from(
                                conflicts,
                              );
                              sortedConflicts.sort((a, b) {
                                final aStart =
                                    DateTime.tryParse(
                                      (a['startDatetime'] ??
                                              a['startDate'] ??
                                              '')
                                          .toString(),
                                    ) ??
                                    DateTime(0);
                                final bStart =
                                    DateTime.tryParse(
                                      (b['startDatetime'] ??
                                              b['startDate'] ??
                                              '')
                                          .toString(),
                                    ) ??
                                    DateTime(0);
                                return aStart.compareTo(bStart);
                              });

                              String formatConflictItem(dynamic c) {
                                final DateTime cStart = DateTime.parse(
                                  (c['startDatetime'] ?? c['startDate'])
                                      .toString(),
                                ).toLocal();
                                final DateTime cEnd = DateTime.parse(
                                  (c['endDatetime'] ?? c['endDate']).toString(),
                                ).toLocal();

                                final String sTime =
                                    '${cStart.hour.toString().padLeft(2, '0')}:${cStart.minute.toString().padLeft(2, '0')}';
                                final String eTime =
                                    '${cEnd.hour.toString().padLeft(2, '0')}:${cEnd.minute.toString().padLeft(2, '0')}';

                                if (cStart.day == cEnd.day &&
                                    cStart.month == cEnd.month &&
                                    cStart.year == cEnd.year) {
                                  return '${cStart.day} ${thaiMonths[cStart.month - 1]} • $sTime - $eTime';
                                }
                                return '${cStart.day} ${thaiMonths[cStart.month - 1]} $sTime → ${cEnd.day} ${thaiMonths[cEnd.month - 1]} $eTime';
                              }

                              if (sortedConflicts.length == 1) {
                                label +=
                                    ' ⚠ มีคิวซ้อน (${formatConflictItem(sortedConflicts.first)})';
                              } else {
                                label +=
                                    ' ⚠ มีคิวซ้อน ${sortedConflicts.length} รายการ';
                              }
                              textColor = Colors.red;
                            } else if (!driver.isAvailable) {
                              label += ' (ไม่พร้อมปฏิบัติงาน)';
                              textColor = Colors.grey;
                            } else {
                              label += ' ✓ พร้อมปฏิบัติงาน';
                              textColor = Colors.green.shade700;
                            }

                            return DropdownMenuItem<int>(
                              value: driver.id,
                              child: Text(
                                label,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(
                                  fontFamily: 'Kanit',
                                  color: textColor,
                                  fontWeight: conflicts.isNotEmpty
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedDrivers[bookingId] = val;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _selectedDrivers[bookingId] == null
                                ? null
                                : () => _assignDriver(
                                    bookingId,
                                    _selectedDrivers[bookingId]!,
                                  ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF009CB4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'บันทึกจัดสรรคนขับ',
                              style: TextStyle(
                                fontFamily: 'Kanit',
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
