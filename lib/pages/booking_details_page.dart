import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:client_app/constants.dart';

enum BookingStatus { free, pending, confirmed }

BookingStatus parseStatus(String? status) {
  switch (status) {
    case "pending":
      return BookingStatus.pending;
    case "confirmed":
      return BookingStatus.confirmed;
    default:
      return BookingStatus.free;
  }
}

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

  Future<bool> _acceptBooking() async {
    if (booking == null) return false;
    final response = await http.patch(
      Uri.parse("${apiUrl}clients/acceptBooking/${booking!['booking_id']}"),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200;
  }

  Future<bool> _rejectBooking() async {
    if (booking == null) return false;
    final response = await http.delete(
      Uri.parse("${apiUrl}clients/rejectBooking/${booking!['booking_id']}"),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200;
  }

  Color _statusColor(BookingStatus status) {
    const map = {
      BookingStatus.confirmed: Colors.blue,
      BookingStatus.pending: Colors.orange,
      BookingStatus.free: Colors.green,
    };
    return map[status] ?? Colors.blueGrey;
  }

  IconData _statusIcon(BookingStatus status) {
    const map = {
      BookingStatus.confirmed: Icons.check_circle,
      BookingStatus.pending: Icons.hourglass_bottom,
      BookingStatus.free: Icons.info,
    };
    return map[status] ?? Icons.info;
  }

  @override
  Widget build(BuildContext context) {
    final status = parseStatus(booking?['booking_status'] ?? (isManualBlocked ? "unavailable" : "free"));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("تفاصيل الحجز", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        backgroundColor: Colors.red.shade50,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                BookingInfoCard(field: field, booking: booking, status: status, statusColor: _statusColor(status), statusIcon: _statusIcon(status)),
                const SizedBox(height: 16),
                BookingTimeCard(start: start, end: end, price: booking?['booking_total_price']),
                const SizedBox(height: 16),
                if (booking?['booking_notes'] != null && booking!['booking_notes'].toString().trim().isNotEmpty)
                  BookingNotesCard(notes: booking!['booking_notes']),
                const SizedBox(height: 20),
                if (status == BookingStatus.pending)
                  BookingActionsRow(
                    onAccept: _acceptBooking,
                    onReject: _rejectBooking,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BookingInfoCard extends StatelessWidget {
  final Map<String, dynamic> field;
  final Map<String, dynamic>? booking;
  final BookingStatus status;
  final Color statusColor;
  final IconData statusIcon;

  const BookingInfoCard({
    super.key,
    required this.field,
    this.booking,
    required this.status,
    required this.statusColor,
    required this.statusIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(field['field_name'] ?? "ملعب غير معروف", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (booking != null) ...[
            Row(
              children: [
                const Icon(Icons.person, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(child: Text(booking!['booking_user'] ?? "مستخدم غير معروف", style: const TextStyle(fontSize: 16))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone, color: Colors.red),
                const SizedBox(width: 8),
                SelectableText(booking!['booking_user_phone_number'] ?? "بدون رقم هاتف", style: const TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [Icon(statusIcon, color: statusColor), const SizedBox(width: 8), Text(AppFormat.translateStatus(status.name), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: statusColor))]),
              if (booking != null) Text("رمز الحجز: ${booking!['booking_id']}", style: const TextStyle(fontSize: 16)),
            ],
          ),
        ]),
      ),
    );
  }
}

class BookingTimeCard extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  final dynamic price;
  const BookingTimeCard({super.key, required this.start, required this.end, this.price});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const Icon(Icons.access_time, color: Colors.red, size: 32),
          const SizedBox(height: 8),
          Text("${AppFormat.formatTime(start)} - ${AppFormat.formatTime(end)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(AppFormat.formatDateArabic(start), style: const TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.bottomRight,
            child: Text("السعر: ${price ?? "--"} دينار", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
          ),
        ]),
      ),
    );
  }
}

class BookingNotesCard extends StatelessWidget {
  final String notes;
  const BookingNotesCard({super.key, required this.notes});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.note, color: Colors.red, size: 28),
          const SizedBox(height: 10),
          const Text("ملاحظات", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
          const SizedBox(height: 8),
          Text(notes, style: const TextStyle(fontSize: 16)),
        ]),
      ),
    );
  }
}

class BookingActionsRow extends StatelessWidget {
  final Future<bool> Function() onAccept;
  final Future<bool> Function() onReject;

  const BookingActionsRow({super.key, required this.onAccept, required this.onReject});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text("قبول", style: TextStyle(color: Colors.white)),
            onPressed: () async {
              final confirm = await showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("هل تريد قبول هذا الحجز؟"),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("لا")),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("نعم")),
                  ],
                ),
              );
              if (confirm == true) {
                final success = await onAccept();
                if (success) Navigator.pop(context, true);
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
            icon: const Icon(Icons.close, color: Colors.red),
            label: const Text("رفض"),
            onPressed: () async {
              final confirm = await showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("هل تريد رفض هذا الحجز؟"),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("لا")),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("نعم")),
                  ],
                ),
              );
              if (confirm == true) {
                final success = await onReject();
                if (success) Navigator.pop(context, true);
              }
            },
          ),
        ),
      ],
    );
  }
}
