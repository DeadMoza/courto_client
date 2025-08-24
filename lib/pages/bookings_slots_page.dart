import 'package:client_app/constants.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'booking_details_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BookingSlotsPage extends StatefulWidget {
  final Map<String, dynamic> field;
  final DateTime date;
  final String? token;
  final List<dynamic> bookings;

  const BookingSlotsPage({
    super.key,
    required this.field,
    required this.date,
    this.token,
    required this.bookings,
  });

  @override
  State<BookingSlotsPage> createState() => _BookingSlotsPageState();
}

class _BookingSlotsPageState extends State<BookingSlotsPage> {
  late List<TimeSlot> slots;
  late List<Color?> backgrounds;
  late List<String?> bookedByList;
  late List<dynamic> currentBookings;

  @override
  void initState() {
    super.initState();
    currentBookings = List.from(widget.bookings);
    _trackBookings();
  }

  void _generateSlots() {
    final openParts = (widget.field['field_open_time'] ?? '08:00').split(':');
    final closeParts = (widget.field['field_close_time'] ?? '20:00').split(':');
    int openHour = int.parse(openParts[0]);
    int closeHour = int.parse(closeParts[0]);
    if (closeHour <= openHour) closeHour += 24;

    slots = [];
    for (int hour = openHour; hour < closeHour; hour++) {
      DateTime start = DateTime(widget.date.year, widget.date.month, widget.date.day, hour % 24);
      DateTime end = DateTime(widget.date.year, widget.date.month, widget.date.day, (hour + 1) % 24);
      if ((hour + 1) >= 24) end = end.add(const Duration(days: 1));
      slots.add(TimeSlot(start: start, end: end));
    }
  }

  String formatTime(DateTime time) => DateFormat.jm().format(time);

  String formatHM(DateTime dt) =>
      "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

  void _trackBookings() {
    _generateSlots();
    backgrounds = List.filled(slots.length, null);
    bookedByList = List.filled(slots.length, null);

    for (int i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final booking = _findBookingForSlot(slot);

      if (booking != null) {
        String status = booking['booking_status'] ?? "";

        // cancelled behaves like free
        if (status == "cancelled") status = "free";

        if (status == "pending") {
          backgrounds[i] = Colors.yellow[200];
          bookedByList[i] = booking['booking_user'] ?? "";
        } else if (status == "confirmed") {
          backgrounds[i] = Colors.blue[100];
          bookedByList[i] = booking['booking_user'] ?? "";
        } else if (status == "unavailable") {
          backgrounds[i] = Colors.grey[400];
          bookedByList[i] = null;
        } else {
          backgrounds[i] = Colors.white; // free
          bookedByList[i] = null;
        }
      } else {
        backgrounds[i] = Colors.white; // free
        bookedByList[i] = null;
      }
    }
    setState(() {});
  }

  Map<String, dynamic>? _findBookingForSlot(TimeSlot slot) {
    return currentBookings.firstWhere(
      (b) {
        final bookingDate = DateTime.parse(b['booking_date']);
        final startParts = (b['start_time'] as String).split(':');
        final endParts = (b['end_time'] as String).split(':');

        final start = DateTime(
          bookingDate.year,
          bookingDate.month,
          bookingDate.day,
          int.parse(startParts[0]),
          int.parse(startParts[1]),
        );
        final end = DateTime(
          bookingDate.year,
          bookingDate.month,
          bookingDate.day,
          int.parse(endParts[0]),
          int.parse(endParts[1]),
        );

        return slot.start.isAtSameMomentAs(start) ||
            (slot.start.isAfter(start) && slot.start.isBefore(end));
      },
      orElse: () => null,
    );
  }

  Future<void> _refreshBookings() async {
    final response = await http.get(
      Uri.parse("${apiUrl}api/clients/getBookings/${widget.field['field_id']}"),
      headers: {'Authorization': 'Bearer ${widget.token}'},
    );

    if (response.statusCode == 200) {
      setState(() {
        currentBookings = jsonDecode(response.body);
      });
      _trackBookings();
    }
  }

  Future<void> _markUnavailable(TimeSlot slot) async {
    final response = await http.post(
      Uri.parse("${apiUrl}api/clients/blockBookingSlot"),
      headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json'},
      body: jsonEncode({
        'field_id': widget.field['field_id'],
        'booking_date': slot.start.toIso8601String().split('T')[0],
        'start_time': formatHM(slot.start),
        'end_time': formatHM(slot.end),
      }),
    );

    if (response.statusCode == 200) {
      await _refreshBookings();
    }
  }

  Future<void> _markAvailable(TimeSlot slot) async {
    final url = Uri.parse("${apiUrl}api/clients/unblockBookingSlot");
    final request = http.Request("DELETE", url)
      ..headers.addAll({
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      })
      ..body = jsonEncode({
        "field_id": widget.field['field_id'],
        "booking_date": slot.start.toIso8601String().split('T')[0],
        "start_time": formatHM(slot.start),
        "end_time": formatHM(slot.end),
      });

    final response = await request.send();
    if (response.statusCode == 200) {
      await _refreshBookings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Booking Slots - ${DateFormat.yMd().format(widget.date)}",
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: slots.length,
        itemBuilder: (context, i) {
          final slot = slots[i];
          final booking = _findBookingForSlot(slot);

          String status = booking?['booking_status'] ?? "free";
          if (status == "cancelled") status = "free";

          bool isBooked = status == "pending" || status == "confirmed";
          bool isUnavailable = status == "unavailable";
          String bookedBy = booking?['booking_user'] ?? "";

          // group rounding
          bool sameAsPrev = i > 0 && bookedByList[i] != null && bookedByList[i] == bookedByList[i - 1];
          bool sameAsNext = i < slots.length - 1 && bookedByList[i] != null && bookedByList[i] == bookedByList[i + 1];

          BorderRadius radius;
          if (sameAsPrev && sameAsNext) {
            radius = BorderRadius.zero;
          } else if (sameAsPrev && !sameAsNext) {
            radius = const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12));
          } else if (!sameAsPrev && sameAsNext) {
            radius = const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12));
          } else {
            radius = BorderRadius.circular(12);
          }

          return Container(
            margin: EdgeInsets.only(bottom: sameAsNext ? 0 : 6),
            decoration: BoxDecoration(
              color: backgrounds[i] ?? Colors.white,
              borderRadius: radius,
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              title: Center(
                child: Text(
                  "${formatTime(slot.start)} - ${formatTime(slot.end)}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              subtitle: isBooked && !sameAsPrev
                  ? Center(child: Text("Booked by $bookedBy"))
                  : null,
              onTap: () async {
                if (status == "free") {
                  bool? mark = await showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("Mark as unavailable?"),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes")),
                      ],
                    ),
                  );
                  if (mark == true) await _markUnavailable(slot);
                } else if (isUnavailable) {
                  bool? mark = await showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("Mark as available?"),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes")),
                      ],
                    ),
                  );
                  if (mark == true) await _markAvailable(slot);
                } else {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingDetailsPage(
                        booking: booking,
                        start: slot.start,
                        end: slot.end,
                        field: widget.field,
                        token: widget.token,
                      ),
                    ),
                  );
                  if (result == true) await _refreshBookings();
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class TimeSlot {
  final DateTime start;
  final DateTime end;
  TimeSlot({required this.start, required this.end});
}
