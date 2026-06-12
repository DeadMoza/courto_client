import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  bool loading = true;

  // Key format: 2026-6
  Map<String, List<dynamic>> bookingsByMonth = {};

  String? apiUrl;

  @override
  void initState() {
    super.initState();
    apiUrl = dotenv.env['API_URL'];
    _loadInvoices();
  }


  String formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return "";
    try {
      // Splits "12:00:00" into ["12", "00", "00"] and keeps the first two parts
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        return "${parts[0]}:${parts[1]}";
      }
      return timeStr;
    } catch (_) {
      return timeStr;
    }
  }

  Future<void> _loadInvoices() async {
    setState(() => loading = true);

    try {
      final token = AuthService.token;

      final url = Uri.parse(
        "${apiUrl}clients/getPaidInvoices/${AuthService.clientData!["id"]}",
      );

      final res = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
          "x-api-key": "${dotenv.env['API_KEY']}",
        },
      );

      if (res.statusCode == 200) {
        final List<dynamic> data =
            json.decode(res.body)["invoices"] ?? [];

        Map<String, List<dynamic>> grouped = {};

        for (var booking in data) {
          final date =
              DateTime.parse(booking["booking_date"]);

          final key = "${date.year}-${date.month}";

          grouped.putIfAbsent(key, () => []);
          grouped[key]!.add(booking);
        }

        // Sort newest first
        final sortedEntries = grouped.entries.toList()
          ..sort((a, b) {
            final aParts = a.key.split("-");
            final bParts = b.key.split("-");

            final aDate = DateTime(
              int.parse(aParts[0]),
              int.parse(aParts[1]),
            );

            final bDate = DateTime(
              int.parse(bParts[0]),
              int.parse(bParts[1]),
            );

            return bDate.compareTo(aDate);
          });

        setState(() {
          bookingsByMonth = {
            for (var e in sortedEntries) e.key: e.value
          };
        });
      } else {
        final error =
            json.decode(res.body)["error"] ??
                "خطأ في جلب البيانات";

        _showError(error);
      }
    } catch (e) {
      _showError("فشل الاتصال: $e");
    } finally {
      setState(() => loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  String monthName(int month) {
    const months = [
      "",
      "يناير",
      "فبراير",
      "مارس",
      "أبريل",
      "مايو",
      "يونيو",
      "يوليو",
      "أغسطس",
      "سبتمبر",
      "أكتوبر",
      "نوفمبر",
      "ديسمبر",
    ];

    return months[month];
  }

  String formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);

      return "${dt.day}/${dt.month}/${dt.year}";
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("الفواتير"),
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white,
        ),
        backgroundColor: Colors.red[50],
        body: loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.redAccent,
                ),
              )
            : bookingsByMonth.isEmpty
                ? const Center(
                    child: Text(
                      "لا توجد حجوزات مدفوعة",
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: bookingsByMonth.length,
                    itemBuilder: (context, index) {
                      final key =
                          bookingsByMonth.keys.elementAt(index);

                      final bookings =
                          bookingsByMonth[key]!;

                      final parts = key.split("-");

                      final year =
                          int.parse(parts[0]);

                      final month =
                          int.parse(parts[1]);

                      double total = 0;

                      for (var booking in bookings) {
                        total += double.tryParse(
                              booking["final_booking_price"]
                                  .toString(),
                            ) ??
                            0;
                      }

                      return Card(
                        margin:
                            const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          tilePadding:
                              const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          title: Text(
                            "$year - ${monthName(month)}",
                            style: const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            "عدد الحجوزات: ${bookings.length}",
                          ),
                          children: [
                            ...bookings.map(
                              (booking) {
                                return ListTile(
                                  title: Text(
                                    booking["field_name"] ??
                                        "",
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      Text(
                                        "التاريخ: ${formatDate(booking["booking_date"])}",
                                      ),
                                      Text(
                                        "الوقت: ${formatTime(booking["start_time"])} - ${formatTime(booking["end_time"])}",
                                      ), 
                                      Text(
                                        booking["is_monthly"] ==
                                                true
                                            ? "حجز شهري"
                                            : "حجز يومي",
                                      ),
                                    ],
                                  ),
                                  trailing: Text(
                                    "${booking["final_booking_price"]} د.ل",
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                      color:
                                          Colors.redAccent,
                                      fontSize: 15,
                                    ),
                                  ),
                                );
                              },
                            ),

                            const Divider(),

                            Padding(
                              padding:
                                  const EdgeInsets.all(
                                16,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .spaceBetween,
                                children: [
                                  const Text(
                                    "الإجمالي",
                                    style: TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                      fontSize: 17,
                                    ),
                                  ),
                                  Text(
                                    "${total.toStringAsFixed(2)} د.ل",
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                      fontSize: 18,
                                      color:
                                          Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
