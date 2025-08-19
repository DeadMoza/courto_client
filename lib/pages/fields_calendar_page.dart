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
        Map<DateTime, List<dynamic>> temp = {};

        for (var booking in data["bookings"]) {
          DateTime day = DateTime.parse(booking["booking_date"]);
          DateTime simpleDay = DateTime(day.year, day.month, day.day);

          if (!temp.containsKey(simpleDay)) temp[simpleDay] = [];
          temp[simpleDay]!.add(booking);
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

  String formatTime(String time) {
    try {
      final parts = time.split(":");
      final dt = DateTime(0, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
      return DateFormat.jm().format(dt); // e.g. 6:00 PM
    } catch (e) {
      return time; // fallback
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
              child: Column(
                children: [
                  // Calendar
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: TableCalendar(
                      firstDay: today,
                      lastDay: lastDay,
                      focusedDay: focusedDay,
                      selectedDayPredicate: (day) => isSameDay(selectedDay, day),
                      onDaySelected: (selected, focused) {
                        setState(() {
                          selectedDay = selected;
                          focusedDay = focused;
                        });

                        final bookings = _getBookingsForDay(selected);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookingSlotsPage(
                              field: widget.field,
                              date: selected,
                              token: widget.token,
                              bookings: bookings,
                            ),
                          ),
                        );
                      },
                      eventLoader: (day) => _getBookingsForDay(day),
                      calendarStyle: const CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, focusedDay) {
                          final bookings = _getBookingsForDay(day);

                          if (bookings.isNotEmpty) {
                            final confirmed = bookings
                                .where((b) => b['booking_status']
                                    ?.toLowerCase() ==
                                    'confirmed')
                                .length;
                            final total = bookings.length;

                            // 🔵 Fully booked (all confirmed)
                            if (confirmed == total) {
                              return Center(
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${day.day}',
                                      style: const TextStyle(
                                          color: Colors.white),
                                    ),
                                  ),
                                ),
                              );
                            }

                            // 🟡 Some bookings, not all confirmed
                            return Center(
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: Colors.orangeAccent,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${day.day}',
                                    style: const TextStyle(
                                        color: Colors.white),
                                  ),
                                ),
                              ),
                            );
                          }

                          // default rendering for no bookings
                          return null;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bookings list for selected day
                  if (selectedDay != null)
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        children:
                            _getBookingsForDay(selectedDay!).map((booking) {
                          final bookingTime =
                              "${formatTime(booking['start_time'])} - ${formatTime(booking['end_time'])}";
                          final user = booking['booking_user'] ?? '';
                          final status = booking['booking_status'] ?? '';

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
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
                ],
              ),
            ),
    );
  }
}
