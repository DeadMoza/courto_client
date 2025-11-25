  import 'package:client_app/constants.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter_dotenv/flutter_dotenv.dart';
  import 'booking_details_page.dart';
  import 'package:http/http.dart' as http;
  import 'dart:convert';

  // Assuming TimeSlot class and widget imports are correct and available
  // (They are included in the provided code)

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
    late List<TimeSlot> slots;
    late List<Color?> backgrounds;
    late List<String?> bookedByList;
    late List<dynamic> currentBookings;
    bool _needsRefresh = false;
    bool _isLoading = false;
    final apiUrl = dotenv.env['API_URL'];
    List<TimeSlot> _conflictingSlots = [];
    String? guestName;
    String? guestPhoneNumber;

    @override
    void initState() {
      super.initState();
      _updateBookingsAndSlots();
    }

    @override
    void didUpdateWidget(covariant BookingSlotsPage oldWidget) {
      super.didUpdateWidget(oldWidget);
      if (widget.bookings != oldWidget.bookings) {
        _updateBookingsAndSlots();
      }
    }

    void _updateBookingsAndSlots() {
      currentBookings = List.from(widget.bookings);
      _trackBookings();
    }

    void _generateSlots() {
      final openParts = (widget.field['field_open_time'] ?? '08:00').split(':');
      final closeParts = (widget.field['field_close_time'] ?? '20:00').split(':');
      int openHour = int.parse(openParts[0]);
      int closeHour = int.parse(closeParts[0]);
      if (closeHour <= openHour) closeHour += 24;

      slots = [];
      for (int hour = openHour; hour < closeHour; hour++) {
        DateTime start =
            DateTime(widget.date.year, widget.date.month, widget.date.day, hour % 24);
        DateTime end = DateTime(
            widget.date.year, widget.date.month, widget.date.day, (hour + 1) % 24);
        if ((hour + 1) >= 24) end = end.add(const Duration(days: 1));
        slots.add(TimeSlot(start: start, end: end));
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
        final conflictingBookings = _findAllConflictingBookings(slot);

        if (conflictingBookings.length > 1) {
          backgrounds[i] = Colors.red[200];
          if (!_conflictingSlots.contains(slot)) {
            _conflictingSlots.add(slot);
          }
    
          bookedByList[i] = "تعارض (${conflictingBookings.length})";
        } else if (booking != null) {
          String status = booking['booking_status'] ?? "";
          bool isMonthly = (booking['booking_is_monthly'] == true);
          if (status == "cancelled") status = "free";

          String monthlySuffix = isMonthly ? " - شهري" : "";
          String booker = booking['booking_user'] ?? "";

          if (status == "pending") {
            backgrounds[i] = isMonthly ? Colors.amber[200] : Colors.yellow[200];
            bookedByList[i] = "$booker$monthlySuffix";
          } else if (status == "confirmed") {
            backgrounds[i] = isMonthly ? Colors.deepPurple[100] : Colors.blue[100];
            bookedByList[i] = "$booker$monthlySuffix";
          } else if (status == "unavailable") {
            backgrounds[i] = Colors.grey[400];
            bookedByList[i] = "غير متاح"; 
          } else {
            backgrounds[i] = Colors.white;
            bookedByList[i] = null;
          }
        } else {
          backgrounds[i] = Colors.white;
          bookedByList[i] = null;
        }
      }
      setState(() {});
    }

    Map<String, dynamic>? _findBookingForSlot(TimeSlot slot) {
      try {
        return currentBookings.firstWhere(
          (b) {
            final bookingDate = DateTime.parse(b['booking_date']);
            final startParts = (b['start_time'] as String).split(':');
            final endParts = (b['end_time'] as String).split(':');

            final start = DateTime(
              bookingDate.year,
              bookingDate.month,
              bookingDate.day,
              int.parse(startParts[0]),
              int.parse(startParts[1]),
            );

            var end = DateTime(
              bookingDate.year,
              bookingDate.month,
              bookingDate.day,
              int.parse(endParts[0]),
              int.parse(endParts[1]),
            );

            if (end.isBefore(start)) {
              end = end.add(const Duration(days: 1));
            }

            final slotStartAdjusted = slot.start.isBefore(start)
                ? slot.start.add(const Duration(days: 1))
                : slot.start;

            return slotStartAdjusted.isAtSameMomentAs(start) ||
                (slotStartAdjusted.isAfter(start) && slotStartAdjusted.isBefore(end));
          },
        );
      } catch (e) {
        return null;
      }
    }

    List<Map<String, dynamic>> _findAllConflictingBookings(TimeSlot slot) {
      List<Map<String, dynamic>> foundBookings = [];
      for (var b in currentBookings) {
        try {
          final bookingDate = DateTime.parse(b['booking_date']);
          final startParts = (b['start_time'] as String).split(':');
          final endParts = (b['end_time'] as String).split(':');

          final start = DateTime(
            bookingDate.year,
            bookingDate.month,
            bookingDate.day,
            int.parse(startParts[0]),
            int.parse(startParts[1]),
          );

          var end = DateTime(
            bookingDate.year,
            bookingDate.month,
            bookingDate.day,
            int.parse(endParts[0]),
            int.parse(endParts[1]),
          );

          if (end.isBefore(start)) {
            end = end.add(const Duration(days: 1));
          }

          final slotStartAdjusted = slot.start.isBefore(start)
              ? slot.start.add(const Duration(days: 1))
              : slot.start;

          if (slotStartAdjusted.isAtSameMomentAs(start) ||
              (slotStartAdjusted.isAfter(start) && slotStartAdjusted.isBefore(end))) {
            foundBookings.add(b as Map<String, dynamic>);
          }
        } catch (e) {
        }
      }
      return foundBookings;
    }

    Future<Map<String, String?>> _askGuestInfo() async {
    TextEditingController nameController = TextEditingController();
    TextEditingController phoneController = TextEditingController();

    final result = await showDialog<Map<String, String?>>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("إضافة اسم ورقم الزائر (اختياري)", style: TextStyle(fontSize: 16),),
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
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red, width: 1.5),
                ),
              ),
              textDirection: TextDirection.rtl,
            ),

              SizedBox(height: 12),

              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: "رقم هاتف الزائر",
                  filled: true,
                  fillColor: Colors.red.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.red, width: 1.5),
                  ),
                ),
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.rtl,
              ),

          ],
        ),
        actions: [
          TextButton(
            child: const Text("رجوع"),
            onPressed: () => Navigator.pop(context, {
              "name": null,
              "phone": null,
            }),
          ),
          TextButton(
            child: const Text("تأكيد"),
            onPressed: () => Navigator.pop(context, {
              "name": nameController.text.isEmpty ? null : nameController.text,
              "phone": phoneController.text.isEmpty ? null : phoneController.text,
            }),
          ),
        ],
      ),
    );

    return result ?? {"name": null, "phone": null};
  }


    Future<void> _refreshBookings() async {
      setState(() => _isLoading = true);
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
        setState(() {
          currentBookings = data["bookings"] as List<dynamic>;
          _trackBookings();
        });
      }
      setState(() => _isLoading = false);
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
          'guest_phone_number': guestPhoneNumber
        }),
      );

      setState(() => _isLoading = false);

      final data = jsonDecode(response.body);
      final message = data['error'] ?? data['message'] ?? "تم تحديث الفترات";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, textAlign: TextAlign.center),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 3),
        ),
      );

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
          'guest_phone_number': guestPhoneNumber
        }),
      );

      setState(() => _isLoading = false);

      final data = jsonDecode(response.body);
      // print(data); // Removed print for cleaner code
      final message = data['error'] ?? data['message'] ?? "تم تحديث الفترات";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, textAlign: TextAlign.center),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 3),
        ),
      );

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

      setState(() => _isLoading = false);

      final data = jsonDecode(response.body);
      final message = data['error'] ?? data['message'] ?? "تم تحديث الفترات";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, textAlign: TextAlign.center),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 3),
        ),
      );

      if (response.statusCode == 200) {
        setState(() => _needsRefresh = true);
        await _refreshBookings();
      }
    }

    // --- MODIFIED: Conflict Details Dialog to show monthly status ---
    Future<void> _showConflictDetailsDialog(TimeSlot slot) async {
      final conflictingBookings = _findAllConflictingBookings(slot);

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          title: Center(
            child: Text(
              // Show the number of conflicting bookings in the title
              "تعارض (${conflictingBookings.length}) - ${AppFormat.formatTime(slot.start)} - ${AppFormat.formatTime(slot.end)}",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 16),
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
                final bookerName = booking['booking_user'] ?? "مستخدم غير معروف";
                final bookingId = booking['booking_id'] ?? "N/A";
                final isMonthly = (booking['booking_is_monthly'] == true); // Check for monthly

                // Determine status and color
                String status = booking['booking_status'] ?? "";

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

                // Add monthly status to the text
                String subtitleText = "الحالة: $statusText";
                if (isMonthly) {
                  subtitleText += " | شهري";
                }

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    tileColor: Colors.red.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                      side: const BorderSide(color: Colors.redAccent, width: 0.5),
                    ),
                    title: Text(
                      bookerName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textDirection: TextDirection.rtl,
                    ),
                    subtitle: Text(
                      subtitleText,
                      style: TextStyle(color: statusColor, fontSize: 13),
                      textDirection: TextDirection.rtl,
                    ),
                    trailing: Text(
                      "ID: $bookingId",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                    ),
                    onTap: () async {
                      Navigator.pop(context); // Close the conflict dialog
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
              child: const Text("إغلاق", style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      );
    }

    // --- NEW: Helper function to navigate to details and handle refresh ---
    Future<void> _navigateToBookingDetails(Map<String, dynamic> bookingToView) async {
      final bookingDate = DateTime.parse(bookingToView['booking_date']);
      final startParts = (bookingToView['start_time'] as String).split(':');
      final endParts = (bookingToView['end_time'] as String).split(':');

      var bookingStart = DateTime(
        bookingDate.year,
        bookingDate.month,
        bookingDate.day,
        int.parse(startParts[0]),
        int.parse(startParts[1]),
      );
      var bookingEnd = DateTime(
        bookingDate.year,
        bookingDate.month,
        bookingDate.day,
        int.parse(endParts[0]),
        int.parse(endParts[1]),
      );

      // Handle overnight bookings if applicable
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
              title: Text(
                AppFormat.formatDateArabic(widget.date),
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.redAccent,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            backgroundColor: Colors.red.shade50,
            body: Stack(
              children: [
                ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: slots.length + (_conflictingSlots.isNotEmpty ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (_conflictingSlots.isNotEmpty && i == 0) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.red.shade400),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "توجد حجوزات متعارضة",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            ..._conflictingSlots.map((slot) {
                              final conflictingBookings = _findAllConflictingBookings(slot);
                              return Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  "${AppFormat.formatTime(slot.start)} - ${AppFormat.formatTime(slot.end)}: ${conflictingBookings.length} حجوزات متداخلة",
                                  style: TextStyle(color: Colors.red.shade700),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }).toList(),
                            const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text(
                                "يرجى مراجعة هذه الفترات. عند النقر على الفترة، سيتم عرض قائمة بالحجوزات المتعارضة للمراجعة.",
                                style: TextStyle(fontSize: 12, color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final adjustedIndex = i - (_conflictingSlots.isNotEmpty ? 1 : 0);
                    final slot = slots[adjustedIndex];
                    final booking = _findBookingForSlot(slot);

                    String status = booking?['booking_status'] ?? "";
                    if (status == "cancelled") status = "";

                    bool isBooked = status == "pending" || status == "confirmed";
                    bool isUnavailable = status == "unavailable";

                    bool isConflicting = _conflictingSlots.contains(slot);
            
                    String? subtitleText;
                    if (isConflicting) {
                        final conflictingBookingsCount = _findAllConflictingBookings(slot).length;
                        subtitleText = "تعارض: $conflictingBookingsCount حجوزات";
                    } else if (isBooked) {
                        bool isMonthly = (booking?['booking_is_monthly'] == true);
                        String bookerName = booking?['booking_user'] ?? "";
                        String monthlySuffix = isMonthly ? " - شهري" : "";
                        subtitleText = "محجوز من قبل $bookerName$monthlySuffix";
                    } else if (isUnavailable) {
                      final guest = booking?['booking_guest_name'];
                      final guestPhone = booking?['booking_guest_phone_number'];

                      if (guest != null && guest.toString().trim().isNotEmpty) {
                        // Name exists (show both)
                        subtitleText = "غير متاح • $guest (${guestPhone ?? 'بدون رقم'})";
                      } else if (guestPhone != null && guestPhone.toString().trim().isNotEmpty) {
                        // No name → show phone only
                        subtitleText = "غير متاح • $guestPhone";
                      } else {
                        subtitleText = "غير متاح";
                      }
                    }



                    // Existing logic for grouping adjacent slots
                    bool sameAsPrev = adjustedIndex > 0 &&
                        bookedByList[adjustedIndex] != null &&
                        bookedByList[adjustedIndex] == bookedByList[adjustedIndex - 1];
                    bool sameAsNext = adjustedIndex < slots.length - 1 &&
                        bookedByList[adjustedIndex] != null &&
                        bookedByList[adjustedIndex] == bookedByList[adjustedIndex + 1];

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
                      margin: EdgeInsets.only(bottom: sameAsNext ? 0 : 6),
                      decoration: BoxDecoration(
                        color: backgrounds[adjustedIndex] ?? Colors.white,
                        borderRadius: radius,
                      ),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 8),
                        title: Center(
                          child: Text(
                            "${AppFormat.formatTime(slot.start)} - ${AppFormat.formatTime(slot.end)}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        // Only show subtitle if it's the start of a group or a single slot
                        subtitle: !sameAsPrev && subtitleText != null
                            ? Center(child: Text(subtitleText))
                            : null,
                        onTap: () async {
                          if (isConflicting) {
                            // --- Handle conflict tap ---
                            await _showConflictDetailsDialog(slot);
                            return; // Stop execution here
                          }

                          if (status == "free" || status == "") {
                            int selectedDays = 1;
                            final dayCount = await showDialog<int>(
                              context: context,
                              builder: (_) {
                                return StatefulBuilder(
                                  builder: (context, setStateDialog) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    title: const Text(
                                      "تحديد كغير متاح؟",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                            minimumSize: const Size.fromHeight(60),
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(5)),
                                          ),
                                          onPressed: () async {
                                            Navigator.pop(context, -1); // Monthly block
                                          },
                                          child: const Text(
                                            "اقفال شهري لهذه الفترة",
                                            style: TextStyle(color: Colors.white),
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        const Divider(),
                                        const Text("او"),
                                        const SizedBox(height: 5),
                                        const Text("اقفال الفترة لعدد ايام (1 - 30):"),
                                        const SizedBox(height: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(5),
                                            border: Border.all(color: Colors.redAccent, width: 1.5),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                                onPressed: () {
                                                  if (selectedDays > 1) {
                                                    setStateDialog(() => selectedDays--);
                                                  }
                                                },
                                              ),
                                              Text(
                                                "$selectedDays",
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.redAccent,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.add_circle_outline, color: Colors.redAccent),
                                                onPressed: () {
                                                  if (selectedDays < 30) {
                                                    setStateDialog(() => selectedDays++);
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    actionsAlignment: MainAxisAlignment.spaceBetween,
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, null),
                                        child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.redAccent,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                        ),
                                        onPressed: () => Navigator.pop(context, selectedDays),
                                        child: const Text("تأكيد", style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );

                          if (dayCount == -1) {
                            // Monthly block chosen → ask for guest info
                            final guest = await _askGuestInfo();
                            guestName = guest["name"];
                            guestPhoneNumber = guest["phone"];

                            await _markMonthly(slot);

                          } else if (dayCount != null) {
                            // Daily block chosen → ask for guest info
                            final guest = await _askGuestInfo();
                            guestName = guest["name"];
                            guestPhoneNumber = guest["phone"];

                            await _markUnavailable(slot, dayCount: dayCount);
                          }

                          } else if (isUnavailable) {
                            bool? mark = await showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text("تحديد كمتاح؟"),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text("لا")),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text("نعم")),
                                ],
                              ),
                            );
                            if (mark == true) await _markAvailable(slot);
                          } else {
                            final bookingToView = _findBookingForSlot(slot);
                            if (bookingToView == null) return; // Should not happen for booked slots

                            // --- Re-using the new helper function ---
                            await _navigateToBookingDetails(bookingToView);
                            // --- End Re-using the new helper function ---
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
                      child: CircularProgressIndicator(color: Colors.white),
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