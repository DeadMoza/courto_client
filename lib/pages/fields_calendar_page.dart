import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'bookings_slots_page.dart';
import 'package:intl/intl.dart';

class FieldsCalendarPage extends StatefulWidget {
  final Map<String, dynamic> field;
  final String? token;

  const FieldsCalendarPage({super.key, required this.field, this.token});

  @override
  _FieldsCalendarPageState createState() => _FieldsCalendarPageState();
}

class _FieldsCalendarPageState extends State<FieldsCalendarPage> {
  Map<DateTime, List<dynamic>> bookingsByDate = {};
  DateTime focusedDay = DateTime.now();
  DateTime? selectedDay;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchBookings();
  }

  Future<void> fetchBookings() async {
    setState(() => loading = true);
    final url = Uri.parse(
        "http://192.168.3.180:3000/api/clients/getfieldBookings/${widget.field['field_id']}");

    try {
      final res = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.token}",
        },
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final Map<DateTime, List<dynamic>> temp = {};

        for (var booking in data["bookings"]) {
          final day = DateTime.parse(booking["booking_date"]);
          final simpleDay = DateTime(day.year, day.month, day.day);
          (temp[simpleDay] ??= []).add(booking);
        }

        setState(() {
          bookingsByDate = temp;
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      setState(() => loading = false);
    }
  }

  List<dynamic> _getBookingsForDay(DateTime day) {
    final simpleDay = DateTime(day.year, day.month, day.day);
    return bookingsByDate[simpleDay] ?? [];
  }

  int _toMinutes(String t) {
    final p = t.split(':');
    final hh = int.parse(p[0]);
    final mm = int.parse(p[1]);
    return hh * 60 + mm;
  }

  int _countBookingGroups(List<dynamic> bookings) {
    if (bookings.isEmpty) return 0;

    final items = bookings.map((b) {
      final s = b['start_time'] as String;
      final e = b['end_time'] as String;
      return {
        'start': _toMinutes(s),
        'end': _toMinutes(e),
        'user': b['booking_user']?.toString()
      };
    }).toList();

    items.sort((a, b) {
      final c = (a['start'] as int).compareTo(b['start'] as int);
      return c != 0 ? c : (a['end'] as int).compareTo(b['end'] as int);
    });

    int groups = 0;
    int currentEnd = -1;
    String? currentUser;

    for (final it in items) {
      final start = it['start'] as int;
      final end = it['end'] as int;
      final user = it['user'] as String?;

      if (groups == 0) {
        groups = 1;
        currentEnd = end;
        currentUser = user;
        continue;
      }

      final sameUser = (currentUser == null || user == currentUser);
      final contiguous = start == currentEnd;

      if (contiguous && sameUser) {
        currentEnd = end;
      } else {
        groups++;
        currentEnd = end;
        currentUser = user;
      }
    }
    return groups;
  }

  String formatTime(String time) {
    try {
      final parts = time.split(":");
      final dt = DateTime(0, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
      return DateFormat.jm().format(dt);
    } catch (e) {
      return time;
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final lastDay = today.add(const Duration(days: 365));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.field['field_name']),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : SafeArea(
              child: NestedScrollView(
                headerSliverBuilder:
                    (BuildContext context, bool innerBoxIsScrolled) {
                  return <Widget>[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: TableCalendar(
                          firstDay: today,
                          lastDay: lastDay,
                          focusedDay: focusedDay,
                          rowHeight: 52,
                          selectedDayPredicate: (day) =>
                              isSameDay(selectedDay, day),
                          onDaySelected: (selected, focused) {
                            setState(() {
                              selectedDay = selected;
                              focusedDay = focused;
                            });
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookingSlotsPage(
                                  field: widget.field,
                                  date: selected,
                                  token: widget.token,
                                  bookings: _getBookingsForDay(selected),
                                ),
                              ),
                            );
                          },
                          eventLoader: (_) => const [],
                          calendarStyle: const CalendarStyle(
                            cellPadding: EdgeInsets.zero,
                            cellMargin: EdgeInsets.zero,
                            todayDecoration: BoxDecoration(),
                            selectedDecoration: BoxDecoration(),
                          ),
                          calendarBuilders: CalendarBuilders(
                            defaultBuilder: (context, day, _) {
                              final fill = _fillForDay(day);
                              return _buildDayCell(
                                day,
                                fill: fill,
                                border: Colors.transparent,
                                isToday: isSameDay(day, DateTime.now()),
                                isSelected: isSameDay(day, selectedDay),
                              );
                            },
                            outsideBuilder: (context, day, _) {
                              final fill = _fillForDay(day);
                              return _buildDayCell(
                                day,
                                fill: fill.withOpacity(0.25),
                                border: Colors.transparent,
                                textColor: Colors.black45,
                                isToday: isSameDay(day, DateTime.now()),
                                isSelected: isSameDay(day, selectedDay),
                              );
                            },
                            todayBuilder: (context, day, _) {
                              final fill = _fillForDay(day);
                              return _buildDayCell(
                                day,
                                fill: fill,
                                border: Colors.grey,
                                isToday: true,
                                isSelected: isSameDay(day, selectedDay),
                              );
                            },
                            selectedBuilder: (context, day, _) {
                              final fill = _fillForDay(day);
                              return _buildDayCell(
                                day,
                                fill: fill,
                                border: Colors.black,
                                isSelected: true,
                                isToday: isSameDay(day, DateTime.now()),
                              );
                            },
                            markerBuilder: (context, day, _) {
                              final groups =
                                  _countBookingGroups(_getBookingsForDay(day));
                              if (groups <= 0) return const SizedBox.shrink();
                              const maxDots = 6;
                              final dots = groups > maxDots ? maxDots : groups;

                              return Positioned(
                                bottom: 4,
                                left: 0,
                                right: 0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(dots, (i) {
                                    return Container(
                                      width: 6,
                                      height: 6,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 1.5),
                                      decoration: const BoxDecoration(
                                        color: Colors.black,
                                        shape: BoxShape.circle,
                                      ),
                                    );
                                  }),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ];
                },
                body: ListView(
                  children: selectedDay == null
                      ? []
                      : _getBookingsForDay(selectedDay!).map((booking) {
                          final bookingTime =
                              "${formatTime(booking['start_time'])} - ${formatTime(booking['end_time'])}";
                          final user = booking['booking_user'] ?? '';
                          final status = booking['booking_status'] ?? '';

                          return Container(
                            margin: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Time: $bookingTime",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "User: $user",
                                  style: const TextStyle(color: Colors.black87),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Status: $status",
                                  style:
                                      const TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                ),
              ),
            ),
    );
  }

  Color _fillForDay(DateTime day) {
    final bookings = _getBookingsForDay(day);
    if (bookings.isEmpty) return Colors.transparent;

    final confirmed = bookings
        .where((b) => (b['booking_status']?.toString().toLowerCase() ?? '') == 'confirmed')
        .length;

    if (confirmed == bookings.length) {
      return Colors.blue;
    } else {
      return Colors.orangeAccent;
    }
  }

  Widget _buildDayCell(
    DateTime day, {
    required Color fill,
    required Color border,
    Color? textColor,
    bool isToday = false,
    bool isSelected = false,
  }) {
    final hasFill = fill != Colors.transparent;
    final numberColor = textColor ?? (hasFill ? Colors.white : Colors.black);

    return Center(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(
            color: border,
            width: border == Colors.transparent ? 0 : 2,
          ),
        ),
        child: Center(
          child: Text(
            '${day.day}',
            style: TextStyle(
              color: numberColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}