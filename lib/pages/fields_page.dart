import 'package:client_app/constants.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_page.dart';
import 'fields_calendar_page.dart';
import 'fields_edit_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class FieldsPage extends StatefulWidget {
  const FieldsPage({super.key});

  @override
  _FieldsPageState createState() => _FieldsPageState();
}

class _FieldsPageState extends State<FieldsPage> {
  List fields = [];
  bool loading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    if (AuthService.isLoggedIn) fetchFields();
  }

  Future<void> fetchFields() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    final url = Uri.parse("${apiUrl}api/clients/getFields");
    try {
      final res = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${AuthService.token}",
        },
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          fields = data["fields"];
          loading = false;
        });
      } else {
        final data = json.decode(res.body);
        setState(() {
          errorMessage = data["error"] ?? "Failed to fetch fields";
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Failed to load, check your connection";
        loading = false;
      });
    }
  }

  String getFirstImageUrl(List<dynamic> images) {
    if (images.isEmpty) return '';
    String url = images[0].toString();
    if (url.startsWith('/')) url = 'http://192.168.1.103:3000$url';
    return url;
  }

  String formatTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length < 2) return timeStr;

      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      final dt = DateTime(0, 1, 1, hour, minute);
      return DateFormat.jm().format(dt); // e.g., 3:30 PM
    } catch (_) {
      return timeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.red,
        title: Row(
          children: [
            Expanded(
              child: Text(
                "Hello, ${AuthService.clientData?['full_name'] ?? ''}",
                style: const TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12), // less rounded
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet,
                      color: Colors.red, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    AuthService.clientData?['wallet_balance']?.toString() ?? '0',
                    style: const TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: AuthService.isLoggedIn
          ? loading
              ? const Center(child: CircularProgressIndicator(color: Colors.red))
              : errorMessage != null
                  ? Center(
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: fields.length,
                      itemBuilder: (context, index) {
                        final field = fields[index];
                        final imageUrl = getFirstImageUrl(field["images"]);

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FieldsCalendarPage(
                                  field: field,
                                  token: AuthService.token,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12), // tighter corners
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.1),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                )
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (imageUrl.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(12)),
                                    child: Image.network(
                                      imageUrl,
                                      width: double.infinity,
                                      height: 160,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              field["field_name"],
                                              style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                const Icon(Icons.attach_money_rounded,
                                                    color: Colors.red,
                                                    size: 18),
                                                const SizedBox(width: 4),
                                                Text(
                                                  "${field["field_price"] ?? '0'} / hr",
                                                  style: const TextStyle(
                                                      fontSize: 15,
                                                      color: Colors.black54),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                const Icon(Icons.place,
                                                    color: Colors.redAccent,
                                                    size: 18),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    "${field["field_location"]}",
                                                    style: const TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.black54),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.red[50],
                                              borderRadius:
                                                  BorderRadius.circular(8), // tighter badge
                                            ),
                                            child: Text(
                                              "${formatTime(field["field_open_time"] ?? '')} - ${formatTime(field["field_close_time"] ?? '')}",
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.red),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          IconButton(
                                            onPressed: () async {
                                              final updated =
                                                  await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      FieldsEditPage(
                                                    field: field,
                                                    token: AuthService.token,
                                                  ),
                                                ),
                                              );
                                              if (updated == true) {
                                                fetchFields();
                                              }
                                            },
                                            icon: const Icon(Icons.settings,
                                                color: Colors.red, size: 24),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
          : Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  ).then((_) {
                    if (AuthService.isLoggedIn) fetchFields();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)), // tighter btn
                ),
                child: const Text(
                  "Login to view your fields",
                  style: TextStyle(fontSize: 15, color: Colors.white),
                ),
              ),
            ),
    );
  }
}
