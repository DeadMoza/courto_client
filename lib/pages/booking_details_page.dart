import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BookingDetailsPage extends StatelessWidget {
  final Map<String, dynamic>? booking;
  final DateTime start;
  final DateTime end;
  final Map<String, dynamic> field;
  final String? token;
  final bool isManualBlocked; // for gray slots

  const BookingDetailsPage({
    super.key,
    required this.booking,
    required this.start,
    required this.end,
    required this.field,
    this.token,
    this.isManualBlocked = false,
  });

  String formatTime(DateTime t) => DateFormat.jm().format(t);

  int calculateHours() {
    return end.difference(start).inHours;
  }

  double calculateCost() {
    return (field['field_price'] as num).toDouble() * calculateHours();
  }

  @override
  Widget build(BuildContext context) {
    bool isBooked = booking != null;
    String status = booking?['booking_status'] ?? "";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Booking Details", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isManualBlocked
            ? _buildManualBlocked(context)
            : !isBooked
                ? _buildEmptySlot(context)
                : status == "confirmed"
                    ? _buildConfirmed(context)
                    : _buildPending(context),
      ),
    );
  }

  Widget _buildConfirmed(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Booking Time: ${formatTime(start)} - ${formatTime(end)}"),
        const SizedBox(height: 12),
        Text("User: ${booking!['booking_user']}"),
        Text("Phone: ${booking!['booking_user_phone_number']}"),
        const SizedBox(height: 12),
        Text("Total Cost: ${calculateCost()} Dinars",
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildPending(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Booking Request: ${formatTime(start)} - ${formatTime(end)}"),
        const SizedBox(height: 12),
        Text("User: ${booking!['booking_user']}"),
        Text("Phone: ${booking!['booking_user_phone_number']}"),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Confirm Booking?"),
                      content: const Text("This booking cannot be cancelled after confirmation. Are you sure?"),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No")),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Yes")),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    // TODO: Call API to accept booking
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Booking confirmed")));
                    Navigator.pop(context, true);
                  }
                },
                child: const Text("Accept"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  // TODO: Call API to deny booking
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Booking denied")));
                  Navigator.pop(context, true);
                },
                child: const Text("Deny"),
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildEmptySlot(BuildContext context) {
    return Center(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
        onPressed: () async {
          final mark = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Mark as booked?"),
              content: const Text("This will block the slot."),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No")),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Yes")),
              ],
            ),
          );
          if (mark == true) {
            // TODO: Call API to mark slot as blocked
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Slot marked as booked")));
            Navigator.pop(context, true);
          }
        },
        child: const Text("Mark as Booked"),
      ),
    );
  }

  Widget _buildManualBlocked(BuildContext context) {
    return Center(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
        onPressed: () async {
          final unmark = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Mark as not booked?"),
              content: const Text("This will free the slot."),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No")),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Yes")),
              ],
            ),
          );
          if (unmark == true) {
            // TODO: Call API to unmark slot
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Slot unmarked")));
            Navigator.pop(context, true);
          }
        },
        child: const Text("Unmark Slot"),
      ),
    );
  }
}
