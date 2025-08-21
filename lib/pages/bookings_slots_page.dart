import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'booking_details_page.dart';

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

    // Track bookings & assign colors
    List<Color?> backgrounds = List.filled(slots.length, null);
    List<String?> bookedByList = List.filled(slots.length, null);

    for (int i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final booking = _findBookingForSlot(slot);

      if (booking != null) {
        String status = booking['booking_status'] ?? "";
        String bookedBy = booking['booking_user'] ?? "";
        bookedByList[i] = bookedBy;

        if (status == "pending") {
          backgrounds[i] = Colors.yellow[200]; // pending
        } else if (status == "confirmed") {
          backgrounds[i] = Colors.blue[100]; // confirmed
        }
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
          final booking = _findBookingForSlot(slot);

          bool isBooked = booking != null;
          String bookedBy = booking?['booking_user'] ?? "";

          // ---- Group rounding logic ----
          bool sameAsPrev =
              i > 0 && bookedByList[i] != null && bookedByList[i] == bookedByList[i - 1];
          bool sameAsNext =
              i < slots.length - 1 && bookedByList[i] != null && bookedByList[i] == bookedByList[i + 1];

          BorderRadius radius;
          if (sameAsPrev && sameAsNext) {
            radius = BorderRadius.zero; // middle
          } else if (sameAsPrev && !sameAsNext) {
            radius = const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ); // last
          } else if (!sameAsPrev && sameAsNext) {
            radius = const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ); // first
          } else {
            radius = BorderRadius.circular(12); // isolated
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
              onTap: () {
                if (isBooked) {
                  // ---- Group consecutive slots for same booking ----
                  int first = i;
                  int last = i;
                  while (first > 0 && bookedByList[first - 1] == bookedByList[i]) {
                    first--;
                  }
                  while (last < slots.length - 1 &&
                      bookedByList[last + 1] == bookedByList[i]) {
                    last++;
                  }

                  // Re-fetch correct booking object
                  final groupBooking = _findBookingForSlot(slots[first]);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingDetailsPage(
                        booking: groupBooking,
                        start: slots[first].start,
                        end: slots[last].end,
                        field: field,
                        token: token,
                      ),
                    ),
                  );
                } else {
                  // Empty slot
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingDetailsPage(
                        booking: null,
                        start: slot.start,
                        end: slot.end,
                        field: field,
                        token: token,
                        isManualBlocked: backgrounds[i] == Colors.grey[300],
                      ),
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }

  /// Finds booking that covers this slot (start <= slot.start < end)
  Map<String, dynamic>? _findBookingForSlot(TimeSlot slot) {
    return bookings.firstWhere(
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
}

class TimeSlot {
  final DateTime start;
  final DateTime end;
  TimeSlot({required this.start, required this.end});
}
