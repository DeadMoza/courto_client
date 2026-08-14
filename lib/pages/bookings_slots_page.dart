import 'package:client_app/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'booking_details_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BookingSlotsPage extends StatefulWidget {
  final Map<String, dynamic> field;
  final DateTime date;
  final String? token;
  final List<dynamic> bookings;

  const BookingSlotsPage({
    super.key,
    required this.field,
    required this.date,
    this.token,
    required this.bookings,
  });

  @override
  State<BookingSlotsPage> createState() => _BookingSlotsPageState();
}

class _BookingSlotsPageState extends State<BookingSlotsPage> {
  // Initialize to empty so _trackBookings never hits uninitialized fields
  List<TimeSlot> slots = [];
  List<Color?> backgrounds = [];
  List<String?> bookedByList = [];
  List<dynamic> currentBookings = [];
  List<dynamic> currentDiscounts = [];

  // Standing rules an admin set on this field: the time range is off the
  // calendar on every day. Read-only here - only an admin can change them,
  // but the owner still needs to know why a slot is unsellable.
  List<dynamic> hiddenSlots = [];

  bool _needsRefresh = false;
  bool _isLoading = false;
  final apiUrl = dotenv.env['API_URL'];
  List<TimeSlot> _conflictingSlots = [];
  String? guestName;
  String? guestPhoneNumber;

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    setState(() => _isLoading = true);
    await _loadDiscounts();
    await _loadHiddenSlots();
    currentBookings = List.from(widget.bookings);
    _trackBookings();
    setState(() => _isLoading = false);
  }

  Future<void> _loadHiddenSlots() async {
    try {
      final res = await http.get(
        Uri.parse("${apiUrl}clients/getHiddenSlots/${widget.field['field_id']}"),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'x-api-key': '${dotenv.env['API_KEY']}'
        },
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        hiddenSlots = data['hidden_slots'] ?? [];
      }
    } catch (_) {
      hiddenSlots = [];
    }
  }

  // The pieces a daily-repeating window occupies inside one day. A window
  // whose end is at or before its start ran past midnight, so it comes back
  // as two pieces; end == start means the whole day.
  List<List<int>> _dailyPieces(int startMin, int endMin) {
    final a = startMin % (24 * 60);
    final b = endMin % (24 * 60);
    if (b > a) return [[a, b]];
    if (b == a) return [[0, 24 * 60]];
    return [[a, 24 * 60], [0, b]];
  }

  /// The standing rule covering [slot], if any. Half-open, so a slot ending
  /// exactly when a rule starts is untouched.
  Map<String, dynamic>? _hiddenRuleForSlot(TimeSlot slot) {
    final slotStart = slot.start.hour * 60 + slot.start.minute;
    var slotEnd = slot.end.hour * 60 + slot.end.minute;
    if (slotEnd <= slotStart) slotEnd += 24 * 60;
    final slotPieces = _dailyPieces(slotStart, slotEnd);

    for (final h in hiddenSlots) {
      final hs = _parseMinutes(h['start_time']);
      final he = _parseMinutes(h['end_time']);
      if (hs == null || he == null) continue;

      final rulePieces = _dailyPieces(hs, he);
      final overlaps = slotPieces.any(
        (sp) => rulePieces.any((rp) => sp[0] < rp[1] && rp[0] < sp[1]),
      );
      if (overlaps) return h as Map<String, dynamic>;
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant BookingSlotsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bookings != oldWidget.bookings) {
      currentBookings = List.from(widget.bookings);
      _trackBookings();
    }
  }

  // "HH:mm[:ss]" -> minutes since midnight. Null when unparseable.
  int? _parseMinutes(dynamic raw) {
    if (raw == null) return null;
    final parts = raw.toString().split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  // The field's slot size in minutes: 15, 30 or 60. Anything else (missing
  // column, older API) falls back to the 1-hour grid this page used to assume.
  int get _slotDuration {
    final raw = int.tryParse(
      widget.field['field_slot_duration']?.toString() ?? '',
    );
    return (raw == 15 || raw == 30 || raw == 60) ? raw! : 60;
  }

  // How many bookings this field runs at once in one slot. 1 is the old
  // behaviour, where the first booking closed the slot for everyone.
  int get _slotSeats {
    final raw = int.tryParse(
      widget.field['field_slot_seats']?.toString() ?? '',
    );
    return (raw != null && raw >= 1) ? raw : 1;
  }

  bool get _isMultiSeat => _slotSeats > 1;

  // Bookings that actually hold a seat: a cancelled row holds nothing.
  List<Map<String, dynamic>> _liveBookingsForSlot(TimeSlot slot) =>
      _findAllConflictingBookings(slot)
          .where((b) => b['booking_status'] != 'cancelled')
          .toList();

  // Seats gone. A closed slot can hold several seats in one row, so seats are
  // summed rather than counted.
  int _occupiedSeats(TimeSlot slot) {
    var taken = 0;
    for (final b in _liveBookingsForSlot(slot)) {
      taken += int.tryParse(b['booking_seats']?.toString() ?? '') ?? 1;
    }
    return taken;
  }

  int _seatsLeft(TimeSlot slot) {
    final left = _slotSeats - _occupiedSeats(slot);
    return left < 0 ? 0 : left;
  }

  // Wall-clock time on the shown day; minutes past 24h roll into the next day,
  // which is what an after-midnight slot needs.
  DateTime _slotTime(int minutesFromMidnight) => DateTime(
        widget.date.year,
        widget.date.month,
        widget.date.day,
        0,
        minutesFromMidnight,
      );

  void _generateSlots() {
    final openMinutes = _parseMinutes(widget.field['field_open_time']) ?? 8 * 60;
    int closeMinutes =
        _parseMinutes(widget.field['field_close_time']) ?? 20 * 60;
    if (closeMinutes <= openMinutes) closeMinutes += 24 * 60;

    final step = _slotDuration;

    slots = [];
    for (int m = openMinutes; m + step <= closeMinutes; m += step) {
      slots.add(TimeSlot(start: _slotTime(m), end: _slotTime(m + step)));
    }
  }

  Future<void> _loadDiscounts() async {
    final dateString = widget.date.toIso8601String().split('T')[0];
    final nextDay = widget.date.add(const Duration(days: 1));
    final nextDayString = nextDay.toIso8601String().split('T')[0];

    try {
      final results = await Future.wait([
        http.get(
          Uri.parse(
              "${apiUrl}clients/getFieldDiscountedSlots/${widget.field['field_id']}/$dateString"),
          headers: {
            'Authorization': 'Bearer ${widget.token}',
            'x-api-key': '${dotenv.env['API_KEY']}'
          },
        ),
        http.get(
          Uri.parse(
              "${apiUrl}clients/getFieldDiscountedSlots/${widget.field['field_id']}/$nextDayString"),
          headers: {
            'Authorization': 'Bearer ${widget.token}',
            'x-api-key': '${dotenv.env['API_KEY']}'
          },
        ),
      ]);

      List<dynamic> combined = [];
      if (results[0].statusCode == 200) {
        final data = jsonDecode(results[0].body);
        combined.addAll(data['discounts'] ?? []);
      }
      if (results[1].statusCode == 200) {
        final data = jsonDecode(results[1].body);
        for (var d in (data['discounts'] ?? [])) {
          combined.add({...d, '_isNextDay': true});
        }
      }
      currentDiscounts = combined;
    } catch (_) {
      currentDiscounts = [];
    }
  }

  Map<String, dynamic>? _findDiscountForSlot(TimeSlot slot) {
    try {
      final openMinutes =
          _parseMinutes(widget.field['field_open_time']) ?? 8 * 60;
      final slotMinutes = slot.start.hour * 60 + slot.start.minute;
      final isAfterMidnight = slotMinutes < openMinutes;

      return currentDiscounts.firstWhere((d) {
        final isNextDay = d['_isNextDay'] == true;
        if (isAfterMidnight != isNextDay) return false;

        // Containment, not an exact start match: a discount created on the old
        // 1-hour grid still covers every sub-slot of a 15/30-minute grid.
        final dStart = _parseMinutes(d['start_time']);
        var dEnd = _parseMinutes(d['end_time']);
        if (dStart == null || dEnd == null) return false;
        if (dEnd <= dStart) dEnd += 24 * 60;

        return slotMinutes >= dStart && slotMinutes < dEnd;
      });
    } catch (_) {
      return null;
    }
  }

  void _trackBookings() {
    _generateSlots();
    backgrounds = List.filled(slots.length, null);
    bookedByList = List.filled(slots.length, null);
    _conflictingSlots = [];

    for (int i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final booking = _findBookingForSlot(slot);
      final discount = _findDiscountForSlot(slot);
      final live = _liveBookingsForSlot(slot);
      final occupied = _occupiedSeats(slot);
      final free = _seatsLeft(slot);
      final hiddenRule = _hiddenRuleForSlot(slot);

      // A standing rule outranks everything: the slot is not for sale on any
      // day, so bookings, seats and discounts are all beside the point.
      if (hiddenRule != null) {
        backgrounds[i] = Colors.deepPurple[50];
        bookedByList[i] = "مخفية من التطبيق";
      } else if (occupied > _slotSeats) {
        // A conflict is over-subscription, not simply "more than one
        // booking". On a 1-seat field those are the same thing, so a pitch
        // still flags a double booking exactly as before.
        backgrounds[i] = Colors.red[200];
        if (!_conflictingSlots.contains(slot)) _conflictingSlots.add(slot);
        bookedByList[i] = "تعارض ($occupied/$_slotSeats)";
      } else if (_isMultiSeat && live.isNotEmpty && free > 0) {
        // Partly sold but still bookable: must not look closed.
        backgrounds[i] = Colors.teal[50];
        bookedByList[i] = "$occupied/$_slotSeats - متبقي $free";
      } else if (_isMultiSeat && live.length > 1) {
        // Every seat sold, by several different bookings.
        backgrounds[i] = Colors.blue[100];
        bookedByList[i] = "مكتمل ($occupied/$_slotSeats)";
      } else if (booking != null) {
        String status = booking['booking_status'] ?? "";
        bool isMonthly = booking['booking_is_monthly'] == true;
        if (status == "cancelled") status = "free";
        final monthlySuffix = isMonthly ? " - شهري" : "";
        final booker = booking['booking_user'] ?? "";

        if (status == "pending") {
          backgrounds[i] = isMonthly ? Colors.amber[200] : Colors.yellow[200];
          bookedByList[i] = "$booker$monthlySuffix";
        } else if (status == "confirmed") {
          backgrounds[i] =
              isMonthly ? Colors.deepPurple[100] : Colors.blue[100];
          bookedByList[i] = "$booker$monthlySuffix";
        } else if (status == "unavailable") {
          backgrounds[i] = Colors.grey[400];
          bookedByList[i] = "غير متاح";
        } else {
          if (discount != null) {
            backgrounds[i] = Colors.green[100];
            bookedByList[i] = "خصم";
          } else {
            backgrounds[i] = Colors.white;
            bookedByList[i] = null;
          }
        }
      } else {
        if (discount != null) {
          backgrounds[i] = Colors.green[100];
          bookedByList[i] = "خصم";
        } else {
          backgrounds[i] = Colors.white;
          bookedByList[i] = null;
        }
      }
    }
    if (mounted) setState(() {});
  }

  Map<String, dynamic>? _findBookingForSlot(TimeSlot slot) {
    try {
      return currentBookings.firstWhere((b) {
        final bookingDate = DateTime.parse(b['booking_date']);
        final startParts = (b['start_time'] as String).split(':');
        final endParts = (b['end_time'] as String).split(':');
        final start = DateTime(bookingDate.year, bookingDate.month,
            bookingDate.day, int.parse(startParts[0]), int.parse(startParts[1]));
        var end = DateTime(bookingDate.year, bookingDate.month, bookingDate.day,
            int.parse(endParts[0]), int.parse(endParts[1]));
        if (end.isBefore(start)) end = end.add(const Duration(days: 1));
        final slotStartAdjusted = slot.start.isBefore(start)
            ? slot.start.add(const Duration(days: 1))
            : slot.start;
        return slotStartAdjusted.isAtSameMomentAs(start) ||
            (slotStartAdjusted.isAfter(start) &&
                slotStartAdjusted.isBefore(end));
      });
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _findAllConflictingBookings(TimeSlot slot) {
    List<Map<String, dynamic>> found = [];
    for (var b in currentBookings) {
      try {
        final bookingDate = DateTime.parse(b['booking_date']);
        final startParts = (b['start_time'] as String).split(':');
        final endParts = (b['end_time'] as String).split(':');
        final start = DateTime(bookingDate.year, bookingDate.month,
            bookingDate.day, int.parse(startParts[0]), int.parse(startParts[1]));
        var end = DateTime(bookingDate.year, bookingDate.month, bookingDate.day,
            int.parse(endParts[0]), int.parse(endParts[1]));
        if (end.isBefore(start)) end = end.add(const Duration(days: 1));
        final slotStartAdjusted = slot.start.isBefore(start)
            ? slot.start.add(const Duration(days: 1))
            : slot.start;
        if (slotStartAdjusted.isAtSameMomentAs(start) ||
            (slotStartAdjusted.isAfter(start) &&
                slotStartAdjusted.isBefore(end))) {
          found.add(b as Map<String, dynamic>);
        }
      } catch (_) {}
    }
    return found;
  }

  Future<void> _refreshBookings() async {
    setState(() => _isLoading = true);
    await _loadDiscounts();
    await _loadHiddenSlots();
    final dateString = widget.date.toIso8601String().split('T')[0];
    final response = await http.get(
      Uri.parse(
          "${apiUrl}clients/getfieldBookings/${widget.field['field_id']}/$dateString"),
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'x-api-key': '${dotenv.env['API_KEY']}'
      },
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      currentBookings = data["bookings"] ?? [];
      _trackBookings();
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ─── Discount dialogs ────────────────────────────────────────────────────────

  Future<void> _showAddDiscountDialog(TimeSlot slot) async {
    final bookingPriceController = TextEditingController();
    final remainingPriceController = TextEditingController();
    DateTime? validFrom;
    DateTime? validTo;
    bool isDaily = true;
    bool isMonthly = false;
    String? error;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Text("إضافة خصم للفترة",
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Booking price
                TextField(
                  controller: bookingPriceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: "سعر الحجز المخفض",
                    filled: true,
                    fillColor: Colors.red.shade50,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5),
                        borderSide:
                            const BorderSide(color: Colors.red, width: 1.5)),
                  ),
                  textDirection: TextDirection.ltr,
                ),
                const SizedBox(height: 12),
                // Remaining price
                TextField(
                  controller: remainingPriceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: "السعر المتبقي عند الوصول",
                    filled: true,
                    fillColor: Colors.red.shade50,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5),
                        borderSide:
                            const BorderSide(color: Colors.red, width: 1.5)),
                  ),
                  textDirection: TextDirection.ltr,
                ),
                const SizedBox(height: 16),
                // Valid from
                const Text("صالح من:",
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: widget.date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setStateDialog(() => validFrom = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: Colors.redAccent, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 16, color: Colors.redAccent),
                        const SizedBox(width: 8),
                        Text(
                          validFrom != null
                              ? "${validFrom!.year}-${validFrom!.month.toString().padLeft(2, '0')}-${validFrom!.day.toString().padLeft(2, '0')}"
                              : "اختر تاريخ",
                          style: TextStyle(
                              color: validFrom != null
                                  ? Colors.black87
                                  : Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Valid to
                const Text("صالح حتى:",
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: validFrom ?? widget.date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setStateDialog(() => validTo = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: Colors.redAccent, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 16, color: Colors.redAccent),
                        const SizedBox(width: 8),
                        Text(
                          validTo != null
                              ? "${validTo!.year}-${validTo!.month.toString().padLeft(2, '0')}-${validTo!.day.toString().padLeft(2, '0')}"
                              : "اختر تاريخ",
                          style: TextStyle(
                              color: validTo != null
                                  ? Colors.black87
                                  : Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Applies to
                const Text("يسري على:",
                    style: TextStyle(fontWeight: FontWeight.w600)),
                CheckboxListTile(
                  value: isDaily,
                  onChanged: (v) =>
                      setStateDialog(() => isDaily = v ?? true),
                  title: const Text("حجوزات يومية"),
                  activeColor: Colors.redAccent,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  value: isMonthly,
                  onChanged: (v) =>
                      setStateDialog(() => isMonthly = v ?? false),
                  title: const Text("حجوزات شهرية"),
                  activeColor: Colors.redAccent,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                      textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("إلغاء",
                        style: TextStyle(color: Colors.black54)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5)),
                    ),
                    onPressed: () async {
                      final bookingPrice =
                          bookingPriceController.text.trim();
                      final remainingPrice =
                          remainingPriceController.text.trim();

                      if (bookingPrice.isEmpty) {
                        setStateDialog(
                            () => error = "أدخل سعر الحجز المخفض");
                        return;
                      }
                      if (remainingPrice.isEmpty) {
                        setStateDialog(
                            () => error = "أدخل السعر المتبقي");
                        return;
                      }
                      if (validFrom == null || validTo == null) {
                        setStateDialog(
                            () => error = "اختر نطاق تاريخ الصلاحية");
                        return;
                      }
                      if (validTo!.isBefore(validFrom!)) {
                        setStateDialog(() =>
                            error = "تاريخ الانتهاء يجب أن يكون بعد تاريخ البداية");
                        return;
                      }
                      if (!isDaily && !isMonthly) {
                        setStateDialog(
                            () => error = "اختر نوع الحجز الذي يسري عليه الخصم");
                        return;
                      }

                      Navigator.pop(context);
                      await _createDiscount(
                        slot: slot,
                        bookingPrice: bookingPrice,
                        remainingPrice: remainingPrice,
                        validFrom: validFrom!,
                        validTo: validTo!,
                        isDaily: isDaily,
                        isMonthly: isMonthly,
                      );
                    },
                    child: const Text("تأكيد",
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createDiscount({
    required TimeSlot slot,
    required String bookingPrice,
    required String remainingPrice,
    required DateTime validFrom,
    required DateTime validTo,
    required bool isDaily,
    required bool isMonthly,
  }) async {
    setState(() => _isLoading = true);

    final dateStr = widget.date.toIso8601String().split('T')[0];
    final fromStr =
        "${validFrom.year}-${validFrom.month.toString().padLeft(2, '0')}-${validFrom.day.toString().padLeft(2, '0')}";
    final toStr =
        "${validTo.year}-${validTo.month.toString().padLeft(2, '0')}-${validTo.day.toString().padLeft(2, '0')}";

    final response = await http.post(
      Uri.parse("${apiUrl}clients/createFieldDiscount"),
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
        'x-api-key': '${dotenv.env['API_KEY']}'
      },
      body: jsonEncode({
        'field_id': widget.field['field_id'],
        'date': dateStr,
        'start_time': AppFormat.formatHM(slot.start),
        'end_time': AppFormat.formatHM(slot.end),
        'booking_price': bookingPrice,
        'remaining_price': remainingPrice,
        'is_daily': isDaily,
        'is_monthly': isMonthly,
        'valid_from': fromStr,
        'valid_to': toStr,
      }),
    );

    final data = jsonDecode(response.body);
    final message = data['error'] ?? data['message'] ?? "تم إضافة الخصم";

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        backgroundColor:
            response.statusCode == 200 ? Colors.green : Colors.redAccent,
        duration: const Duration(seconds: 3),
      ));
    }

    if (response.statusCode == 200) await _refreshBookings();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _removeDiscount(Map<String, dynamic> discount) async {
    setState(() => _isLoading = true);

    final discountId = discount['discount_id'];
    final response = await http.delete(
      Uri.parse("${apiUrl}clients/deleteFieldDiscount/$discountId"),
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'x-api-key': '${dotenv.env['API_KEY']}'
      },
    );

    final data = jsonDecode(response.body);
    final message = data['error'] ?? data['message'] ?? "تم إزالة الخصم";

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        backgroundColor:
            response.statusCode == 200 ? Colors.green : Colors.redAccent,
        duration: const Duration(seconds: 3),
      ));
    }

    if (response.statusCode == 200) await _refreshBookings();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _showDiscountedSlotDialog(
      TimeSlot slot, Map<String, dynamic> discount) async {
    final bookingPrice = discount['booking_price'];
    final remainingPrice = discount['remaining_price'];
    final validFrom = discount['valid_from'];
    final validTo = discount['valid_to'];

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text("فترة مخفضة",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
                fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  Text("$bookingPrice د.ل",
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.green)),
                  const SizedBox(height: 4),
                  Text("+ $remainingPrice د.ل عند الوصول",
                      style: TextStyle(
                          fontSize: 13, color: Colors.green.shade700)),
                  if (validFrom != null && validTo != null) ...[
                    const SizedBox(height: 8),
                    Text("$validFrom → $validTo",
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("إغلاق",
                      style: TextStyle(color: Colors.black54)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    await _removeDiscount(discount);
                  },
                  child: const Text("إزالة الخصم",
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Block / unblock ─────────────────────────────────────────────────────────

  Future<Map<String, String?>?> _askGuestInfo(
      {String? initialName, String? initialPhone}) {
    final nameController =
        TextEditingController(text: initialName ?? "");
    final phoneController =
        TextEditingController(text: initialPhone ?? "");

    return showDialog<Map<String, String?>>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("إضافة اسم ورقم الزائر (اختياري)",
            style: TextStyle(fontSize: 16), textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: "اسم الزائر",
                filled: true,
                fillColor: Colors.red.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: const BorderSide(
                        color: Colors.redAccent, width: 1.2)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide:
                        const BorderSide(color: Colors.red, width: 1.5)),
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: InputDecoration(
                labelText: "رقم هاتف الزائر",
                filled: true,
                fillColor: Colors.red.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: const BorderSide(
                        color: Colors.redAccent, width: 1.2)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide:
                        const BorderSide(color: Colors.red, width: 1.5)),
              ),
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text("رجوع"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                  ),
                  onPressed: () => Navigator.pop(context, {
                    "name": nameController.text.trim().isEmpty
                        ? null
                        : nameController.text.trim(),
                    "phone": phoneController.text.trim().isEmpty
                        ? null
                        : phoneController.text.trim(),
                  }),
                  child: const Text("تأكيد",
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _markUnavailable(TimeSlot slot, {int dayCount = 1}) async {
    setState(() => _isLoading = true);
    final response = await http.post(
      Uri.parse("${apiUrl}clients/blockBookingSlots"),
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
        'x-api-key': '${dotenv.env['API_KEY']}'
      },
      body: jsonEncode({
        'field_id': widget.field['field_id'],
        'booking_date': slot.start.toIso8601String().split('T')[0],
        'start_time': AppFormat.formatHM(slot.start),
        'end_time': AppFormat.formatHM(slot.end),
        'day_count': dayCount,
        'guest_name': guestName,
        'guest_phone_number': guestPhoneNumber,
      }),
    );
    if (mounted) setState(() => _isLoading = false);
    final data = jsonDecode(response.body);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(data['error'] ?? data['message'] ?? "تم تحديث الفترات",
            textAlign: TextAlign.center),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ));
    }
    if (response.statusCode == 200) {
      setState(() => _needsRefresh = true);
      await _refreshBookings();
    }
  }

  Future<void> _markMonthly(TimeSlot slot) async {
    setState(() => _isLoading = true);
    final response = await http.post(
      Uri.parse("${apiUrl}clients/blockMonthlyBookingSlots"),
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
        'x-api-key': '${dotenv.env['API_KEY']}'
      },
      body: jsonEncode({
        'field_id': widget.field['field_id'],
        'start_date': slot.start.toIso8601String().split('T')[0],
        'start_time': AppFormat.formatHM(slot.start),
        'end_time': AppFormat.formatHM(slot.end),
        'guest_name': guestName,
        'guest_phone_number': guestPhoneNumber,
      }),
    );
    if (mounted) setState(() => _isLoading = false);
    final data = jsonDecode(response.body);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(data['error'] ?? data['message'] ?? "تم تحديث الفترات",
            textAlign: TextAlign.center),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ));
    }
    if (response.statusCode == 200) {
      setState(() => _needsRefresh = true);
      await _refreshBookings();
    }
  }

  Future<void> _markAvailable(TimeSlot slot) async {
    setState(() => _isLoading = true);
    final url = Uri.parse("${apiUrl}clients/unblockBookingSlots");
    final request = http.Request("DELETE", url)
      ..headers.addAll({
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
        'x-api-key': '${dotenv.env['API_KEY']}'
      })
      ..body = jsonEncode({
        "field_id": widget.field['field_id'],
        "booking_date": slot.start.toIso8601String().split('T')[0],
        "start_time": AppFormat.formatHM(slot.start),
        "end_time": AppFormat.formatHM(slot.end),
      });
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (mounted) setState(() => _isLoading = false);
    final data = jsonDecode(response.body);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(data['error'] ?? data['message'] ?? "تم تحديث الفترات",
            textAlign: TextAlign.center),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ));
    }
    if (response.statusCode == 200) {
      setState(() => _needsRefresh = true);
      await _refreshBookings();
    }
  }

  Future<void> _editUnavailableOptionOne(
      TimeSlot slot, Map<String, dynamic>? booking) async {
    final initialName =
        (booking?['booking_guest_name'] as String?)?.trim();
    final initialPhone =
        (booking?['booking_guest_phone_number'] as String?)?.trim();
    final guest = await _askGuestInfo(
      initialName: (initialName == null || initialName.isEmpty)
          ? null
          : initialName,
      initialPhone: (initialPhone == null || initialPhone.isEmpty)
          ? null
          : initialPhone,
    );
    if (guest == null) return;
    guestName = guest["name"];
    guestPhoneNumber = guest["phone"];
    await _markAvailable(slot);
    await _markUnavailable(slot, dayCount: 1);
  }

  // A slot an admin took off the calendar. Read-only: the owner can see the
  // rule and why it exists, but removing it is an admin action.
  Future<void> _showHiddenSlotDialog(
      TimeSlot slot, Map<String, dynamic> rule) async {
    final reason = (rule['reason'] ?? '').toString().trim();
    final shownAsBooked = rule['display_mode'] == 'booked';

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        title: Center(
          child: Text(
            "${AppFormat.formatTime(slot.start)} - ${AppFormat.formatTime(slot.end)}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "هذه الفترة مخفية من التطبيق في كل الأيام.",
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 8),
            Text(
              shownAsBooked
                  ? "يراها المستخدمون كفترة محجوزة."
                  : "لا يراها المستخدمون إطلاقاً.",
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
            ),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                "السبب: $reason",
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              "للتعديل عليها يرجى التواصل مع الإدارة.",
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إغلاق", style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  // Shown for a slot several bookings share legitimately, which only happens
  // on a field with more than one seat. Lists who is in, and - while seats are
  // still free - offers the same actions a free slot has.
  Future<void> _showSlotSeatsDialog(TimeSlot slot) async {
    final live = _liveBookingsForSlot(slot);
    final occupied = _occupiedSeats(slot);
    final free = _seatsLeft(slot);

    final action = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        title: Center(
          child: Text(
            "${AppFormat.formatTime(slot.start)} - ${AppFormat.formatTime(slot.end)}\n"
            "$occupied من $_slotSeats مقاعد محجوزة",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            textAlign: TextAlign.center,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: live.length,
            itemBuilder: (context, index) {
              final booking = live[index];
              final status = booking['booking_status'] ?? "";
              final seats =
                  int.tryParse(booking['booking_seats']?.toString() ?? '') ?? 1;
              final isMonthly = booking['booking_is_monthly'] == true;

              final String name;
              final Color tint;
              final String statusText;
              if (status == "unavailable") {
                final guest =
                    (booking['booking_guest_name'] as String?)?.trim() ?? "";
                name = guest.isNotEmpty ? guest : "مغلق";
                tint = Colors.grey.shade200;
                statusText = "غير متاح";
              } else if (status == "pending") {
                name = booking['booking_user'] ?? "مستخدم غير معروف";
                tint = Colors.yellow.shade100;
                statusText = "معلّق";
              } else {
                name = booking['booking_user'] ?? "مستخدم غير معروف";
                tint = Colors.blue.shade50;
                statusText = "مؤكّد";
              }

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  tileColor: tint,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  title: Text(name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textDirection: TextDirection.rtl),
                  subtitle: Text(
                    "$statusText${isMonthly ? ' | شهري' : ''}"
                    "${seats > 1 ? ' | $seats مقاعد' : ''}",
                    style: const TextStyle(fontSize: 13),
                    textDirection: TextDirection.rtl,
                  ),
                  onTap: () => Navigator.pop(context, "booking:$index"),
                ),
              );
            },
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (free > 0) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5)),
                    ),
                    onPressed: () => Navigator.pop(context, "block"),
                    child: Text("إغلاق المقاعد المتبقية ($free)",
                        style: const TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5)),
                    ),
                    onPressed: () => Navigator.pop(context, "discount"),
                    child: const Text("إضافة خصم",
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child:
                      const Text("إغلاق", style: TextStyle(color: Colors.grey)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (action == null) return;

    if (action == "block") {
      final guest = await _askGuestInfo();
      if (guest == null) return;
      guestName = guest["name"];
      guestPhoneNumber = guest["phone"];
      // No seat count is sent, so the backend takes every seat still free -
      // the same "close this slot" meaning it has always had.
      await _markUnavailable(slot, dayCount: 1);
      return;
    }

    if (action == "discount") {
      await _showAddDiscountDialog(slot);
      return;
    }

    if (action.startsWith("booking:")) {
      final booking = live[int.parse(action.substring("booking:".length))];

      if (booking['booking_status'] == "unavailable") {
        final choice = await _showUnavailableActionsDialog();
        if (choice == "unblock") {
          await _markAvailable(slot);
        } else if (choice == "edit") {
          await _editUnavailableOptionOne(slot, booking);
        }
        return;
      }

      await _navigateToBookingDetails(booking);
    }
  }

  Future<void> _showConflictDetailsDialog(TimeSlot slot) async {
    final conflictingBookings = _findAllConflictingBookings(slot);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        title: Center(
          child: Text(
            "تعارض (${conflictingBookings.length}) - ${AppFormat.formatTime(slot.start)} - ${AppFormat.formatTime(slot.end)}",
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
                fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: conflictingBookings.length,
            itemBuilder: (context, index) {
              final booking = conflictingBookings[index];
              final bookerName =
                  booking['booking_user'] ?? "مستخدم غير معروف";
              final bookingId = booking['booking_id'] ?? "N/A";
              final isMonthly = booking['booking_is_monthly'] == true;
              final status = booking['booking_status'] ?? "";
              Color statusColor;
              String statusText;
              if (status == "pending") {
                statusColor = Colors.yellow.shade700;
                statusText = "معلّق";
              } else if (status == "confirmed") {
                statusColor = Colors.blue.shade700;
                statusText = "مؤكّد";
              } else {
                statusColor = Colors.grey.shade700;
                statusText = "غير محدد";
              }
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  tileColor: Colors.red.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                    side: const BorderSide(
                        color: Colors.redAccent, width: 0.5),
                  ),
                  title: Text(bookerName,
                      style:
                          const TextStyle(fontWeight: FontWeight.bold),
                      textDirection: TextDirection.rtl),
                  subtitle: Text(
                      "الحالة: $statusText${isMonthly ? ' | شهري' : ''}",
                      style:
                          TextStyle(color: statusColor, fontSize: 13),
                      textDirection: TextDirection.rtl),
                  trailing: Text("ID: $bookingId",
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 10)),
                  onTap: () async {
                    Navigator.pop(context);
                    await _navigateToBookingDetails(booking);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إغلاق",
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToBookingDetails(
      Map<String, dynamic> bookingToView) async {
    final bookingDate = DateTime.parse(bookingToView['booking_date']);
    final startParts = (bookingToView['start_time'] as String).split(':');
    final endParts = (bookingToView['end_time'] as String).split(':');
    var bookingStart = DateTime(bookingDate.year, bookingDate.month,
        bookingDate.day, int.parse(startParts[0]), int.parse(startParts[1]));
    var bookingEnd = DateTime(bookingDate.year, bookingDate.month,
        bookingDate.day, int.parse(endParts[0]), int.parse(endParts[1]));
    if (bookingEnd.isBefore(bookingStart)) {
      bookingEnd = bookingEnd.add(const Duration(days: 1));
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingDetailsPage(
          booking: bookingToView,
          start: bookingStart,
          end: bookingEnd,
          field: widget.field,
          token: widget.token,
        ),
      ),
    );
    if (result == true) {
      setState(() => _needsRefresh = true);
      await _refreshBookings();
    }
  }

  Future<String?> _showUnavailableActionsDialog() {
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        title: const Text("الفترة مغلقة",
            textAlign: TextAlign.center),
        content: const Text("اختر الإجراء:",
            textAlign: TextAlign.center),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () =>
                          Navigator.pop(context, "cancel"),
                      child: const Text("الرجوع",
                          style: TextStyle(color: Colors.black54)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5)),
                      ),
                      onPressed: () =>
                          Navigator.pop(context, "unblock"),
                      child: const Text("فتح الفترة",
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () =>
                      Navigator.pop(context, "edit"),
                  child: const Text("تعديل",
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: WillPopScope(
        onWillPop: () async {
          Navigator.pop(context, _needsRefresh);
          return false;
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(AppFormat.formatDateArabic(widget.date),
                style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          backgroundColor: Colors.red.shade50,
          body: Stack(
            children: [
              slots.isEmpty && !_isLoading
                  ? const Center(child: Text("لا توجد فترات"))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: slots.length +
                          (_conflictingSlots.isNotEmpty ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (_conflictingSlots.isNotEmpty && i == 0) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(5),
                              border:
                                  Border.all(color: Colors.red.shade400),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text("توجد حجوزات متعارضة",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red),
                                    textAlign: TextAlign.center),
                                ..._conflictingSlots.map((slot) {
                                  final count = _occupiedSeats(slot);
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      "${AppFormat.formatTime(slot.start)} - ${AppFormat.formatTime(slot.end)}: $count حجوزات على $_slotSeats مقاعد",
                                      style: TextStyle(
                                          color: Colors.red.shade700),
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                }),
                                const Padding(
                                  padding: EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    "يرجى مراجعة هذه الفترات.",
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.red),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final adjustedIndex =
                            i - (_conflictingSlots.isNotEmpty ? 1 : 0);
                        final slot = slots[adjustedIndex];
                        final booking = _findBookingForSlot(slot);
                        final discount = _findDiscountForSlot(slot);

                        String status =
                            booking?['booking_status'] ?? "";
                        if (status == "cancelled") status = "";

                        final live = _liveBookingsForSlot(slot);
                        final occupied = _occupiedSeats(slot);
                        final free = _seatsLeft(slot);
                        final hiddenRule = _hiddenRuleForSlot(slot);
                        final bool isHidden = hiddenRule != null;

                        final bool isConflicting =
                            !isHidden && _conflictingSlots.contains(slot);
                        // Seats left on a multi-seat field: still open for
                        // business, so it behaves like a free slot that also
                        // knows who is already in.
                        final bool isPartial = !isHidden &&
                            !isConflicting &&
                            _isMultiSeat &&
                            live.isNotEmpty &&
                            free > 0;
                        // Sold out across several bookings: tapping has to ask
                        // which one, there is no single booking to open.
                        final bool isSharedFull = !isHidden &&
                            !isConflicting &&
                            !isPartial &&
                            _isMultiSeat &&
                            live.length > 1;

                        final bool isBooked = !isHidden &&
                            !isPartial &&
                            !isSharedFull &&
                            (status == "pending" || status == "confirmed");
                        final bool isUnavailable = !isHidden &&
                            !isPartial &&
                            !isSharedFull &&
                            status == "unavailable";
                        final bool isFreeWithDiscount = !isHidden &&
                            !isBooked &&
                                !isUnavailable &&
                                !isPartial &&
                                !isSharedFull &&
                                discount != null;

                        String? subtitleText;
                        if (isHidden) {
                          final reason =
                              (hiddenRule['reason'] ?? '').toString().trim();
                          subtitleText = reason.isNotEmpty
                              ? "مخفية من التطبيق • $reason"
                              : "مخفية من التطبيق (كل الأيام)";
                        } else if (isConflicting) {
                          subtitleText =
                              "تعارض: $occupied حجوزات على $_slotSeats مقاعد";
                        } else if (isPartial) {
                          subtitleText = discount != null
                              ? "متبقي $free من $_slotSeats • خصم ${discount['booking_price']} د.ل"
                              : "محجوز $occupied من $_slotSeats • متبقي $free";
                        } else if (isSharedFull) {
                          subtitleText =
                              "مكتمل: $occupied من $_slotSeats مقاعد (${live.length} حجوزات)";
                        } else if (isBooked) {
                          final isMonthly =
                              booking?['booking_is_monthly'] == true;
                          final bookerName =
                              booking?['booking_user'] ?? "";
                          subtitleText =
                              "محجوز من قبل $bookerName${isMonthly ? ' - شهري' : ''}";
                        } else if (isUnavailable) {
                          final guest =
                              booking?['booking_guest_name'];
                          final guestPhone =
                              booking?['booking_guest_phone_number'];
                          if (guest != null &&
                              guest.toString().trim().isNotEmpty) {
                            subtitleText =
                                "غير متاح • $guest (${guestPhone ?? 'بدون رقم'})";
                          } else if (guestPhone != null &&
                              guestPhone.toString().trim().isNotEmpty) {
                            subtitleText = "غير متاح • $guestPhone";
                          } else {
                            subtitleText = "غير متاح";
                          }
                        } else if (isFreeWithDiscount) {
                          subtitleText =
                              "عرض خاص: ${discount['booking_price']} د.ل + ${discount['remaining_price']} د.ل عند الوصول";
                        }

                        bool sameAsPrev = false;
                        bool sameAsNext = false;
                        // Seat labels are counts, so two unrelated slots can
                        // read the same; merging them into one block would be
                        // a lie about a single long booking.
                        if (!isUnavailable &&
                            !isFreeWithDiscount &&
                            !isPartial &&
                            !isSharedFull &&
                            !isHidden) {
                          sameAsPrev = adjustedIndex > 0 &&
                              bookedByList[adjustedIndex] != null &&
                              bookedByList[adjustedIndex] ==
                                  bookedByList[adjustedIndex - 1];
                          sameAsNext =
                              adjustedIndex < slots.length - 1 &&
                                  bookedByList[adjustedIndex] != null &&
                                  bookedByList[adjustedIndex] ==
                                      bookedByList[adjustedIndex + 1];
                        }

                        BorderRadius radius;
                        if (sameAsPrev && sameAsNext) {
                          radius = BorderRadius.zero;
                        } else if (sameAsPrev && !sameAsNext) {
                          radius = const BorderRadius.only(
                              bottomLeft: Radius.circular(5),
                              bottomRight: Radius.circular(5));
                        } else if (!sameAsPrev && sameAsNext) {
                          radius = const BorderRadius.only(
                              topLeft: Radius.circular(5),
                              topRight: Radius.circular(5));
                        } else {
                          radius = BorderRadius.circular(5);
                        }

                        return Container(
                          margin: EdgeInsets.only(
                              bottom: sameAsNext ? 0 : 6),
                          decoration: BoxDecoration(
                            color: backgrounds[adjustedIndex] ??
                                Colors.white,
                            borderRadius: radius,
                          ),
                          child: ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 8),
                            title: Center(
                              child: Text(
                                "${AppFormat.formatTime(slot.start)} - ${AppFormat.formatTime(slot.end)}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            subtitle: !sameAsPrev && subtitleText != null
                                ? Center(
                                    child: Text(
                                      subtitleText,
                                      style: TextStyle(
                                        color: isFreeWithDiscount
                                            ? Colors.green.shade800
                                            : null,
                                        fontWeight: isFreeWithDiscount
                                            ? FontWeight.w600
                                            : null,
                                      ),
                                    ),
                                  )
                                : null,
                            onTap: () async {
                              // Nothing to do here: only an admin can lift a
                              // standing rule, so this just explains itself.
                              if (isHidden) {
                                await _showHiddenSlotDialog(slot, hiddenRule);
                                return;
                              }

                              if (isConflicting) {
                                await _showConflictDetailsDialog(slot);
                                return;
                              }

                              // Several bookings share this slot, so there is
                              // no single one to open: show them and, when
                              // seats are left, the actions for the rest.
                              if (isPartial || isSharedFull) {
                                await _showSlotSeatsDialog(slot);
                                return;
                              }

                              if (isFreeWithDiscount) {
                                await _showDiscountedSlotDialog(
                                    slot, discount);
                                return;
                              }

                              if (status == "free" || status == "") {
                                // Show options: close slot OR add discount
                                final choice = await showDialog<String>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(5)),
                                    title: const Text("اختر إجراء",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontWeight:
                                                FontWeight.bold)),
                                    actionsPadding:
                                        const EdgeInsets.fromLTRB(
                                            16, 0, 16, 12),
                                    actions: [
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              style:
                                                  ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.redAccent,
                                                minimumSize:
                                                    const Size.fromHeight(
                                                        48),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(5)),
                                              ),
                                              onPressed: () =>
                                                  Navigator.pop(
                                                      context, "block"),
                                              child: const Text(
                                                  "إغلاق الفترة",
                                                  style: TextStyle(
                                                      color:
                                                          Colors.white)),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              style:
                                                  ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.green,
                                                minimumSize:
                                                    const Size.fromHeight(
                                                        48),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(5)),
                                              ),
                                              onPressed: () =>
                                                  Navigator.pop(
                                                      context,
                                                      "discount"),
                                              child: const Text(
                                                  "إضافة خصم",
                                                  style: TextStyle(
                                                      color:
                                                          Colors.white)),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          SizedBox(
                                            width: double.infinity,
                                            child: TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(
                                                      context, null),
                                              child: const Text("إلغاء",
                                                  style: TextStyle(
                                                      color:
                                                          Colors.grey)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );

                                if (choice == "discount") {
                                  await _showAddDiscountDialog(slot);
                                } else if (choice == "block") {
                                  int selectedDays = 1;
                                  final dayCount =
                                      await showDialog<int>(
                                    context: context,
                                    builder: (_) => StatefulBuilder(
                                      builder:
                                          (context, setStateDialog) =>
                                              AlertDialog(
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    5)),
                                        title: const Text(
                                            "تحديد كغير متاح؟",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontWeight:
                                                    FontWeight.bold)),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ElevatedButton(
                                              style:
                                                  ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.redAccent,
                                                minimumSize:
                                                    const Size.fromHeight(
                                                        60),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(5)),
                                              ),
                                              onPressed: () =>
                                                  Navigator.pop(
                                                      context, -1),
                                              child: const Text(
                                                  "اقفال شهري لهذه الفترة",
                                                  style: TextStyle(
                                                      color:
                                                          Colors.white)),
                                            ),
                                            const SizedBox(height: 5),
                                            const Divider(),
                                            const Text("او"),
                                            const SizedBox(height: 5),
                                            const Text(
                                                "اقفال الفترة لعدد ايام (1 - 30):"),
                                            const SizedBox(height: 10),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        5),
                                                border: Border.all(
                                                    color: Colors.redAccent,
                                                    width: 1.5),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .center,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons
                                                            .remove_circle_outline,
                                                        color: Colors
                                                            .redAccent),
                                                    onPressed: () {
                                                      if (selectedDays >
                                                          1) {
                                                        setStateDialog(() =>
                                                            selectedDays--);
                                                      }
                                                    },
                                                  ),
                                                  Text("$selectedDays",
                                                      style: const TextStyle(
                                                          fontSize: 20,
                                                          fontWeight:
                                                              FontWeight
                                                                  .bold,
                                                          color: Colors
                                                              .redAccent)),
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons
                                                            .add_circle_outline,
                                                        color: Colors
                                                            .redAccent),
                                                    onPressed: () {
                                                      if (selectedDays == 30) {
                                                        setStateDialog(() =>
                                                            selectedDays++);
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        actionsAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, null),
                                            child: const Text("إلغاء",
                                                style: TextStyle(
                                                    color: Colors.grey)),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.redAccent,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          5)),
                                            ),
                                            onPressed: () => Navigator.pop(
                                                context, selectedDays),
                                            child: const Text("تأكيد",
                                                style: TextStyle(
                                                    color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );

                                  if (dayCount == -1) {
                                    final guest = await _askGuestInfo();
                                    if (guest == null) return;
                                    guestName = guest["name"];
                                    guestPhoneNumber = guest["phone"];
                                    await _markMonthly(slot);
                                  } else if (dayCount != null) {
                                    final guest = await _askGuestInfo();
                                    if (guest == null) return;
                                    guestName = guest["name"];
                                    guestPhoneNumber = guest["phone"];
                                    await _markUnavailable(slot,
                                        dayCount: dayCount);
                                  }
                                }
                              } else if (isUnavailable) {
                                final action =
                                    await _showUnavailableActionsDialog();
                                if (action == "unblock") {
                                  await _markAvailable(slot);
                                } else if (action == "edit") {
                                  await _editUnavailableOptionOne(
                                      slot, booking);
                                }
                              } else {
                                final bookingToView =
                                    _findBookingForSlot(slot);
                                if (bookingToView == null) return;
                                await _navigateToBookingDetails(
                                    bookingToView);
                              }
                            },
                          ),
                        );
                      },
                    ),
              if (_isLoading)
                Container(
                  color: Colors.black45,
                  child: const Center(
                    child:
                        CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class TimeSlot {
  final DateTime start;
  final DateTime end;

  TimeSlot({required this.start, required this.end});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeSlot &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => start.hashCode ^ end.hashCode;
}