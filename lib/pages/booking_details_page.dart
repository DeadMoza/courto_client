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
        return Colors.blue;
      case "pending":
        return Colors.orange;
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
        title: const Text("Booking Details", style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.red,
      ),
      backgroundColor: Colors.red.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // First Card: Field, Status + ID, User Info
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Field Name
                      Text(
                        field['field_name'] ?? "Unknown Field",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // User Info
                      if (booking != null) ...[
                        Row(
                          children: [
                            const Icon(Icons.person, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                booking!['booking_user'] ?? "Unknown User",
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.phone, color: Colors.red),
                            const SizedBox(width: 8),
                            SelectableText(
                              booking!['booking_user_phone_number'] ?? "No Phone",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      // Row 2: Status + Booking ID
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
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
                          if (booking != null)
                            Text(
                              "ID: ${booking!['booking_id']}",
                              style: const TextStyle(fontSize: 16),
                            ),
                        ],
                      ),

                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Second Card: Time, Date, Price
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.access_time, color: Colors.red, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        "${formatTime(start)} - ${formatTime(end)}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat.yMMMMd().format(start),
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          "Price: ${booking?['booking_total_price'] ?? "--"} LYD",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Third Card: Notes
              if (booking?['booking_notes'] != null &&
                  booking!['booking_notes'].toString().trim().isNotEmpty)
                Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.note, color: Colors.red, size: 28),
                        const SizedBox(height: 10),
                        const Text(
                          "Notes",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          booking!['booking_notes'],
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // Action buttons
              if (status == "pending")
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                                  child: const Text("No"),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("Yes"),
                                ),
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
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.close, color: Colors.red),
                        label: const Text("Reject"),
                        onPressed: () async {
                          bool? confirm = await showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("Reject this booking?"),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text("No"),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("Yes"),
                                ),
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
            ],
          ),
        ),
      ),
    );
  }
}
