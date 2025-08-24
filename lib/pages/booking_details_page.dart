import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:client_app/constants.dart';

class BookingDetailsPage extends StatelessWidget {
  final Map<String, dynamic>? booking;
  final DateTime start;
  final DateTime end;
  final Map<String, dynamic> field;
  final String? token;
  final bool isManualBlocked;

  const BookingDetailsPage({
    super.key,
    this.booking,
    required this.start,
    required this.end,
    required this.field,
    this.token,
    this.isManualBlocked = false,
  });

  String formatTime(DateTime time) => DateFormat.jm().format(time);

  String formatHM(DateTime dt) =>
      "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

  Future<bool> _acceptBooking() async {
    if (booking == null) return false;
    final response = await http.patch(
      Uri.parse("${apiUrl}api/clients/acceptBooking/${booking!['booking_id']}"),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200;
  }

  Future<bool> _rejectBooking() async {
    if (booking == null) return false;
    final response = await http.delete(
      Uri.parse("${apiUrl}api/clients/rejectBooking/${booking!['booking_id']}"),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200;
  }

  Color _statusColor(String status) {
    switch (status) {
      case "confirmed":
        return Colors.green;
      case "pending":
        return Colors.orange;
      case "unavailable":
        return Colors.grey;
      case "rejected":
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case "confirmed":
        return Icons.check_circle;
      case "pending":
        return Icons.hourglass_bottom;
      case "unavailable":
        return Icons.block;
      case "rejected":
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status =
        booking?['booking_status'] ?? (isManualBlocked ? "unavailable" : "free");

    return Scaffold(
      appBar: AppBar(
        title: const Text("Booking Details"),
        backgroundColor: Colors.red,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Card with field & status
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field['field_name'] ?? "Unknown Field",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(_statusIcon(status), color: _statusColor(status)),
                        const SizedBox(width: 8),
                        Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _statusColor(status),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Time card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 3,
              child: ListTile(
                leading: const Icon(Icons.access_time, color: Colors.red),
                title: Text(
                  "${formatTime(start)} - ${formatTime(end)}",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  DateFormat.yMMMMd().format(start),
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // User card
            if (booking != null)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 3,
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.red,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(
                    booking!['booking_user'] ?? "Unknown User",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text("Booking ID: ${booking!['booking_id']}"),
                ),
              ),

            const Spacer(),

            // Action buttons
            if (status == "pending")
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text("Accept", style: TextStyle(color: Colors.white)),
                      onPressed: () async {
                        bool? confirm = await showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("Accept this booking?"),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text("No")),
                              TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("Yes")),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          final success = await _acceptBooking();
                          if (success) Navigator.pop(context, true);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.close, color: Colors.white),
                      label: const Text("Reject", style: TextStyle(color: Colors.white)),
                      onPressed: () async {
                        bool? confirm = await showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("Reject this booking?"),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text("No")),
                              TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("Yes")),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          final success = await _rejectBooking();
                          if (success) Navigator.pop(context, true);
                        }
                      },
                    ),
                  ),
                ],
              ),
            if (status == "confirmed")
              const Text(
                "✅ Booking is confirmed.",
                style: TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}
