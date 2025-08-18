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

    final url = Uri.parse("http://192.168.3.180:3000/api/clients/getFields");
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
        errorMessage = "Network error: $e";
        loading = false;
      });
    }
  }

  String getFirstImageUrl(List<dynamic> images) {
    if (images.isEmpty) return '';
    String url = images[0].toString();
    if (url.startsWith('/')) url = 'http://192.168.3.180:3000$url';
    return url;
  }

  // Convert HH:MM to hh:mm AM/PM
  String formatTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length < 2) return timeStr;

      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      final dt = DateTime(0, 1, 1, hour, minute); // dummy date
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
        backgroundColor: Colors.red,
        title: Row(
          children: [
            Expanded(
              child: Text(
                "Hello, ${AuthService.clientData?['full_name'] ?? ''}",
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet,
                      color: Colors.red, size: 20),
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
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.red))
              : errorMessage != null
                  ? Center(
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                  : ListView.builder(
                      itemCount: fields.length,
                      itemBuilder: (context, index) {
                        final field = fields[index];
                        final imageUrl = getFirstImageUrl(field["images"]);

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              // Navigate to Calendar Page
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (imageUrl.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(16)),
                                    child: Image.network(
                                      imageUrl,
                                      width: double.infinity,
                                      height: 180,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                                "Price: \$${field["field_price"] ?? '0'}"),
                                            const SizedBox(height: 4),
                                            Text(
                                                "Location: ${field["field_location"]}"),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            "[ ${formatTime(field["field_open_time"] ?? '')} - ${formatTime(field["field_close_time"] ?? '')} ]",
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                          const SizedBox(height: 6),
                                          IconButton(
                                            onPressed: () async {
                                              final updated = await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                    FieldsEditPage(
                                                      field: field,
                                                      token: AuthService.token,
                                                  ),
                                                ),
                                              );
                                              if(updated == true) fetchFields();
                                            },
                                            icon: const Icon(Icons.settings,
                                                color: Colors.red, size: 28),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text(
                  "Login to view your fields",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
    );
  }
}
