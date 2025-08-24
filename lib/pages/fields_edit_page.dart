import 'package:client_app/constants.dart';
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
    });

    final url =
        Uri.parse("${apiUrl}api/clients/updateField/${widget.field["field_id"]}");

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
            const SnackBar(content: Text("Field updated successfully"), backgroundColor: Colors.red));
        Navigator.pop(context, true);
      } else {
        final data = json.decode(res.body);
        _showError(data["error"] ?? "Failed to update field");
      }
    } catch (e) {
      setState(() {
        loading = false;
      });
      _showError("Network error: $e");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: Colors.red) : null,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    );
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
      backgroundColor: Colors.red[50],
      appBar: AppBar(
        title: Text("Edit ${widget.field["field_name"]}", style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.red,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Availability
                  CheckboxListTile(
                    title: const Text("Is available?"),
                    value: isAvailable,
                    activeColor: Colors.red,
                    onChanged: (val) => setState(() => isAvailable = val ?? true),
                  ),
                  const SizedBox(height: 16),

                  // Price
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration("Price", icon: Icons.attach_money_rounded),
                  ),
                  const SizedBox(height: 16),

                  // Open/Close Times in a row
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _pickTime(isOpen: true),
                          child: AbsorbPointer(
                            child: TextField(
                              decoration: _inputDecoration("Open Time", icon: Icons.access_time),
                              controller: TextEditingController(text: _formatTimeOfDay(openTime)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _pickTime(isOpen: false),
                          child: AbsorbPointer(
                            child: TextField(
                              decoration: _inputDecoration("Close Time", icon: Icons.lock_clock_rounded),
                              controller: TextEditingController(text: _formatTimeOfDay(closeTime)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Contact
                  TextField(
                    controller: contactController,
                    keyboardType: TextInputType.phone,
                    decoration: _inputDecoration("Field Contact Number", icon: Icons.phone),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: _inputDecoration("Description", icon: Icons.description),
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: saveField,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        "Save Changes",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
