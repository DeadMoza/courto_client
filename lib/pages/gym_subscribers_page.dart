import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// What a gym owner sees where a field owner sees a calendar.
///
/// A gym sells memberships rather than time slots, so there is nothing to lay
/// out on a grid: the useful view is who is currently in, who has lapsed, and
/// when each membership runs out.
class GymSubscribersPage extends StatefulWidget {
  final Map<String, dynamic> plan;
  final String? token;

  const GymSubscribersPage({super.key, required this.plan, this.token});

  @override
  State<GymSubscribersPage> createState() => _GymSubscribersPageState();
}

class _GymSubscribersPageState extends State<GymSubscribersPage> {
  List<dynamic> subscribers = [];
  bool loading = true;
  String? errorMessage;

  // null = everyone. The server filters on the computed status, so asking for
  // 'expired' finds lapsed rows even before the sweep has corrected them.
  String? statusFilter;

  final apiUrl = dotenv.env['API_URL'];

  @override
  void initState() {
    super.initState();
    _fetchSubscribers();
  }

  Future<void> _fetchSubscribers() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    final planId = widget.plan['plan_id'];
    final query = statusFilter == null ? '' : '?status=$statusFilter';

    try {
      final res = await http.get(
        Uri.parse("${apiUrl}clients/getPlanSubscribers/$planId$query"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.token}",
          'x-api-key': '${dotenv.env['API_KEY']}'
        },
      );

      final data = json.decode(res.body);

