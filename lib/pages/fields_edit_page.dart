import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui' as ui;

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
  bool autoAccept = false;
  bool loading = false;

  TimeOfDay? openTime;
  TimeOfDay? closeTime;

  // Minutes per bookable slot: 15, 30 or 60. The open/close window is cut into
  // pieces of this size everywhere slots are drawn.
  int slotDuration = 60;

  // How many bookings may share one slot. 1 means the first booking closes the
  // slot; a karting track with 6 carts sells the same slot 6 times.
  int slotSeats = 1;
  late TextEditingController slotSeatsController;

  final apiUrl = dotenv.env['API_URL'];

  @override
  void initState() {
    super.initState();
    priceController = TextEditingController(text: widget.field["field_price"]?.toString() ?? "");
    contactController = TextEditingController(text: widget.field["field_contact_number"] ?? "");
    descriptionController = TextEditingController(text: widget.field["field_description"] ?? "");
    isAvailable = widget.field["field_is_available"] ?? true;
    autoAccept = widget.field["field_auto_accept"] ?? false; 

    openTime = _parseTime(widget.field["field_open_time"]);
    closeTime = _parseTime(widget.field["field_close_time"]);

    final rawDuration =
        int.tryParse(widget.field["field_slot_duration"]?.toString() ?? "");
    if (rawDuration == 15 || rawDuration == 30 || rawDuration == 60) {
      slotDuration = rawDuration!;
    }

    final rawSeats =
        int.tryParse(widget.field["field_slot_seats"]?.toString() ?? "");
    if (rawSeats != null && rawSeats >= 1) slotSeats = rawSeats;
    slotSeatsController = TextEditingController(text: slotSeats.toString());
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
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context),
          child: child!,
        );
      },
    );

    if (picked != null) {
      // Force integer hours only
      final hourOnly = TimeOfDay(hour: picked.hour, minute: 0);
      setState(() {
        if (isOpen) {
          openTime = hourOnly;
        } else {
          closeTime = hourOnly;
        }
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2, '0')}:00';
  }

  String _formatTimeForBackend(TimeOfDay? time) {
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2, '0')}:00';
  }

  bool _isValidTimeDifference() {
    if (openTime == null || closeTime == null) return true;

    final now = DateTime.now();
    final openDt = DateTime(now.year, now.month, now.day, openTime!.hour, openTime!.minute);
    var closeDt = DateTime(now.year, now.month, now.day, closeTime!.hour, closeTime!.minute);

    // Handle cases where closing time is after midnight
    if (closeDt.isBefore(openDt)) {
      closeDt = closeDt.add(const Duration(days: 1));
    }

    final difference = closeDt.difference(openDt).inHours;

    return difference >= 4 && difference <= 23;
  }

  Future<void> saveField() async {
    final price = double.tryParse(priceController.text) ?? 0;

    // Validate price
    if (price < 20 || price > 100) {
      _showError("السعر يجب أن يكون بين 20 و 100 دينار");
      return;
    }

    // Validate time difference
    if (!_isValidTimeDifference()) {
      _showError("يجب أن يكون الفرق بين وقت الفتح والإغلاق من 4 إلى 23 ساعة");
      return;
    }

    setState(() {
      loading = true;
    });

    String phone = contactController.text.trim();

    if (phone.startsWith("09")) {
      phone = "218${phone.substring(1)}";
    } else if (phone.startsWith("9")) {
      phone = "218$phone";
    } else if (phone.startsWith("0")) {
      phone = "218${phone.substring(1)}";
    } else if (!phone.startsWith("218")) {
      phone = "218$phone";
    }

    final url = Uri.parse("${apiUrl}clients/updateField/${widget.field["field_id"]}");

    try {
      final res = await http.put(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.token}",
          'x-api-key': '${dotenv.env['API_KEY']}'
        },
        body: json.encode({
          "field_price": price,
          "field_open_time": _formatTimeForBackend(openTime),
          "field_close_time": _formatTimeForBackend(closeTime),
          "field_contact": phone,
          "field_description": descriptionController.text,
          "field_is_available": isAvailable,
          "field_auto_accept": autoAccept,
          "field_slot_duration": slotDuration,
          "field_slot_seats": slotSeats,
        }),
      );

      setState(() => loading = false);

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم تحديث بيانات الملعب بنجاح"),
            backgroundColor: Colors.redAccent,
          ),
        );
        Navigator.pop(context, true);
      } else {
        final data = json.decode(res.body);
        _showError(data["error"] ?? "فشل تحديث بيانات الملعب");
      }
    } catch (e) {
      setState(() {
        loading = false;
      });
      _showError("خطأ في الاتصال: $e");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: Colors.redAccent) : null,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
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
    slotSeatsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.red[50],
        appBar: AppBar(
          title: Text(
            "تعديل ${widget.field["field_name"]}",
            style: const TextStyle(color: Colors.white),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          backgroundColor: Colors.redAccent,
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    CheckboxListTile(
                      title: const Text(
                        "متاح للحجز؟",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                      subtitle: const Text(
                        "في حال عدم التفعيل سوف يختفي الملعب من واجهة المستخدمين, ولا يمكن لأحد حجز الملعب عبر التطبيق.",
                        style: TextStyle(color: Colors.black54),
                      ),
                      value: isAvailable,
                      activeColor: Colors.redAccent,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (val) =>
                          setState(() => isAvailable = val ?? true),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      title: const Text(
                        "الموافقة علي الحجوزات تلقائيا؟",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                      subtitle: const Text(
                        "في حال التفعيل سيتم تأكيد الحجوزات فوراً دون مراجعة.",
                        style: TextStyle(color: Colors.black54),
                      ),
                      value: autoAccept,
                      activeColor: Colors.redAccent,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (val) => setState(() => autoAccept = val ?? false),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                        "السعر",
                        icon: Icons.attach_money_rounded,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _pickTime(isOpen: true),
                            child: AbsorbPointer(
                              child: TextField(
                                decoration: _inputDecoration(
                                  "وقت الفتح",
                                  icon: Icons.access_time,
                                ),
                                controller: TextEditingController(
                                  text: _formatTimeOfDay(openTime),
                                ),
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
                                decoration: _inputDecoration(
                                  "وقت الإغلاق",
                                  icon: Icons.lock_clock_rounded,
                                ),
                                controller: TextEditingController(
                                  text: _formatTimeOfDay(closeTime),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: slotDuration,
                      decoration: _inputDecoration(
                        "مدة الفترة",
                        icon: Icons.timelapse,
                      ),
                      items: const [
                        DropdownMenuItem(value: 60, child: Text("60 دقيقة")),
                        DropdownMenuItem(value: 30, child: Text("30 دقيقة")),
                        DropdownMenuItem(value: 15, child: Text("15 دقيقة")),
                      ],
                      onChanged: (val) =>
                          setState(() => slotDuration = val ?? slotDuration),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: slotSeatsController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                        "عدد الحجوزات في نفس الفترة",
                        icon: Icons.event_seat,
                      ),
                      onChanged: (val) {
                        final parsed = int.tryParse(val.trim());
                        if (parsed != null && parsed >= 1 && parsed <= 100) {
                          slotSeats = parsed;
                        }
                      },
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 6, right: 4, left: 4),
                      child: Text(
                        "1 يعني أن أول حجز يغلق الفترة. أي رقم أكبر يسمح لهذا العدد من المستخدمين بحجز نفس الفترة (مثال: 6 كارتات).",
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: contactController,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecoration(
                        "رقم التواصل",
                        icon: Icons.phone,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: _inputDecoration(
                        "الوصف",
                        icon: Icons.description,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: saveField,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        child: const Text(
                          "حفظ التغييرات",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
