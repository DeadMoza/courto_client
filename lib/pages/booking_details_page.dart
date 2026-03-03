import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:client_app/constants.dart';
import '../services/auth_service.dart';
import 'dart:ui' as ui;

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

  Future<List<DateTime>> _getMonthlyDates() async {
    if (booking?['booking_is_monthly'] != true) return [];
    return await _fetchMonthlyBookingDates();
  }

  Future<Map<String, dynamic>> _acceptBooking() async {
    try {
      if (booking == null) return {'success': false, 'message': "بيانات الحجز غير متوفرة"};

      final response = await http.patch(
        Uri.parse("${apiUrl}clients/acceptBooking/${booking!['booking_id']}/${booking!['user_id']}"),
        headers: {
          'Authorization': 'Bearer $token',
          'x-api-key': dotenv.env['API_KEY']!,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (data['booking']?['new_wallet_balance'] != null) {
          final newBalance = double.tryParse("${data['booking']['new_wallet_balance']}") ?? 0;
          AuthService.clientData?['wallet_balance'] = newBalance;
        }
        return {'success': true, 'message': "تم قبول الحجز"};
      }

      return {'success': false, 'message': data['error'] ?? "حدث خطأ"};
    } catch (e) {
      return {'success': false, 'message': "فشل الاتصال"};
    }
  }


Future<String?> _rejectDialog(BuildContext context) async {
  final controller = TextEditingController();

  return await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text(" إدخال سبب الرفض"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: "اكتب السبب هنا...",
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text("إلغاء"),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context, controller.text.trim());
          },
          child: const Text("تأكيد"),
        ),
      ],
    ),
  );
}

