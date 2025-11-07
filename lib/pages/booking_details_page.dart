import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:client_app/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';

enum BookingStatus { free, pending, confirmed }
final apiUrl = dotenv.env['API_URL'];

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

Future<Map<String, dynamic>> _acceptBooking() async {
  if (booking == null) return {'success': false, 'message': "بيانات الحجز غير متوفرة"};
  try {
    final response = await http.patch(
      Uri.parse("${apiUrl}clients/acceptBooking/${booking!['booking_id']}/${booking!['user_id']}"),
      headers: {'Authorization': 'Bearer $token', 'x-api-key': '${dotenv.env['API_KEY']}'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);


      // Update AuthService wallet balance if available
      if (data['booking']?['new_wallet_balance'] != null) {
        final newBalance = double.tryParse(data['booking']['new_wallet_balance'].toString()) ?? 0;
        if (AuthService.clientData != null) {
          AuthService.clientData!['wallet_balance'] = newBalance;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('clientData', jsonEncode(AuthService.clientData));

        }
      }

      return {
        'success': true,
        'message': 'تم قبول الحجز بنجاح',
        'new_wallet_balance': AuthService.clientData?['wallet_balance']
      };
    }

    final error = jsonDecode(response.body);
    return {'success': false, 'message': error['error'] ?? 'حدث خطأ غير متوقع'};
  } catch (e) {
    return {'success': false, 'message': 'فشل الاتصال'};
  }
}


  Future<Map<String, dynamic>> _rejectBooking() async {
    if (booking == null) return {'success': false, 'message': "بيانات الحجز غير متوفرة"};
    try {
      final response = await http.delete(
        Uri.parse("${apiUrl}clients/rejectBooking/${booking!['booking_id']}/${booking!['user_id']}"),
        headers: {'Authorization': 'Bearer $token', 'x-api-key': '${dotenv.env['API_KEY']}'},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'تم رفض الحجز بنجاح'};
      }

      final error = jsonDecode(response.body);
      return {'success': false, 'message': error['error'] ?? 'حدث خطأ غير متوقع'};
    } catch (e) {
      return {'success': false, 'message': 'فشل الاتصال بالخادم'};
    }
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
    final status = parseStatus(
      booking?['booking_status'] ?? (isManualBlocked ? "unavailable" : "free"),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("تفاصيل الحجز", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        backgroundColor: Colors.red.shade50,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                BookingInfoCard(
                  field: field,
                  booking: booking,
                  status: status,
                  statusColor: _statusColor(status),
                  statusIcon: _statusIcon(status),
                ),
                const SizedBox(height: 16),
                BookingTimeCard(
                  start: start,
                  end: end,
                  price: booking,
                ),
                const SizedBox(height: 16),
                if (booking?['booking_notes'] != null &&
                    booking!['booking_notes'].toString().trim().isNotEmpty)
                  BookingNotesCard(notes: booking!['booking_notes']),
              ],
            ),
          ),
        ),
        bottomNavigationBar: (status == BookingStatus.pending)
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: BookingActionsRow(
                  onAccept: _acceptBooking,
                  onReject: _rejectBooking,
                ),
              )
            : null,
      ),
    );
  }
}

// ---------------- Booking Info Card ----------------
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
          Text(field['field_name'] ?? "ملعب غير معروف",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (booking != null) ...[
            Row(
              children: [
                const Icon(Icons.person, color: Colors.redAccent),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(booking!['booking_user'] ?? "مستخدم غير معروف",
                        style: const TextStyle(fontSize: 16))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone, color: Colors.redAccent),
                const SizedBox(width: 8),
                SelectableText(
                  booking!['booking_user_phone_number'] ?? "بدون رقم هاتف",
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(statusIcon, color: statusColor),
                const SizedBox(width: 8),
                Text(AppFormat.translateStatus(status.name),
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, color: statusColor))
              ]),
              if (booking != null)
                Text("رمز الحجز: ${booking!['booking_id']}", style: const TextStyle(fontSize: 16)),
            ],
          ),
        ]),
      ),
    );
  }
}

// ---------------- Booking Time Card ----------------
class BookingTimeCard extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  final dynamic price;

  const BookingTimeCard({super.key, required this.start, required this.end, this.price});

  @override
  Widget build(BuildContext context) {
    final bookingPrice = price is Map ? double.tryParse(price['booking_price'].toString()) : null;
    final remainingPrice = price is Map ? price['booking_remaining_price'] : null;

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const Icon(Icons.access_time, color: Colors.redAccent, size: 32),
          const SizedBox(height: 8),
          Text("${AppFormat.formatTime(start)} - ${AppFormat.formatTime(end)}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(AppFormat.formatDateArabic(start),
              style: const TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 20),
          if (bookingPrice != null)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                "سعر الحجز: ${(bookingPrice / 2).toStringAsFixed(2)} دينار",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
            ),
          if (remainingPrice != null)
            Align(
              alignment: Alignment.centerRight,
              child: Text("المتبقي: $remainingPrice دينار",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
            ),
        ]),
      ),
    );
  }
}

// ---------------- Booking Notes Card ----------------
class BookingNotesCard extends StatelessWidget {
  final String notes;
  const BookingNotesCard({super.key, required this.notes});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        elevation: 4,
        child: SizedBox(
          height: 160,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "ملاحظات:",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      notes,
                      style: const TextStyle(fontSize: 16, height: 1.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- Booking Actions Row ----------------
class BookingActionsRow extends StatelessWidget {
  final Future<Map<String, dynamic>> Function() onAccept;
  final Future<Map<String, dynamic>> Function() onReject;

  const BookingActionsRow({super.key, required this.onAccept, required this.onReject});

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("خطأ"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("موافق"),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            ),
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
                final result = await onAccept();
                if (result['success'] == true) {
                  Navigator.pop(context, true);
                  _showSnackBar(context, result['message']);
                } else {
                  _showErrorDialog(context, result['message']);
                }
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            ),
            icon: const Icon(Icons.close, color: Colors.redAccent),
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
                final result = await onReject();
                if (result['success'] == true) {
                  Navigator.pop(context, true);
                  _showSnackBar(context, result['message']);
                } else {
                  _showErrorDialog(context, result['message']);
                }
              }
            },
          ),
        ),
      ],
    );
  }
}
