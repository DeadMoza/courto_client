import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BookingSlotsPage extends StatelessWidget {
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

  String formatTime(DateTime time) {
    return DateFormat.jm().format(time);
  }

  @override
  Widget build(BuildContext context) {
    final openParts = (field['field_open_time'] ?? '08:00').split(':');
    final closeParts = (field['field_close_time'] ?? '20:00').split(':');
    int openHour = int.parse(openParts[0]);
    int closeHour = int.parse(closeParts[0]);
    if (closeHour <= openHour) closeHour += 24;

    // Generate slots
    List<TimeSlot> slots = [];
    for (int hour = openHour; hour < closeHour; hour++) {
      DateTime start = DateTime(date.year, date.month, date.day, hour % 24);
      DateTime end = DateTime(date.year, date.month, date.day, (hour + 1) % 24);
      if ((hour + 1) >= 24) end = end.add(const Duration(days: 1));
      slots.add(TimeSlot(start: start, end: end));
    }

    // Assign background colors + track users
    List<Color?> backgrounds = List.filled(slots.length, null);
    List<String?> bookedByList = List.filled(slots.length, null);

    for (int i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final booking = bookings.firstWhere(
        (b) {
          final bookingDate = DateTime.parse(b['booking_date']);
          final startParts = (b['start_time'] as String).split(':');
          final start = DateTime(
            bookingDate.year,
            bookingDate.month,
            bookingDate.day,
            int.parse(startParts[0]),
            int.parse(startParts[1]),
          );
          return slot.start.isAtSameMomentAs(start);
        },
        orElse: () => null,
      );

      if (booking != null) {
        String status = booking['booking_status'] ?? "";
        String bookedBy = booking['booking_user'] ?? "";
        bookedByList[i] = bookedBy;

        if (status == "pending") status = "Respond to request";
        backgrounds[i] =
            status == "Respond to request" ? Colors.yellow[200] : Colors.blue[100];
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Booking Slots - ${DateFormat.yMd().format(date)}",
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
          final booking = bookings.firstWhere(
            (b) {
              final bookingDate = DateTime.parse(b['booking_date']);
              final startParts = (b['start_time'] as String).split(':');
              final start = DateTime(
                bookingDate.year,
                bookingDate.month,
                bookingDate.day,
                int.parse(startParts[0]),
                int.parse(startParts[1]),
              );
              return slot.start.isAtSameMomentAs(start);
            },
            orElse: () => null,
          );

          bool isBooked = booking != null;
          String status = booking?['booking_status'] ?? "";
          String bookedBy = booking?['booking_user'] ?? "";
          if (status == "pending") status = "Respond to request";

          // ---- Group rounding logic ----
          bool sameAsPrev = i > 0 && bookedByList[i] != null && bookedByList[i] == bookedByList[i - 1];
          bool sameAsNext = i < slots.length - 1 && bookedByList[i] != null && bookedByList[i] == bookedByList[i + 1];

          BorderRadius radius;
          if (sameAsPrev && sameAsNext) {
            // middle tile
            radius = BorderRadius.zero;
          } else if (sameAsPrev && !sameAsNext) {
            // last tile
            radius = const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            );
          } else if (!sameAsPrev && sameAsNext) {
            // first tile
            radius = const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            );
          } else {
            // isolated tile
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
              subtitle: isBooked
                  ? Center(child: Text("Booked by $bookedBy"))
                  : null,
              onTap: isBooked ? () {} : null,
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
