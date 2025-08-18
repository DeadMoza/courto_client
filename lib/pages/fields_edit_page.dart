import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class FieldsEditPage extends StatefulWidget {
  final Map<String, dynamic> field;
  final String? token;
  const FieldsEditPage({super.key, required this.field, this.token});

  @override
  _FieldsEditPageState createState() => _FieldsEditPageState();
}

class _FieldsEditPageState extends State<FieldsEditPage> {
  late TextEditingController priceController;
  late TextEditingController contactController;
  late TextEditingController descriptionController;
  bool isAvailable = true;
  bool loading = false;
  String? errorMessage;

  TimeOfDay? openTime;
  TimeOfDay? closeTime;

  @override
  void initState() {
    super.initState();
    priceController =
        TextEditingController(text: widget.field["field_price"]?.toString() ?? "");
    contactController =
        TextEditingController(text: widget.field["field_contact_number"] ?? "");
    descriptionController =
        TextEditingController(text: widget.field["field_description"] ?? "");
    isAvailable = widget.field["field_is_available"] ?? true;

    // Parse times to TimeOfDay
    openTime = _parseTime(widget.field["field_open_time"]);
    closeTime = _parseTime(widget.field["field_close_time"]);
  }

  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    final parts = timeStr.split(":");
    if (parts.length < 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Future<void> _pickTime({required bool isOpen}) async {
    final initial = isOpen ? openTime ?? TimeOfDay.now() : closeTime ?? TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        if (isOpen) openTime = picked;
        else closeTime = picked;
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat.jm().format(dt); // hh:mm AM/PM
  }

  String _formatTimeForBackend(TimeOfDay? time) {
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2,'0')}:${time.minute.toString().padLeft(2,'0')}';
  }

  Future<void> saveField() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    final url =
        Uri.parse("http://192.168.3.180:3000/api/clients/updateField/${widget.field["field_id"]}");

    try {
      final res = await http.put(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.token}",
        },
        body: json.encode({
          "field_price": double.tryParse(priceController.text) ?? 0,
          "field_open_time": _formatTimeForBackend(openTime),
          "field_close_time": _formatTimeForBackend(closeTime),
          "field_contact": contactController.text,
          "field_description": descriptionController.text,
          "field_is_available": isAvailable,
        }),
      );

      setState(() => loading = false);

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Field updated successfully")));
        Navigator.pop(context, true);
      } else {
        final data = json.decode(res.body);
        setState(() {
          errorMessage = data["error"] ?? "Failed to update field";
        });
      }
    } catch (e) {
      setState(() {
        loading = false;
        errorMessage = "Network error: $e";
      });
    }
  }

  @override
  void dispose() {
    priceController.dispose();
    contactController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Edit ${widget.field["field_name"]}"),
        backgroundColor: Colors.red,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CheckboxListTile(
                    title: const Text("Is available?"),
                    value: isAvailable,
                    onChanged: (val) => setState(() => isAvailable = val ?? true),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Price",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  ListTile(
                    title: const Text("Open Time"),
                    subtitle: Text(_formatTimeOfDay(openTime)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () => _pickTime(isOpen: true),
                  ),
                  const SizedBox(height: 12),

                  ListTile(
                    title: const Text("Close Time"),
                    subtitle: Text(_formatTimeOfDay(closeTime)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () => _pickTime(isOpen: false),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: contactController,
                    decoration: const InputDecoration(
                      labelText: "Field Contact Number",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Description",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (errorMessage != null)
                    Text(errorMessage!,
                        style: const TextStyle(color: Colors.red)),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: saveField,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text(
                        "Save Changes",
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
