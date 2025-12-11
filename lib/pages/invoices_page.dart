import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui' as ui;
import '../services/auth_service.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  bool loading = true;
  Map<int, List<dynamic>> invoicesByMonth = {}; // monthIndex -> list of invoices
  String? apiUrl;

  @override
  void initState() {
    super.initState();
    apiUrl = dotenv.env['API_URL'];
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => loading = true);
    try {
      final token = AuthService.token;
      final url = Uri.parse("${apiUrl}clients/getPaidInvoices/${AuthService.clientData!["id"]}");
      final res = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
          'x-api-key': '${dotenv.env['API_KEY']}',
        },
      );

      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body)["invoices"];

        // Group by month
        Map<int, List<dynamic>> grouped = {};
        for (var inv in data) {
          int month = inv['invoice_month'];
          if (!grouped.containsKey(month)) grouped[month] = [];
          grouped[month]!.add(inv);
        }

        setState(() {
          invoicesByMonth = grouped;
          loading = false;
        });
      } else {
        final errorData = json.decode(res.body);
        _showError(errorData["error"] ?? "خطأ في جلب الفواتير");
      }
    } catch (e) {
      _showError("فشل الاتصال: $e");
    } finally {
      setState(() => loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  String monthName(int monthIndex) {
    const months = [
      "", "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
      "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"
    ];
    return months[monthIndex];
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
          foregroundColor: Colors.white,
          title: const Text("الفواتير"),
          backgroundColor: Colors.redAccent,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        backgroundColor: Colors.red[50],
        body: loading
            ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
            : invoicesByMonth.isEmpty
                ? const Center(child: Text("لا توجد فواتير متاحة"))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: invoicesByMonth.entries.map((entry) {
                      int monthIndex = entry.key;
                      List<dynamic> monthInvoices = entry.value;
                      int year = monthInvoices[0]['invoice_year'];
                      bool isPaid = monthInvoices.every((inv) => inv['paid'] == true);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: Colors.white,
                        child: ExpansionTile(
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("${monthName(monthIndex)} $year",
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              if (isPaid)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    "مدفوع",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                )
                            ],
                          ),
                          children: monthInvoices.map((inv) {
                            return ListTile(
                              title: Text("رقم الفاتورة: ${inv['invoice_id']}"),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("المجموع: ${inv['invoice_total']} د.ل"),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }).toList(),
                  ),
      ),
    );
  }
}
