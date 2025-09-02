import 'package:flutter/material.dart';
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

    return Directionality(
      textDirection: TextDirection.rtl, // ← اجعل الصفحة من اليمين لليسار
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "تفاصيل الحجز",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        backgroundColor: Colors.red.shade50,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // البطاقة الأولى: معلومات الملعب والمستخدم والحالة
                Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // اسم الملعب
                        Text(
                          field['field_name'] ?? "ملعب غير معروف",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // معلومات المستخدم
                        if (booking != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.person, color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  booking!['booking_user'] ?? "مستخدم غير معروف",
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
                                booking!['booking_user_phone_number'] ??
                                    "بدون رقم هاتف",
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],

                        // الحالة وID الحجز
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(_statusIcon(status), color: _statusColor(status)),
                                const SizedBox(width: 8),
                                Text(
                                  AppFormat.translateStatus(status),
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
                                "رمز الحجز: ${booking!['booking_id']}",
                                style: const TextStyle(fontSize: 16),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // البطاقة الثانية: الوقت، التاريخ، السعر
                Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.access_time, color: Colors.red, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          "${AppFormat.formatTime(start)} - ${AppFormat.formatTime(end)}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppFormat.formatDateArabic(start),
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            "السعر: ${booking?['booking_total_price'] ?? "--"} دينار",
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

                // البطاقة الثالثة: الملاحظات
                if (booking?['booking_notes'] != null &&
                    booking!['booking_notes'].toString().trim().isNotEmpty)
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.note, color: Colors.red, size: 28),
                          const SizedBox(height: 10),
                          const Text(
                            "ملاحظات",
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

                // أزرار الإجراء
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
                          label: const Text(
                            "قبول",
                            style: TextStyle(color: Colors.white),
                          ),
                          onPressed: () async {
                            bool? confirm = await showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text("هل تريد قبول هذا الحجز؟"),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text("لا"),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text("نعم"),
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
                          label: const Text("رفض"),
                          onPressed: () async {
                            bool? confirm = await showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text("هل تريد رفض هذا الحجز؟"),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text("لا"),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text("نعم"),
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
      ),
    );
  }

}