Future<Map<String, dynamic>> _rejectBooking(String reason) async {
  try {
    if (booking == null) {
      return {'success': false, 'message': "بيانات غير كافية"};
    }

    final response = await http.delete(
      Uri.parse("${apiUrl}clients/rejectBooking/${booking!['booking_id']}/${booking!['user_id']}"),
      headers: {
        'Authorization': 'Bearer $token',
        'x-api-key': dotenv.env['API_KEY']!,
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "reason": reason,
      }),
    );

    final data = jsonDecode(response.body);

    return {
      'success': response.statusCode == 200,
      'message': data['message'] ?? "تم الرفض"
    };
  } catch (e) {
    return {'success': false, 'message': "فشل الاتصال"};
  }
}

  Future<Map<String, dynamic>> _cancelBooking() async {
    try {
      final response = await http.delete(
        Uri.parse("${apiUrl}clients/cancelBooking"),
        headers: {
          'Authorization': 'Bearer $token',
          'x-api-key': dotenv.env['API_KEY']!,
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "booking_id": booking!['booking_id'],
          "client_id": AuthService.clientData?['id'],
        }),
      );
      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? "تم الإلغاء"
      };
    } catch (e) {
      return {'success': false, 'message': "فشل الاتصال"};
    }
  }

  Future<List<DateTime>> _fetchMonthlyBookingDates() async {
    try {
      final res = await http.get(
        Uri.parse("${apiUrl}clients/getMonthlyBookingDetails/${booking!['booking_id']}"),
        headers: {
          "Authorization": "Bearer $token",
          "x-api-key": dotenv.env['API_KEY']!,
        },
      );
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      final list = data['booking_details'] as List<dynamic>;
      return list.map((e) => DateTime.parse(e['multi_booking_date'])).toList();
    } catch (e) {
      return [];
    }
  }

  Color _statusColor(BookingStatus s) {
    switch (s) {
      case BookingStatus.confirmed:
        return Colors.redAccent;
      case BookingStatus.pending:
        return Colors.orange.shade700;
      default:
        return Colors.grey.shade800;
    }
  }

  IconData _statusIcon(BookingStatus s) {
    switch (s) {
      case BookingStatus.confirmed:
        return Icons.check_circle;
      case BookingStatus.pending:
        return Icons.hourglass_bottom;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = parseStatus(booking?['booking_status']);
    final isMonthly = booking?['booking_is_monthly'] == true;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.red.shade50,
        appBar: AppBar(
          title: const Text("تفاصيل الحجز", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: FutureBuilder(
          future: isMonthly ? _getMonthlyDates() : Future.value([]),
          builder: (context, snapshot) {
            final monthlyDates = snapshot.data ?? [];

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              child: Card(
                color: Colors.white,
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // FIELD NAME
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            field['field_name'] ?? "اسم الملعب",
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.red,
                            ),
                          ),
                        // STATUS
                        const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(_statusIcon(status), color: _statusColor(status), size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    AppFormat.translateStatus(status.name),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _statusColor(status),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                "رمز الحجز: ${booking!["booking_id"].toString()}",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),

                            ],
                          ),
                      const SizedBox(height: 10),
                      const Divider(),
                      const SizedBox(height: 10),

                      // USER INFO
                      if (booking != null)
                        Center(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              border: Border.all(color: Colors.redAccent.shade100),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // DATE & TIME
                                _buildIconTextRow(
                                  icon: Icons.calendar_month,
                                  text: AppFormat.formatDateArabic(start),
                                  bold: true,
                                  size: 18,
                                ),
                                const SizedBox(height: 8),
                                _buildIconTextRow(
                                  icon: Icons.access_time_filled,
                                  text: "${AppFormat.formatTime(start)} - ${AppFormat.formatTime(end)}",
                                  bold: true,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),

                    const SizedBox(height: 10),


                    _buildDetailRow(
                      label: "الاسم",
                      value: booking!['booking_user'] ?? "غير معروف",
                      valueColor: Colors.black54
                    ),
                    _buildDetailRow(
                      label: "رقم الهاتف",
                      value: booking!['booking_user_phone_number'] ?? "--",
                      valueColor: Colors.black54,
                      isBold: true,
                      size: 18,
                    ),

                     const SizedBox(height: 10),

                     const Divider(height: 10, thickness: 1),
                     const SizedBox(height: 10),


                    _buildDetailRow(
                      label: "سعر الحجز",
                      value: "${booking!['booking_price']} د.ل ",
                      valueColor: Colors.black54
                    ),
                    _buildDetailRow(
                      label: "السعر المتبقي",
                      value: "${booking!['booking_remaining_price']} د.ل ",
                      valueColor: Colors.redAccent,
                      isBold: true,
                      size: 18,
                    ),



                      // MONTHLY DATES
                      if (monthlyDates.isNotEmpty) ...[
                    const Divider(height: 30, thickness: 1),
                        const Text(
                          "مواعيد الحجز الشهرية",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
                        ),
                        ...monthlyDates.map((d) => _buildIconTextRow(
                              icon: Icons.event_repeat,
                              text: AppFormat.formatDateArabic(d),
                              size: 14,
                              color: Colors.black87,
                              padding: const EdgeInsets.only(bottom: 4),
                            )),
                      ],


                      // NOTES
                      if (booking?['booking_notes'] != null &&
                          booking!['booking_notes'].toString().trim().isNotEmpty) ...[
                        const Divider(height: 20, thickness: 1),
                        const SizedBox(height: 10),
                        Text(
                          "الملاحظات",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.redAccent.shade100),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            booking!['booking_notes'],
                            style: TextStyle(color: Colors.black87, fontSize: 15),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        // BOTTOM ACTIONS
        bottomNavigationBar: Builder(
          builder: (context) {
            final now = DateTime.now();
            final canCancelBeforeMatch = now.isBefore(start);

            if (status == BookingStatus.confirmed && canCancelBeforeMatch) {
              return _bottomButton(
                label: "إلغاء الحجز",
                color: Colors.redAccent,
                icon: Icons.cancel,
                handler: () async {
                  final confirm = await _confirmDialog(context, "هل تريد إلغاء هذا الحجز؟");
                  if (confirm) {
                    final res = await _cancelBooking();
                    _snack(context, res['message']);
                    Navigator.pop(context, true);
                  }
                },
              );
            }

            if (status == BookingStatus.pending) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _coloredButton(
                        label: "قبول",
                        color: Colors.redAccent,
                        icon: Icons.check,
                        handler: () async {
                          final confirm = await _confirmDialog(context, "قبول الحجز؟");
                          if (confirm) {
                            final res = await _acceptBooking();
                            _snack(context, res['message']);
                            Navigator.pop(context, true);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _coloredButton(
                        label: "رفض",
                        color: Colors.grey.shade800,
                        icon: Icons.close,
                        handler: () async {
                          final reason = await _rejectDialog(context);

                          if (reason != null) {
                            final res = await _rejectBooking(reason);
                            _snack(context, res['message']);
                            Navigator.pop(context, true);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---
  Widget _buildIconTextRow({
    required IconData icon,
    required String text,
    Color iconColor = Colors.redAccent,
    Color color = Colors.black87,
    bool bold = false,
    double size = 16,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                fontSize: size,
              ),
            ),
          ),
        ],
      ),
    );
  }

    Widget _buildDetailRow({
    required String label,
    required String value,
    Color valueColor = Colors.black,
    bool isBold = false,
    double size = 16,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "$label:",
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: size,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: valueColor,
            ),
            textDirection: ui.TextDirection.ltr, // Ensure numbers display correctly
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDialog(BuildContext context, String msg) async {
    return await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(msg),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("لا")),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("نعم")),
            ],
          ),
        ) ??
        false;
  }

  Widget _bottomButton({
    required String label,
    required IconData icon,
    required Color color,
    required Function handler,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(icon, color: Colors.white),
        label: Text(label, style: const TextStyle(color: Colors.white)),
        onPressed: () => handler(),
      ),
    );
  }

  Widget _coloredButton({
    required String label,
    required IconData icon,
    required Color color,
    required Function handler,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      onPressed: () => handler(),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}