      if (res.statusCode == 200) {
        setState(() {
          subscribers = data['subscribers'] ?? [];
          loading = false;
        });
      } else {
        setState(() {
          errorMessage = data['error'] ?? "فشل تحميل المشتركين";
          loading = false;
        });
      }
    } catch (_) {
      setState(() {
        errorMessage = "فشل التحميل، تحقق من اتصالك بالإنترنت";
        loading = false;
      });
    }
  }

  int get _activeCount =>
      subscribers.where((s) => s['status'] == 'active').length;

  String _statusLabel(String? status) {
    switch (status) {
      case 'active':
        return 'نشط';
      case 'expired':
        return 'منتهي';
      case 'paused':
        return 'موقوف';
      case 'cancelled':
        return 'ملغي';
    }
    return status ?? '';
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'expired':
        return Colors.redAccent;
      case 'paused':
        return Colors.orange;
    }
    return Colors.grey;
  }

  String _durationLabel(String? duration) {
    switch (duration) {
      case 'monthly':
        return 'شهري';
      case 'quarterly':
        return 'ربع سنوي';
      case 'annual':
        return 'سنوي';
    }
    return duration ?? '';
  }

  // "متبقي 12 يوم" while live, "انتهى منذ 3 أيام" once it has lapsed. The
  // server sends days_remaining already signed, so the sign carries the sense.
  String _remainingLabel(dynamic daysRemaining, String? status) {
    final days = int.tryParse(daysRemaining?.toString() ?? '');
    if (days == null) return '';
    if (status != 'active') {
      return days < 0 ? 'انتهى منذ ${-days} يوم' : 'غير نشط';
    }
    if (days == 0) return 'ينتهي اليوم';
    return 'متبقي $days يوم';
  }

  Widget _filterChip(String label, String? value) {
    final selected = statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: Colors.redAccent,
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
          side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
        ),
        onSelected: (_) {
          if (statusFilter == value) return;
          setState(() => statusFilter = value);
          _fetchSubscribers();
        },
      ),
    );
  }

  /// Suspend or resume a member. Resuming credits back the days that were
  /// paused, so the server reports how many it gave and that gets shown -
  /// otherwise the owner has no way to know the end date moved.
  Future<void> _setPaused(Map<String, dynamic> sub, bool paused) async {
    setState(() => loading = true);

    final id = sub['subscription_id'];
    final response = await http.put(
      Uri.parse("${apiUrl}clients/setSubscriptionPaused/$id"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer ${widget.token}",
        'x-api-key': '${dotenv.env['API_KEY']}'
      },
      body: json.encode({'paused': paused}),
    );

    final data = json.decode(response.body);

    String message;
    if (response.statusCode == 200) {
      final credited = int.tryParse(data['days_credited']?.toString() ?? '') ?? 0;
      if (paused) {
        message = "تم إيقاف الاشتراك مؤقتاً";
      } else {
        message = credited > 0
            ? "تم استئناف الاشتراك وإضافة $credited يوم"
            : "تم استئناف الاشتراك";
      }
    } else {
      message = data['error'] ?? "فشل تحديث الاشتراك";
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        backgroundColor:
            response.statusCode == 200 ? Colors.green : Colors.redAccent,
        duration: const Duration(seconds: 3),
      ));
    }

    await _fetchSubscribers();
  }

  Widget _detailRow(String label, String? value, {IconData? icon}) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Colors.redAccent),
            const SizedBox(width: 8),
          ],
          Text(
            "$label: ",
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSubscriberDetails(Map<String, dynamic> sub) async {
    final status = sub['status']?.toString();
    final isPaused = status == 'paused';
    // A cancelled membership is finished; there is nothing to suspend.
    final canToggle = status != 'cancelled';

    final name = (sub['full_name']?.toString().trim().isNotEmpty ?? false)
        ? sub['full_name'].toString()
        : (sub['user_full_name']?.toString() ?? 'غير معروف');

    final renewals = int.tryParse(sub['renewals']?.toString() ?? '') ?? 0;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border:
                            Border.all(color: _statusColor(status), width: 0.8),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _statusColor(status),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                _detailRow("رقم الهاتف", sub['phone_number']?.toString(),
                    icon: Icons.phone),
                // The account the subscription was bought from, shown only
                // when it is a different person from the member.
                if (sub['user_full_name'] != null &&
                    sub['user_full_name'].toString() != name)
                  _detailRow("صاحب الحساب", sub['user_full_name']?.toString(),
                      icon: Icons.account_circle_outlined),
                _detailRow("نوع الاشتراك",
                    _durationLabel(sub['duration_type']?.toString()),
                    icon: Icons.card_membership),
                _detailRow("أول اشتراك", sub['first_start_date']?.toString(),
                    icon: Icons.flag_outlined),
                _detailRow("الفترة الحالية",
                    "${sub['start_date'] ?? ''} → ${sub['end_date'] ?? ''}",
                    icon: Icons.calendar_month),
                _detailRow("المتبقي",
                    _remainingLabel(sub['days_remaining'], status),
                    icon: Icons.hourglass_bottom),
                if (renewals > 0)
                  _detailRow("عدد التجديدات", "$renewals",
                      icon: Icons.autorenew),
                _detailRow("آخر دفعة", "${sub['amount_paid'] ?? 0} د.ل",
                    icon: Icons.payments_outlined),
                _detailRow("إجمالي المدفوع", "${sub['total_paid'] ?? 0} د.ل",
                    icon: Icons.account_balance_wallet_outlined),
                if (isPaused)
                  _detailRow("موقوف منذ", sub['paused_at']?.toString(),
                      icon: Icons.pause_circle_outline),
                _detailRow("تاريخ التسجيل", sub['created']?.toString(),
                    icon: Icons.schedule),

                const SizedBox(height: 12),

                if (canToggle) ...[
                  if (!isPaused)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        "عند الإيقاف المؤقت تتم إضافة الأيام الموقوفة إلى نهاية الاشتراك عند الاستئناف.",
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isPaused ? Colors.green : Colors.orange.shade800,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      icon: Icon(
                          isPaused ? Icons.play_arrow : Icons.pause, size: 20),
                      label: Text(
                        isPaused ? "استئناف الاشتراك" : "إيقاف مؤقت",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _setPaused(sub, !isPaused);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriberCard(Map<String, dynamic> sub) {
    final status = sub['status']?.toString();

    // The member details captured at purchase, falling back to the account
    // holder: a parent may subscribe on a child's behalf, so the two are not
    // necessarily the same person.
    final name = (sub['full_name']?.toString().trim().isNotEmpty ?? false)
        ? sub['full_name'].toString()
        : (sub['user_full_name']?.toString() ?? 'غير معروف');
    final phone = (sub['phone_number']?.toString().trim().isNotEmpty ?? false)
        ? sub['phone_number'].toString()
        : (sub['user_phone_number']?.toString() ?? '');

    return GestureDetector(
      onTap: () => _showSubscriberDetails(sub),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _statusColor(status), width: 0.8),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _statusColor(status),
                  ),
                ),
              ),
            ],
          ),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.phone, size: 15, color: Colors.redAccent),
                const SizedBox(width: 4),
                Text(phone,
                    style: const TextStyle(fontSize: 13, color: Colors.black54)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_month,
                  size: 15, color: Colors.redAccent),
              const SizedBox(width: 4),
              Text(
                "${sub['start_date'] ?? ''} → ${sub['end_date'] ?? ''}",
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip(_durationLabel(sub['duration_type']?.toString())),
              _chip("${sub['amount_paid'] ?? 0} د.ل"),
              if (_remainingLabel(sub['days_remaining'], status).isNotEmpty)
                _chip(_remainingLabel(sub['days_remaining'], status)),
              // Renewals are worth surfacing on the card: a returning member
              // is different from a new one at a glance.
              if ((int.tryParse(sub['renewals']?.toString() ?? '') ?? 0) > 0)
                _chip("جدد ${sub['renewals']} مرة"),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Colors.black87),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final planName = widget.plan['name']?.toString() ?? 'الصالة';
    final maxSeats = int.tryParse(widget.plan['max_seats']?.toString() ?? '');

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.red.shade50,
        appBar: AppBar(
          title: Text(planName, style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: loading ? null : _fetchSubscribers,
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    maxSeats == null
                        ? "$_activeCount مشترك نشط"
                        : "$_activeCount من $maxSeats مشترك نشط",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip("الكل", null),
                        _filterChip("النشطون", "active"),
                        _filterChip("الموقوفة", "paused"),
                        _filterChip("المنتهية", "expired"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Colors.redAccent))
                  : errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 16),
                            ),
                          ),
                        )
                      : subscribers.isEmpty
                          ? const Center(
                              child: Text(
                                "لا يوجد مشتركون",
                                style: TextStyle(color: Colors.black54),
                              ),
                            )
                          : RefreshIndicator(
                              color: Colors.redAccent,
                              onRefresh: _fetchSubscribers,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: subscribers.length,
                                itemBuilder: (context, i) =>
                                    _buildSubscriberCard(
                                        subscribers[i] as Map<String, dynamic>),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
