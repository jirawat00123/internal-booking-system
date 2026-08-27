import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'calendar_model.dart';
import 'calendar_service.dart';
import '../Booking_room/Room_model.dart';

class CalendarPage extends StatefulWidget {
  final String category;

  const CalendarPage({Key? key, this.category = 'ROOM'}) : super(key: key);

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final CalendarService _calendarService = CalendarService();

  CalendarFormat _calendarFormat = CalendarFormat.twoWeeks;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  bool _isLoading = false;
  List<CalendarEvent> _allEvents = [];
  Map<DateTime, List<CalendarEvent>> _groupedEvents = {};
  String? _selectedLocation;
  int? _selectedRoomId;
  int? _selectedVehicleId;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchEventsForCurrentView();
  }

  Future<void> _fetchEventsForCurrentView() async {
    setState(() {
      _isLoading = true;
    });

    try {
      DateTime startDate = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
      DateTime endDate = DateTime(_focusedDay.year, _focusedDay.month + 2, 0);

      List<CalendarEvent> events;
      if (widget.category == 'VEHICLE') {
        events = await _calendarService.fetchVehicleEvents(
          startDate,
          endDate,
          vehicleId: _selectedVehicleId,
        );
      } else {
        events = await _calendarService.fetchRoomEvents(
          startDate,
          endDate,
          roomId: _selectedRoomId,
          location: _selectedLocation,
        );
      }

      // กรองให้แสดงเฉพาะสถานะ RESERVED (APPROVED) และ IN_USE เท่านั้น
      events = events.where((event) {
        final status = event.status.toUpperCase();
        return status == 'RESERVED' || status == 'APPROVED' || status == 'IN_USE';
      }).toList();

      _groupEvents(events);

      setState(() {
        _allEvents = events;
      });
    } catch (e) {
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
    return _groupedEvents[normalizedDay] ?? [];
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
              ? 'ตารางการจองรถยนต์'
              : 'ตารางการจองห้องประชุม',
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 4.0,
            ),
            color: Colors.white,
            child: widget.category == 'VEHICLE'
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: const [
                        Icon(
                          Icons.directions_car,
                          color: Color(0xFF003E75),
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'ปฏิทินรายการจองรถยนต์',
                          style: TextStyle(
                            fontFamily: 'Kanit',
                            fontSize: 14,
                            color: Color(0xFF003E75),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final bool isWide = constraints.maxWidth > 500;

                      Widget locationFilter = Row(
                        children: [
                          const Text(
                            'ฝั่ง:',
                            style: TextStyle(
                              fontFamily: 'Kanit',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButton<String?>(
                              value: _selectedLocation,
                              isExpanded: true,
                              isDense: true,
                              underline: const SizedBox(),
                              icon: const Icon(Icons.arrow_drop_down),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(
                                    'ทุกฝั่ง',
                                    style: TextStyle(
                                      fontFamily: 'Kanit',
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                ...globalMeetingRooms.value
                                    .map((room) => room.location)
                                    .where((loc) => loc.trim().isNotEmpty)
                                    .toSet()
                                    .map((location) {
                                      return DropdownMenuItem<String?>(
                                        value: location,
                                        child: Text(
                                          location,
                                          style: const TextStyle(
                                            fontFamily: 'Kanit',
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    })
                                    .toList(),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _selectedLocation = val;
                                  _selectedRoomId = null;
                                });
                                _fetchEventsForCurrentView();
                              },
                            ),
                          ),
                        ],
                      );

                      Widget roomFilter = Row(
                        children: [
                          const Text(
                            'ห้อง:',
                            style: TextStyle(
                              fontFamily: 'Kanit',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                final filteredRooms = globalMeetingRooms.value
                                    .where((room) {
                                      if (_selectedLocation == null)
                                        return true;
                                      return room.location == _selectedLocation;
                                    })
                                    .toList();

                                if (_selectedLocation != null &&
                                    filteredRooms.isEmpty) {
                                  return DropdownButton<int?>(
                                    value: null,
                                    isExpanded: true,
                                    isDense: true,
                                    underline: const SizedBox(),
                                    icon: const Icon(
                                      Icons.arrow_drop_down,
                                      color: Colors.grey,
                                    ),
                                    items: const [
                                      DropdownMenuItem<int?>(
                                        value: null,
                                        child: Text(
                                          'ไม่มีห้องประชุม',
                                          style: TextStyle(
                                            fontFamily: 'Kanit',
                                            color: Colors.grey,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: null,
                                  );
                                }

                                return DropdownButton<int?>(
                                  value: _selectedRoomId,
                                  isExpanded: true,
                                  isDense: true,
                                  underline: const SizedBox(),
                                  icon: const Icon(Icons.arrow_drop_down),
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text(
                                        'ทุกห้อง',
                                        style: TextStyle(
                                          fontFamily: 'Kanit',
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    ...filteredRooms.map((room) {
                                      return DropdownMenuItem<int?>(
                                        value: int.tryParse(room.id.toString()),
                                        child: Text(
                                          room.roomName,
                                          style: const TextStyle(
                                            fontFamily: 'Kanit',
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedRoomId = val;
                                    });
                                    _fetchEventsForCurrentView();
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      );

                      if (isWide) {
                        return Row(
                          children: [
                            Expanded(flex: 2, child: locationFilter),
                            Container(
                              width: 1,
                              height: 20,
                              color: Colors.grey.shade300,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                            ),
                            Expanded(flex: 3, child: roomFilter),
                          ],
                        );
                      } else {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            locationFilter,
                            const SizedBox(height: 6),
                            roomFilter,
                          ],
                        );
                      }
                    },
                  ),
          ),
          const Divider(height: 1),

          // 🏷️ บาร์แสดงสัญลักษณ์สถานะการจอง
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            color: Colors.grey.shade100,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendBadge(const Color(0xFFF59E0B), 'RESERVED'),
                  const SizedBox(width: 16),
                  _buildLegendBadge(const Color(0xFF004381), 'IN_USE'),
                ],
              ),
            ),
          ),

          // ส่วนแสดงปฏิทิน
          TableCalendar<CalendarEvent>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              if (!isSameDay(_selectedDay, selectedDay)) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              }
            },
            availableCalendarFormats: const {
              CalendarFormat.month: '1 เดือน',
              CalendarFormat.twoWeeks: '2 สัปดาห์',
              CalendarFormat.week: '1 สัปดาห์',
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
              // ดึงข้อมูลใหม่เมื่อเปลี่ยนเดือน (ถ้าจำเป็น)
              _fetchEventsForCurrentView();
            },
            eventLoader: _getEventsForDay,
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.blueGrey,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Color(0xFF00529B),
                shape: BoxShape.circle,
              ),
              markerSize: 6.0,
            ),
            calendarBuilders: CalendarBuilders(
              // ปรับแต่งการแสดงผลแถบสถานะหรือ Marker ใต้วันที่
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return const SizedBox();

                final normalizedDay = DateTime(day.year, day.month, day.day);

                // หากเป็นปฏิทินรถยนต์ ให้แสดงเป็น Continuous Event Bar ลากยาวต่อเนื่องตั้งแต่วันเริ่มต้นถึงวันสิ้นสุด
                if (widget.category == 'VEHICLE') {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: events.take(2).map((event) {
                      final startDay = DateTime(
                        event.start.year,
                        event.start.month,
                        event.start.day,
                      );
                      final endDay = DateTime(
                        event.end.year,
                        event.end.month,
                        event.end.day,
                      );

                      final isStart = isSameDay(normalizedDay, startDay);
                      final isEnd = isSameDay(normalizedDay, endDay);

                      return Container(
                        height: 5.0,
                        margin: EdgeInsets.only(
                          top: 1.0,
                          bottom: 1.0,
                          left: isStart ? 4.0 : 0.0,
                          right: isEnd ? 4.0 : 0.0,
                        ),
                        decoration: BoxDecoration(
                          color: event.color,
                          borderRadius: BorderRadius.horizontal(
                            left: isStart
                                ? const Radius.circular(3.0)
                                : Radius.zero,
                            right: isEnd
                                ? const Radius.circular(3.0)
                                : Radius.zero,
                          ),
                        ),
                      );
                    }).toList(),
                  );
                }

                // สำหรับห้องประชุม คงจุด Marker แบบเดิม
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: events.take(4).map((event) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.0),
                      width: 6.0,
                      height: 6.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: event.color,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),

          const Divider(height: 1),

          // ข้อความแสดงสถานะโหลดข้อมูล
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Center(child: CircularProgressIndicator()),
            ),

          // แสดงรายละเอียดการจองในวันที่เลือก
          Expanded(child: _buildEventList()),
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
}
