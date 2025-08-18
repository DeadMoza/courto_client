import 'package:flutter/material.dart';

class FieldsCalendarPage extends StatelessWidget {
  final Map<String, dynamic> field;
  final String? token;
  const FieldsCalendarPage({super.key, required this.field, this.token});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Calendar - ${field['field_name']}"),
        backgroundColor: Colors.red,
      ),
      body: Center(
        child: Text(
          "This is a placeholder for the calendar page of ${field['field_name']}.",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, color: Colors.black54),
        ),
      ),
    );
  }
}
