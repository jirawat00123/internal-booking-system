import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'calendar_model.dart';
import 'calendar_service.dart';
import '../Booking_room/Room_model.dart';
import '../auth_service.dart'; // เพิ่ม Import AuthService (ตรวจสอบ Path ให้ตรงกับไฟล์ในโปรเจกต์ของคุณ)

class CalendarPage extends StatefulWidget {
  final String category;

  const CalendarPage({Key? key, this.category = 'ROOM'}) : super(key: key);

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final CalendarService _calendarService = CalendarService();

  CalendarFormat _calendarFormat = CalendarFormat.twoWeeks;
  DateTime _focusedDay = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  DateTime? _selectedDay;

  bool _isLoading = false;
  List<CalendarEvent> _allEvents = [];
  Map<DateTime, List<CalendarEvent>> _groupedEvents = {};
  int? _selectedVehicleId;

  List<VehicleCalendarGrid> _vehicleGridData = [];
  List<RoomCalendarGrid> _roomGridData = [];
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadUserRole();
    _fetchEventsForCurrentView();
  }

  Future<void> _loadUserRole() async {
    try {
      final role = await AuthService.instance.getRole();
      if (mounted) {
        setState(() {
          _userRole = role?.toUpperCase();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchEventsForCurrentView() async {
    setState(() {
      _isLoading = true;
    });

    try {
      DateTime startOfWeek = DateTime(
        _focusedDay.year,
        _focusedDay.month,
        _focusedDay.day,
      ).subtract(Duration(days: _focusedDay.weekday - 1));

      DateTime endOfWeek = DateTime(
        startOfWeek.year,
        startOfWeek.month,
        startOfWeek.day + 6,
        23,
        59,
        59,
      );

      if (widget.category == 'VEHICLE') {
        final gridData = await _calendarService.getCalendarGrid(
          startOfWeek,
          endOfWeek,
        );
        print('DEBUG_VEHICLE_GRID_COUNT: ${gridData.length}');
        for (var v in gridData) {
          print(
            'DEBUG_VEHICLE: ${v.vehicleName}, Bookings: ${v.bookings.length}',
          );
          for (var b in v.bookings) {
            print(
              '   -> Booking ID: ${b.id}, User: ${b.userName}, Status: ${b.status}, Start: ${b.startDatetime}, End: ${b.endDatetime}',
            );
          }
        }
        setState(() {
          _vehicleGridData = gridData;
        });
      } else {
        final gridData = await _calendarService.getRoomCalendarGrid(
          startOfWeek,
          endOfWeek,
        );
        print('DEBUG_ROOM_GRID_COUNT: ${gridData.length}');
        setState(() {
          _roomGridData = gridData;
        });
      }
    } catch (e) {
      print('DEBUG_FETCH_ERROR: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // จัดกลุ่ม Event ลงในแต่ละวันที่เกิดเหตุการณ์ (รองรับ Multi-day Booking)
  void _groupEvents(List<CalendarEvent> events) {
    _groupedEvents.clear();

    for (var event in events) {
      // คัดแยกเอาเฉพาะ (ปี-เดือน-วัน) ตัดเวลาออกเพื่อใช้เป็น Key ของ Map
      DateTime startDay = DateTime(
        event.start.year,
        event.start.month,
        event.start.day,
      );
      DateTime endDay = DateTime(
        event.end.year,
        event.end.month,
        event.end.day,
      );

      // วนลูปใส่วันที่จองตั้งแต่เริ่มจนจบ (เพื่อรองรับการจองรถแบบข้ามวัน)
      DateTime currentDay = startDay;
      while (currentDay.isBefore(endDay) ||
          currentDay.isAtSameMomentAs(endDay)) {
        if (_groupedEvents[currentDay] == null) {
          _groupedEvents[currentDay] = [];
        }
        _groupedEvents[currentDay]!.add(event);

        currentDay = currentDay.add(const Duration(days: 1));
      }
    }
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    // ล้างเวลาออกเพื่อให้ตรงกับ Key ใน Map
    DateTime normalizedDay = DateTime(day.year, day.month, day.day);
    final events = _groupedEvents[normalizedDay] ?? [];
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    // กรองไม่ให้แสดงประวัติของวันที่ผ่านไปแล้ว แต่การจองของวันนี้ และการจองลากยาวข้ามวันจะยังคงแสดงอยู่
    return events.where((event) => !event.end.isBefore(todayMidnight)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF003E75),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.category == 'VEHICLE'
              ? 'ปฏิทินการจองรถยนต์'
              : 'ปฏิทินการจองห้องประชุม',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            fontFamily: 'Kanit',
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchEventsForCurrentView,
          ),
        ],
      ),
      body: Column(
        children: [
          const Divider(height: 1),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_userRole == 'GUARD' && widget.category == 'ROOM')
                ? const Center(
                    child: Text(
                      'เจ้าหน้าที่รักษาความปลอดภัย (GUARD)\nไม่สามารถเข้าดูปฏิทินห้องประชุมได้',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        fontSize: 16,
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : widget.category == 'VEHICLE'
                ? _buildVehicleGrid()
                : _buildRoomGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendBadge(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, fontFamily: 'Kanit')),
      ],
    );
  }

  Widget _buildEventList() {
    final selectedDate = _selectedDay ?? _focusedDay;
    final selectedEvents = _getEventsForDay(selectedDate);
    final selectedDateText = DateFormat(
      'dd MMMM yyyy',
      'th',
    ).format(selectedDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ส่วนหัวแสดงวันที่เลือก
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          color: const Color(0xFFE8F1F5),
          child: Row(
            children: [
              const Icon(Icons.event_note, color: Color(0xFF00529B), size: 20),
              const SizedBox(width: 8),
              Text(
                'รายการขอใช้งานวันนี้ ($selectedDateText)',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF003E77),
                  fontFamily: 'Kanit',
                ),
              ),
            ],
          ),
        ),

        // รายการการจอง
        Expanded(
          child: selectedEvents.isEmpty && !_isLoading
              ? const Center(
                  child: Text(
                    'ไม่มีรายการจองในวันนี้',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey,
                      fontFamily: 'Kanit',
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: selectedEvents.length,
                  padding: const EdgeInsets.all(12.0),
                  itemBuilder: (context, index) {
                    final event = selectedEvents[index];

                    final timeFormat = DateFormat('HH:mm');
                    final startTime = timeFormat.format(event.start);
                    final endTime = timeFormat.format(event.end);

                    return InkWell(
                      onTap: () => _showEventDetailDialog(event),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 4,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: event.color,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '$startTime - $endTime น.',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: event.color,
                                            fontFamily: 'Kanit',
                                          ),
                                        ),
                                        // แสดง Badge เล็กๆ บอกสถานะ Reserved / In Use
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: event.color.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: event.color,
                                            ),
                                          ),
                                          child: Text(
                                            event.status,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: event.color,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      event.title,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Kanit',
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.person,
                                          size: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          event.bookerName,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade700,
                                            fontFamily: 'Kanit',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    Color valueColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontFamily: 'Kanit',
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: valueColor,
                  fontFamily: 'Kanit',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showEventDetailDialog(CalendarEvent event) {
    final dateFormat = DateFormat('d MMMM yyyy', 'th');
    final timeFormat = DateFormat('HH:mm');
    final room = event.roomInfo;
    final vehicle = event.vehicleInfo;
    final isVehicle = event.type == 'VEHICLE' || widget.category == 'VEHICLE';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(
            24.0,
          ).copyWith(bottom: MediaQuery.of(context).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isVehicle
                    ? 'รายละเอียดการจองรถยนต์'
                    : 'รายละเอียดการจองห้องประชุม',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kanit',
                ),
              ),
              const SizedBox(height: 20),
              _buildDetailRow(
                isVehicle ? Icons.directions_car : Icons.meeting_room,
                isVehicle ? 'ยานพาหนะ' : 'ห้องประชุม',
                event.title,
                Colors.black87,
              ),
              if (!isVehicle && room != null && room['location'] != null) ...[
                const SizedBox(height: 16),
                _buildDetailRow(
                  Icons.location_on,
                  'สถานที่ / ชั้น',
                  '${room['location'] ?? '-'} ชั้น ${room['floor'] ?? '-'}',
                  Colors.black87,
                ),
              ],
              if (isVehicle &&
                  vehicle != null &&
                  vehicle['plateNumber'] != null) ...[
                const SizedBox(height: 16),
                _buildDetailRow(
                  Icons.badge,
                  'ทะเบียนรถ',
                  '${vehicle['plateNumber'] ?? '-'}',
                  Colors.black87,
                ),
              ],
              const SizedBox(height: 16),
              _buildDetailRow(
                Icons.person,
                'ผู้จอง',
                event.bookerName,
                Colors.black87,
              ),
              const SizedBox(height: 16),
              _buildDetailRow(
                Icons.calendar_today,
                'วันที่',
                dateFormat.format(event.start),
                Colors.black87,
              ),
              const SizedBox(height: 16),
              _buildDetailRow(
                Icons.access_time,
                'เวลา',
                '${timeFormat.format(event.start)} - ${timeFormat.format(event.end)} น.',
                Colors.black87,
              ),
              const SizedBox(height: 16),
              _buildDetailRow(
                Icons.info_outline,
                'สถานะ',
                event.status,
                event.color,
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================
  // ส่วนแสดงผลปฏิทินตารางรถยนต์ (Matrix Grid)
  // =========================================================
  Widget _buildVehicleGrid() {
    DateTime startOfWeek = DateTime(
      _focusedDay.year,
      _focusedDay.month,
      _focusedDay.day,
    ).subtract(Duration(days: _focusedDay.weekday - 1));
    List<DateTime> weekDays = List.generate(
      7,
      (i) => startOfWeek.add(Duration(days: i)),
    );

    return Column(
      children: [
        _buildWeekNavigator(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = constraints.maxWidth;
              const minTableWidth =
                  1090.0; // ขยายขั้นต่ำชดเชยพื้นที่รูป เพื่อไม่ให้กระทบความกว้างช่องวัน
              final tableWidth = screenWidth > minTableWidth
                  ? screenWidth
                  : minTableWidth;
              const vehicleColWidth =
                  190.0; // ขยายพื้นที่คอลัมน์ชื่อรถ เพื่อให้วางรูปรถและข้อความไม่ถูกบีบ
              final dayColWidth = (tableWidth - vehicleColWidth) / 7;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  width: tableWidth,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTableHeaderRow(
                        weekDays,
                        vehicleColWidth,
                        dayColWidth,
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_vehicleGridData.isEmpty)
                                Container(
                                  width: tableWidth,
                                  padding: const EdgeInsets.all(32),
                                  child: const Center(
                                    child: Text(
                                      'ไม่พบข้อมูลรายการรถยนต์',
                                      style: TextStyle(
                                        fontFamily: 'Kanit',
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                ..._vehicleGridData.map((vehicle) {
                                  return _buildVehicleDataRow(
                                    vehicle,
                                    weekDays,
                                    vehicleColWidth,
                                    dayColWidth,
                                  );
                                }).toList(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeaderRow(
    List<DateTime> weekDays,
    double vehicleColWidth,
    double dayColWidth,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEBF3FA),
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Container(
            width: vehicleColWidth,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
            child: const Text(
              'รายชื่อ / วันที่',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Kanit',
                fontSize: 13,
                color: Color(0xFF003E75),
              ),
            ),
          ),
          ...weekDays.map((date) {
            final dateNormalized = DateTime(date.year, date.month, date.day);
            final isToday = dateNormalized.isAtSameMomentAs(today);

            return Container(
              width: dayColWidth,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              decoration: BoxDecoration(
                color: isToday
                    ? const Color(0xFF003E75)
                    : const Color(0xFFEBF3FA),
                border: Border(right: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E d MMM', 'th').format(date),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Kanit',
                      fontSize: 12,
                      color: isToday ? Colors.white : const Color(0xFF003E75),
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade400,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'วันนี้',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontFamily: 'Kanit',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildVehicleDataRow(
    VehicleCalendarGrid vehicle,
    List<DateTime> weekDays,
    double vehicleColWidth,
    double dayColWidth,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: vehicleColWidth,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: Colors.grey.shade300)),
              ),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _showImagePreview(context, vehicle.upload_url),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: _buildVehicleThumbnail(vehicle.upload_url),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${vehicle.vehicleName}\n(${vehicle.plateNumber})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kanit',
                        fontSize: 12,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 3,
                    ),
                  ),
                ],
              ),
            ),
            ...weekDays.map((date) {
              final bookings = _findBookingsForDate(vehicle.bookings, date);
              return Container(
                width: dayColWidth,
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: _buildCellContent(
                  bookings,
                  date,
                  weekDays.first,
                  isVehicle: true,
                  parent: vehicle,
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekNavigator() {
    DateTime startOfWeek = DateTime(
      _focusedDay.year,
      _focusedDay.month,
      _focusedDay.day,
    ).subtract(Duration(days: _focusedDay.weekday - 1));
    DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));

    final bool isAdmin = _userRole == 'ADMIN';

    DateTime now = DateTime.now();
    DateTime currentWeekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    DateTime targetPrevWeek = startOfWeek.subtract(const Duration(days: 7));

    // Admin ดูอดีตได้อิสระ ส่วน USER/GUARD บล็อก Navigation/Drag ย้อนกลับไปสัปดาห์ในอดีต
    final bool canGoBack =
        isAdmin || !targetPrevWeek.isBefore(currentWeekStart);
    // การดูปฏิทินล่วงหน้า ทุก Role สามารถใช้งานได้
    final bool canGoForward = true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 18),
                onPressed: canGoBack
                    ? () {
                        setState(() {
                          _focusedDay = _focusedDay.subtract(
                            const Duration(days: 7),
                          );
                        });
                        _fetchEventsForCurrentView();
                      }
                    : null,
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: const BorderSide(color: Color(0xFF003E75)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    DateTime now = DateTime.now();
                    _focusedDay = DateTime(now.year, now.month, now.day);
                  });
                  _fetchEventsForCurrentView();
                },
                child: const Text(
                  'วันนี้',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Kanit',
                    color: Color(0xFF003E75),
                  ),
                ),
              ),
            ],
          ),
          Text(
            'สัปดาห์: ${DateFormat('d MMM', 'th').format(startOfWeek)} - ${DateFormat('d MMM yyyy', 'th').format(endOfWeek)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'Kanit',
              color: Color(0xFF003E75),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 18),
            onPressed: canGoForward
                ? () {
                    setState(() {
                      _focusedDay = _focusedDay.add(const Duration(days: 7));
                    });
                    _fetchEventsForCurrentView();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  List<BookingItem> _findBookingsForDate(
    List<BookingItem> bookings,
    DateTime date,
  ) {
    DateTime target = DateTime(date.year, date.month, date.day);
    List<BookingItem> results = [];

    for (var b in bookings) {
      final s = b.status.toUpperCase();
      if (s == 'CANCELLED' || s == 'REJECTED' || s == 'EXPIRED') continue;

      // แก้ไขปัญหา Timezone +7 โดยสร้าง DateTime ใหม่จากค่าตัวเลขตรงๆ
      // เพื่อป้องกันการแปลง UTC -> Local ที่ทำให้เวลาเพี้ยนไป 7 ชั่วโมง
      DateTime startLocal = DateTime(
        b.startDatetime.year,
        b.startDatetime.month,
        b.startDatetime.day,
        b.startDatetime.hour,
        b.startDatetime.minute,
      );
      DateTime endLocal = DateTime(
        b.endDatetime.year,
        b.endDatetime.month,
        b.endDatetime.day,
        b.endDatetime.hour,
        b.endDatetime.minute,
      );

      DateTime start = DateTime(
        startLocal.year,
        startLocal.month,
        startLocal.day,
      );
      DateTime end = DateTime(endLocal.year, endLocal.month, endLocal.day);

      if ((target.isAfter(start) || target.isAtSameMomentAs(start)) &&
          (target.isBefore(end) || target.isAtSameMomentAs(end))) {
        print(
          'MATCH_FOUND: Date $target matched booking ${b.id} (${b.userName}) status: ${b.status}',
        );
        results.add(b);
      }
    }
    return results; // รองรับ Overlap ส่งกลับการจองทั้งหมดที่ทับซ้อนกันในวันเดียว
  }

  Widget _buildCellContent(
    List<BookingItem> dayBookings,
    DateTime currentDate,
    DateTime startOfWeek, {
    bool isVehicle = true,
    dynamic parent,
  }) {
    if (dayBookings.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text(
            '— ว่าง —',
            style: TextStyle(
              color: Colors.grey,
              fontFamily: 'Kanit',
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    // รองรับการแสดงผล Overlap สร้าง Block แบบวางซ้อนเรียงลงมาตามจำนวนการจอง
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: dayBookings.map((booking) {
        // สร้าง Normalized DateTime ไว้ด้านบน เพื่อนำมาเช็คสถานะและแก้ไขปัญหา Timezone Shift (+7)
        DateTime normStart = DateTime(
          booking.startDatetime.year,
          booking.startDatetime.month,
          booking.startDatetime.day,
          booking.startDatetime.hour,
          booking.startDatetime.minute,
        );
        DateTime normEnd = DateTime(
          booking.endDatetime.year,
          booking.endDatetime.month,
          booking.endDatetime.day,
          booking.endDatetime.hour,
          booking.endDatetime.minute,
        );

        // คำนวณสถานะตามเวลาปัจจุบัน (อ้างอิง Logic จากหน้าประวัติการจอง)
        DateTime now = DateTime.now();
        final s = booking.status.toUpperCase();

        String statusLabel = '[จองแล้ว]';
        Color bgColor = const Color(0xFFFFF7ED);
        Color borderColor = const Color(0xFFFDBA74);
        Color textColor = const Color(0xFFC2410C);

        if (isVehicle) {
          if (s == 'RETURNED') {
            statusLabel = '🟢 คืนรถแล้ว';
            bgColor = const Color(0xFFDCFCE7);
            borderColor = const Color(0xFF86EFAC);
            textColor = const Color(0xFF166534);
          } else if (s == 'COMPLETED' || s == 'FINISHED') {
            statusLabel = '[เสร็จสิ้น]';
            bgColor = const Color(0xFFF3F4F6);
            borderColor = const Color(0xFFD1D5DB);
            textColor = const Color(0xFF4B5563);
          } else if (s == 'IN_USE') {
            if (now.isAfter(normEnd)) {
              statusLabel = '⚠️ เกินเวลาที่กำหนดคืนรถ';
              bgColor = const Color(0xFFFEE2E2);
              borderColor = const Color(0xFFFCA5A5);
              textColor = const Color(0xFF991B1B);
            } else {
              statusLabel = '[กำลังใช้งาน]';
              bgColor = const Color(0xFFEFF6FF);
              borderColor = const Color(0xFF93C5FD);
              textColor = const Color(0xFF1E40AF);
            }
          } else if (s == 'APPROVED') {
            statusLabel = 'รอปล่อยรถ';
            bgColor = const Color(0xFFFEF9C3);
            borderColor = const Color(0xFFFDE047);
            textColor = const Color(0xFF854D0E);
          } else if (s == 'PENDING' || s == 'WAITING') {
            statusLabel = '[รออนุมัติ]';
            bgColor = const Color(0xFFFEF3C7);
            borderColor = const Color(0xFFFCD34D);
            textColor = const Color(0xFFD97706);
          }
        } else {
          // Room Status Display
          if (s == 'COMPLETED' || s == 'FINISHED' || now.isAfter(normEnd)) {
            statusLabel = '[เสร็จสิ้น]';
            bgColor = const Color(0xFFF3F4F6);
            borderColor = const Color(0xFFD1D5DB);
            textColor = const Color(0xFF4B5563);
          } else if (s == 'IN_USE') {
            statusLabel = '[กำลังใช้งาน]';
            bgColor = const Color(0xFFEFF6FF);
            borderColor = const Color(0xFF93C5FD);
            textColor = const Color(0xFF1E40AF);
          } else if (s == 'APPROVED' || s == 'PENDING' || s == 'WAITING') {
            statusLabel = '[จองแล้ว]';
            bgColor = const Color(0xFFFFF7ED);
            borderColor = const Color(0xFFFDBA74);
            textColor = const Color(0xFFC2410C);
          }
        }

        DateTime start = DateTime(
          normStart.year,
          normStart.month,
          normStart.day,
        );
        DateTime end = DateTime(normEnd.year, normEnd.month, normEnd.day);
        DateTime current = DateTime(
          currentDate.year,
          currentDate.month,
          currentDate.day,
        );
        DateTime weekStart = DateTime(
          startOfWeek.year,
          startOfWeek.month,
          startOfWeek.day,
        );

        bool isFirstDayOfBooking =
            current.isAtSameMomentAs(start) || current.isBefore(start);
        bool isLastDayOfBooking =
            current.isAtSameMomentAs(end) || current.isAfter(end);

        String startTimeStr = DateFormat('HH:mm').format(normStart);
        String endTimeStr = DateFormat('HH:mm').format(normEnd);

        String timeStr = '$startTimeStr - $endTimeStr';

        // จัดการ Ribbon UI สำหรับการจองข้ามวันให้เชื่อมต่อกัน (ลบขอบส่วนกลางทิ้ง)
        BorderRadius radius = BorderRadius.zero;
        if (isFirstDayOfBooking && isLastDayOfBooking) {
          radius = BorderRadius.circular(6);
        } else if (isFirstDayOfBooking) {
          radius = const BorderRadius.horizontal(left: Radius.circular(6));
        } else if (isLastDayOfBooking) {
          radius = const BorderRadius.horizontal(right: Radius.circular(6));
        }

        // แสดงรายละเอียดเฉพาะวันแรกของการจอง หรือวันแรกของสัปดาห์นั้น
        bool shouldShowDetails =
            isFirstDayOfBooking ||
            (start.isBefore(weekStart) && current.isAtSameMomentAs(weekStart));

        Widget cardContent = Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () =>
                _showBookingDetailBottomSheet(booking, parent, isVehicle),
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: SizedBox(
                height: isVehicle ? 60 : 76,
                width: double.infinity,
                child: shouldShowDetails
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              fontFamily: 'Kanit',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            booking.userName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                              fontFamily: 'Kanit',
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          if (!isVehicle && parent != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                [
                                  if (parent.floor != null &&
                                      parent.floor.toString().isNotEmpty)
                                    'ชั้น ${parent.floor}',
                                  if (parent.location != null &&
                                      parent.location.toString().isNotEmpty)
                                    parent.location,
                                ].join(' • '),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade700,
                                  fontFamily: 'Kanit',
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: textColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              statusLabel,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Kanit',
                              ),
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.expand(),
              ),
            ),
          ),
        );

        BorderSide borderSide = BorderSide(color: borderColor, width: 1.5);

        return Container(
          // ปิดช่องว่าง Margin ด้านในระหว่างวัน เพื่อให้สี Background ต่อกันสนิท
          margin: EdgeInsets.only(
            top: 4,
            bottom: 4,
            left: isFirstDayOfBooking ? 4 : 0,
            right: isLastDayOfBooking ? 4 : 0,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: radius,
            // วาด Border ให้เปิดช่องว่างตรงกลางไว้
            border: Border(
              top: borderSide,
              bottom: borderSide,
              left: isFirstDayOfBooking ? borderSide : BorderSide.none,
              right: isLastDayOfBooking ? borderSide : BorderSide.none,
            ),
          ),
          child: cardContent,
        );
      }).toList(),
    );
  }

  String _getFullImageUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';

    // แปลง Backslash (\) จาก Windows Server ให้เป็น Slash (/) และลบช่องว่างหัวท้าย
    String formattedPath = path.trim().replaceAll('\\', '/');

    if (formattedPath.startsWith('http://') ||
        formattedPath.startsWith('https://')) {
      return Uri.encodeFull(formattedPath);
    }

    // ดึงเฉพาะ http://IP:PORT เพื่อป้องกัน Path /api ติดมาด้วย
    final uri = Uri.parse(AuthService.baseUrl);
    final imageBaseUrl =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';

    // ตัด Path ส่วนเกินของ NAS ออก ให้เหลือเฉพาะ Relative Path ของรูปภาพ
    if (formattedPath.contains('attachments/vehicles/images/')) {
      final index = formattedPath.indexOf('attachments/vehicles/images/');
      formattedPath = '/${formattedPath.substring(index)}';
    } else if (!formattedPath.startsWith('/')) {
      formattedPath = '/$formattedPath';
    }

    // รวม URL และแปลง Encode ช่องว่างให้เป็น %20
    return Uri.encodeFull('$imageBaseUrl$formattedPath');
  }

  Widget _buildVehicleThumbnail(String? imageUrl) {
    final String fullUrl = _getFullImageUrl(imageUrl);

    // 🟢 ย้ายมาไว้บรรทัดแรก เพื่อดูว่า API ส่งค่า imageUrl หรือ uploadUrl อะไรมา
    print('DEBUG_THUMBNAIL_RAW: "$imageUrl" | FULL_URL: "$fullUrl"');

    if (fullUrl.isEmpty) {
      // เพิ่ม Log แจ้งเตือนเมื่อ URL เป็นค่าว่าง
      print('⚠️ Image URL is empty or null, showing fallback icon');
      return Container(
        width: 45,
        height: 35,
        color: Colors.grey.shade200,
        child: const Icon(Icons.directions_car, size: 20, color: Colors.grey),
      );
    }

    return Image.network(
      fullUrl,
      width: 45,
      height: 35,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        // 🟢 เปลี่ยนใช้ print ปกติเพื่อให้แสดงใน Web DevTools พร้อมแสดง Error ที่แท้จริง
        print('❌ Image Failed to load: $fullUrl | Error: $error');
        return Container(
          width: 45,
          height: 35,
          color: Colors.grey.shade200,
          child: const Icon(Icons.directions_car, size: 20, color: Colors.grey),
        );
      },
    );
  }

  void _showImagePreview(BuildContext context, String? imageUrl) {
    final String fullUrl = _getFullImageUrl(imageUrl);
    if (fullUrl.isEmpty) return;

    // เพิ่ม print เพื่อตรวจสอบ URL เมื่อกดดูรูปใหญ่
    print('DEBUG_PREVIEW_URL: $fullUrl');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                fullUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image, size: 50, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          'ไม่สามารถโหลดรูปภาพได้',
                          style: TextStyle(fontFamily: 'Kanit'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.cancel, color: Colors.white, size: 36),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // ส่วนแสดงผลปฏิทินตารางห้องประชุม (Matrix Grid)
  // =========================================================
  Widget _buildRoomGrid() {
    DateTime startOfWeek = DateTime(
      _focusedDay.year,
      _focusedDay.month,
      _focusedDay.day,
    ).subtract(Duration(days: _focusedDay.weekday - 1));
    List<DateTime> weekDays = List.generate(
      7,
      (i) => startOfWeek.add(Duration(days: i)),
    );

    return Column(
      children: [
        _buildWeekNavigator(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = constraints.maxWidth;
              const minTableWidth = 1090.0;
              final tableWidth = screenWidth > minTableWidth
                  ? screenWidth
                  : minTableWidth;
              const roomColWidth = 190.0;
              final dayColWidth = (tableWidth - roomColWidth) / 7;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  width: tableWidth,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTableHeaderRow(weekDays, roomColWidth, dayColWidth),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_roomGridData.isEmpty)
                                Container(
                                  width: tableWidth,
                                  padding: const EdgeInsets.all(32),
                                  child: const Center(
                                    child: Text(
                                      'ไม่พบข้อมูลรายการห้องประชุม',
                                      style: TextStyle(
                                        fontFamily: 'Kanit',
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                ..._roomGridData.map((room) {
                                  return _buildRoomDataRow(
                                    room,
                                    weekDays,
                                    roomColWidth,
                                    dayColWidth,
                                  );
                                }).toList(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRoomDataRow(
    RoomCalendarGrid room,
    List<DateTime> weekDays,
    double roomColWidth,
    double dayColWidth,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: roomColWidth,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: Colors.grey.shade300)),
              ),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _showImagePreview(context, room.upload_url),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: _buildVehicleThumbnail(room.upload_url),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${room.roomName}\n(${[if (room.floor != null && room.floor.toString().isNotEmpty) 'ชั้น ${room.floor}', if (room.location != null && room.location.toString().isNotEmpty) room.location].join(' • ')})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kanit',
                        fontSize: 12,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 3,
                    ),
                  ),
                ],
              ),
            ),
            ...weekDays.map((date) {
              final bookings = _findBookingsForDate(room.bookings, date);
              return Container(
                width: dayColWidth,
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: _buildCellContent(
                  bookings,
                  date,
                  weekDays.first,
                  isVehicle: false,
                  parent: room,
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  void _showBookingDetailBottomSheet(
    BookingItem booking,
    dynamic parent,
    bool isVehicle,
  ) {
    // สร้าง Normalized DateTime เพื่อแก้ปัญหา Timezone Shift (+7) สำหรับการเช็คสถานะ
    DateTime normStart = DateTime(
      booking.startDatetime.year,
      booking.startDatetime.month,
      booking.startDatetime.day,
      booking.startDatetime.hour,
      booking.startDatetime.minute,
    );
    DateTime normEnd = DateTime(
      booking.endDatetime.year,
      booking.endDatetime.month,
      booking.endDatetime.day,
      booking.endDatetime.hour,
      booking.endDatetime.minute,
    );

    DateTime now = DateTime.now();
    final s = booking.status.toUpperCase();
    String statusLabel = '[จองแล้ว]';

    if (isVehicle) {
      if (s == 'RETURNED') {
        statusLabel = '🟢 คืนรถแล้ว';
      } else if (s == 'COMPLETED' || s == 'FINISHED') {
        statusLabel = '[เสร็จสิ้น]';
      } else if (s == 'IN_USE') {
        if (now.isAfter(normEnd)) {
          statusLabel = '⚠️ เกินเวลาที่กำหนดคืนรถ';
        } else {
          statusLabel = '[กำลังใช้งาน]';
        }
      } else if (s == 'APPROVED') {
        statusLabel = 'รอปล่อยรถ';
      } else if (s == 'PENDING' || s == 'WAITING') {
        statusLabel = '[รออนุมัติ]';
      }
    } else {
      if (s == 'COMPLETED' || s == 'FINISHED' || now.isAfter(normEnd)) {
        statusLabel = '[เสร็จสิ้น]';
      } else if (s == 'IN_USE') {
        statusLabel = '[กำลังใช้งาน]';
      } else if (s == 'APPROVED' || s == 'PENDING' || s == 'WAITING') {
        statusLabel = '[จองแล้ว]';
      }
    }

    String imageUrl = '';
    String title = '';
    String subTitle = '';

    if (isVehicle && parent != null) {
      imageUrl = _getFullImageUrl(parent.upload_url);
      title = '🚗 ${parent.vehicleName}';
      subTitle = 'ทะเบียน ${parent.plateNumber}';
    } else if (!isVehicle && parent != null) {
      imageUrl = _getFullImageUrl(parent.upload_url);
      title = '🏢 ${parent.roomName}';
      subTitle = [
        if (parent.floor != null && parent.floor.toString().isNotEmpty)
          'ชั้น ${parent.floor}',
        if (parent.location != null && parent.location.toString().isNotEmpty)
          parent.location,
      ].join(' • ');
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(
            24,
          ).copyWith(bottom: MediaQuery.of(context).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'รายละเอียด',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Kanit',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              if (imageUrl.isNotEmpty) const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kanit',
                ),
              ),
              if (subTitle.isNotEmpty)
                Text(
                  subTitle,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontFamily: 'Kanit',
                    fontSize: 14,
                  ),
                ),
              const Divider(height: 32),
              _buildSheetDetailRow('👤 ผู้จอง', booking.userName),
              _buildSheetDetailRow(
                '📅 วันที่',
                DateFormat('d MMM yyyy', 'th').format(
                  DateTime(
                    booking.startDatetime.year,
                    booking.startDatetime.month,
                    booking.startDatetime.day,
                    booking.startDatetime.hour,
                    booking.startDatetime.minute,
                  ),
                ),
              ),
              _buildSheetDetailRow(
                '🕐 เวลา',
                '${DateFormat('HH:mm').format(DateTime(booking.startDatetime.year, booking.startDatetime.month, booking.startDatetime.day, booking.startDatetime.hour, booking.startDatetime.minute))} - ${DateFormat('HH:mm').format(DateTime(booking.endDatetime.year, booking.endDatetime.month, booking.endDatetime.day, booking.endDatetime.hour, booking.endDatetime.minute))}',
              ),
              _buildSheetDetailRow('ℹ️ สถานะ', statusLabel),
              if (booking.purpose.isNotEmpty)
                _buildSheetDetailRow(
                  isVehicle ? '📍 จุดหมาย/รายละเอียด' : '📝 หัวข้อ/รายละเอียด',
                  booking.purpose,
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003E75),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'ปิด',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Kanit',
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontFamily: 'Kanit',
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontFamily: 'Kanit',
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
