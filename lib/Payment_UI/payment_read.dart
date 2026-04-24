import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../services/payment_service.dart';
import '../utils/ui_helpers.dart';
import 'payment.dart';
import 'package:local_auth/local_auth.dart';

class PaymentHistoryPage extends StatefulWidget {
  const PaymentHistoryPage({super.key});

  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  final PaymentService _service = PaymentService();
  late ConfettiController _confettiController;
  final LocalAuthentication auth = LocalAuthentication();

  // --- Filter & Sort States ---
  String _sortBy = 'Date (Newest)';
  String _filterStatus = 'All';
  String _filterBookingStatus = 'All';

  // --- Theme Colors ---
  final Color bgDark = const Color(0xFF0F111A);
  final Color surfaceDark = const Color(0xFF1A1D29);
  final Color primaryPurple = const Color(0xFF9D59FF);
  final Color textMuted = const Color(0xFF9496A1);

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  // --- 1. MAIN BUILDER ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: const Text("Transaction History", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: bgDark,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _service.getPaymentHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return _loading();
          if (snapshot.hasError) return _error(snapshot.error.toString());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return _buildEmptyState();

          final List<Map<String, dynamic>> filteredData = _processData(snapshot.data!);

          return Column(
            children: [
              _buildTopControls(), // The new Sort and Filter row
              Expanded(
                child: filteredData.isEmpty
                    ? const Center(child: Text("No transactions match this filter", style: TextStyle(color: Colors.white)))
                    : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredData.length,
                  itemBuilder: (context, index) => _buildTransactionCard(filteredData[index]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- 2. NEW TOP CONTROLS (Sort & Filter Button) ---
  Widget _buildTopControls() {
    bool hasActiveFilters = _filterStatus != 'All' || _filterBookingStatus != 'All';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceDark.withOpacity(0.5),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left Side: Sort Dropdown
          Row(
            children: [
              Icon(Icons.swap_vert_rounded, size: 18, color: primaryPurple),
              const SizedBox(width: 4),
              DropdownButton<String>(
                value: _sortBy,
                dropdownColor: surfaceDark,
                underline: const SizedBox(),
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                items: ['Date (Newest)', 'Date (Oldest)', 'Amount (High)', 'Amount (Low)']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (value) => setState(() => _sortBy = value!),
              ),
            ],
          ),
          // Right Side: Filter Button
          TextButton.icon(
            onPressed: _showFilterSheet,
            icon: Icon(Icons.tune_rounded, size: 18, color: hasActiveFilters ? primaryPurple : Colors.white),
            label: Text(
              "Filter${hasActiveFilters ? " (Active)" : ""}",
              style: TextStyle(color: hasActiveFilters ? primaryPurple : Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. FILTER BOTTOM SHEET ---
  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: surfaceDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pull Handle
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Filter", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  // RESET BUTTON - Stays at the top for easy access
                  TextButton.icon(
                    onPressed: () {
                      setModalState(() {
                        _filterStatus = 'All';
                        _filterBookingStatus = 'All';
                      });
                      setState(() {}); // Updates the list in real-time
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.redAccent),
                    label: const Text("Reset All", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),

              const Divider(height: 20, color: Colors.white10),

              _filterLabel("PAYMENT STATUS"),
              const SizedBox(height: 8),
              _buildModalFilterRow(
                options: ["All", "Success", "Pending", "Refunded"],
                currentValue: _filterStatus,
                onSelected: (val) {
                  setModalState(() => _filterStatus = val);
                  setState(() {});
                },
              ),

              const SizedBox(height: 25),

              _filterLabel("BOOKING STATUS"),
              const SizedBox(height: 8),
              _buildModalFilterRow(
                options: ["All", "Confirmed", "Cancelled", "Attended"],
                currentValue: _filterBookingStatus,
                onSelected: (val) {
                  setModalState(() => _filterBookingStatus = val);
                  setState(() {});
                },
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalFilterRow({required List<String> options, required String currentValue, required Function(String) onSelected}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        bool isSelected = currentValue == option;
        return ChoiceChip(
          label: Text(option),
          selected: isSelected,
          onSelected: (val) => onSelected(option),
          selectedColor: primaryPurple.withOpacity(0.2),
          backgroundColor: bgDark,
          labelStyle: TextStyle(color: isSelected ? primaryPurple : textMuted, fontSize: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isSelected ? primaryPurple : Colors.white10)),
        );
      }).toList(),
    );
  }

  // --- 4. DATA LOGIC ---
  List<Map<String, dynamic>> _processData(List<Map<String, dynamic>> data) {
    var list = data.where((item) {
      bool payMatch = _filterStatus == 'All' || item['status'].toString().toLowerCase() == _filterStatus.toLowerCase();
      bool bookMatch = _filterBookingStatus == 'All' || (item['booking']['booking_status'] ?? '').toString().toLowerCase() == _filterBookingStatus.toLowerCase();
      return payMatch && bookMatch;
    }).toList();

    if (_sortBy == 'Amount (High)') {
      list.sort((a, b) => (b['amount'] as num).compareTo(a['amount'] as num));
    } else if (_sortBy == 'Amount (Low)') {
      list.sort((a, b) => (a['amount'] as num).compareTo(b['amount'] as num));
    } else if (_sortBy == 'Date (Oldest)') {
      list.sort((a, b) => (a['payment_id'] as num).compareTo(b['payment_id'] as num));
    } else {
      list.sort((a, b) => (b['payment_id'] as num).compareTo(a['payment_id'] as num));
    }
    return list;
  }

  // --- UI COMPONENTS (BADGES, CARDS, METADATA) ---
  Widget _loading() => Center(child: CircularProgressIndicator(color: primaryPurple));
  Widget _error(String err) => Center(child: Text("Error: $err", style: const TextStyle(color: Colors.white)));
  Widget _filterLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)));

  Widget _buildStatusBadge(String label, String status, {bool isBooking = false}) {
    Color color = primaryPurple;
    final s = status.toLowerCase();
    if (s == 'pending' || s == 'waiting') color = Colors.orangeAccent;
    else if (s == 'refunded' || s == 'cancelled') color = Colors.redAccent;
    else if (s == 'success' || s == 'confirmed') color = Colors.greenAccent;
    else if (s == 'processing') color = Colors.cyanAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.2), width: 1)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("$label: ", style: TextStyle(color: color.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.w900)),
          Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> item) {
    final status = item['status'].toString().toLowerCase();
    final booking = item['booking'];
    final bStatus = booking['booking_status'] ?? 'Confirmed';

    return GestureDetector(
      onTap: () => _showReceiptDetail(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: surfaceDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Wrap(spacing: 6, children: [_buildStatusBadge("PAY", status), _buildStatusBadge("BKG", bStatus, isBooking: true)]),
                  Text("#${item['booking_id']}", style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Text(booking['courses']['course_name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              _buildCardMetadata(booking),
              const Divider(height: 32, color: Colors.white10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("RM ${item['amount'].toStringAsFixed(2)}", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: primaryPurple)),
                  if (status == 'pending')
                    ElevatedButton(
                      onPressed: () => _continueToPayment(item['booking_id']),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text("Pay Now"),
                    )
                  else
                    Icon(Icons.arrow_forward_ios, size: 14, color: textMuted)
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardMetadata(Map<String, dynamic> booking) {
    return Row(
      children: [
        Icon(Icons.calendar_today, size: 14, color: textMuted),
        const SizedBox(width: 5),
        Text(booking['booking_date'] ?? "N/A", style: TextStyle(color: textMuted, fontSize: 13)),
        const SizedBox(width: 15),
        Icon(Icons.location_on_outlined, size: 14, color: textMuted),
        const SizedBox(width: 5),
        Text(booking['location'] ?? "Main Studio", style: TextStyle(color: textMuted, fontSize: 13)),
      ],
    );
  }

  // --- 5. SHEETS, DIALOGS, AUTH & REFUND (PRESERVED) ---
  void _showReceiptDetail(Map<String, dynamic> item) {
    final status = item['status'].toString().toLowerCase();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(color: surfaceDark, borderRadius: const BorderRadius.vertical(top: Radius.circular(25))),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            const Text("Transaction Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const Divider(height: 30, color: Colors.white10),
            _buildDetailRow("Course", item['booking']['courses']['course_name']),
            _buildDetailRow("Booking ID", "#${item['booking_id']}"),
            _buildDetailRow("Date", item['booking']['booking_date'] ?? "N/A"),
            _buildDetailRow("Status", status.toUpperCase(), valueColor: status == 'refunded' ? Colors.redAccent : primaryPurple),
            const Divider(height: 30, color: Colors.white10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total Paid", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text("RM ${item['amount'].toStringAsFixed(2)}", style: TextStyle(color: primaryPurple, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 30),
            _buildReceiptActions(item, status),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptActions(Map<String, dynamic> item, String status) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity, height: 55,
          child: ElevatedButton.icon(
            onPressed: () => _service.shareReceipt(item),
            icon: const Icon(Icons.share),
            label: const Text("Export Receipt as PDF"),
            style: ElevatedButton.styleFrom(backgroundColor: primaryPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
          ),
        ),
        if (status == 'success') ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () { Navigator.pop(context); _handleRefund(item); },
            child: const Text("Request Refund", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }

  void _handleRefund(Map<String, dynamic> item) {
    if (item['booking']['booking_status'] != 'Cancelled') {
      _showWarning("Cancel Booking First", "Please cancel your slot in 'My Bookings' before requesting a refund.");
    } else {
      _showRefundReasonSheet(item);
    }
  }

  Future<bool> _authenticateRefund() async {
    try {
      bool canCheck = await auth.canCheckBiometrics;
      bool isSupported = await auth.isDeviceSupported();
      if (canCheck || isSupported) {
        return await auth.authenticate(localizedReason: 'Please authenticate to request this refund', biometricOnly: false, persistAcrossBackgrounding: true);
      }
      return true;
    } catch (e) {
      debugPrint("Security Error: $e");
      return false;
    }
  }

  void _showRefundReasonSheet(Map<String, dynamic> item) {
    String selectedReason = 'Schedule Conflict';
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: BoxDecoration(color: surfaceDark, borderRadius: const BorderRadius.vertical(top: Radius.circular(25))),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),
                  const Text("Refund Request", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("Why are you requesting a refund for #${item['booking_id']}?", style: TextStyle(color: textMuted, fontSize: 14)),
                  const SizedBox(height: 10),
                  ...['Schedule Conflict', 'Accidental Booking', 'Health Issues', 'Others'].map((reason) =>
                      RadioListTile<String>(
                        title: Text(reason, style: const TextStyle(color: Colors.white, fontSize: 15)),
                        value: reason,
                        groupValue: selectedReason,
                        activeColor: primaryPurple,
                        onChanged: (val) => setModalState(() => selectedReason = val!),
                        contentPadding: EdgeInsets.zero,
                      ),
                  ).toList(),
                  const SizedBox(height: 10),
                  _buildDarkTextField("Comments", "Tell us more...", Icons.chat_bubble_outline),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      onPressed: () async {
                        Navigator.pop(context);
                        bool didAuth = await _authenticateRefund();
                        if (didAuth) { _submitRefund(item['payment_id'], selectedReason); }
                        else { UIHelpers.showSnack(context, "Authorization failed. Refund canceled.", isError: true); }
                      },
                      child: const Text("Submit Request", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submitRefund(int paymentId, String reason) async {
    UIHelpers.showSnack(context, "Submitting to Audit Team...", isError: false);
    try {
      await _service.refundPayment(paymentId, reason);
      await Future.delayed(const Duration(seconds: 2));
      _confettiController.play();
      _showRefundSuccessDialog();
      setState(() {});
    } catch (e) { UIHelpers.showSnack(context, "Refund failed: $e", isError: true); }
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: textMuted)),
          Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildDarkTextField(String label, String hint, IconData icon) {
    return TextField(
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label, labelStyle: TextStyle(color: textMuted), hintText: hint, hintStyle: const TextStyle(color: Colors.white10),
        prefixIcon: Icon(icon, color: primaryPurple, size: 20), filled: true, fillColor: bgDark,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryPurple)),
      ),
    );
  }

  void _showRefundSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => Stack(
        alignment: Alignment.topCenter,
        children: [
          AlertDialog(
            backgroundColor: surfaceDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Column(children: [
              Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 60),
              SizedBox(height: 10),
              Text("Refund Successful", style: TextStyle(color: Colors.white)),
            ]),
            content: Text("Expect funds in 3-5 working days.", textAlign: TextAlign.center, style: TextStyle(color: textMuted)),
            actions: [Center(child: TextButton(onPressed: () => Navigator.pop(context), child: Text("Done", style: TextStyle(color: primaryPurple, fontWeight: FontWeight.bold))))],
          ),
          ConfettiWidget(confettiController: _confettiController, blastDirectionality: BlastDirectionality.explosive, colors: [Colors.greenAccent, primaryPurple, Colors.white]),
        ],
      ),
    );
  }

  void _showWarning(String title, String msg) {
    showDialog(context: context, builder: (c) => AlertDialog(
      backgroundColor: surfaceDark, title: Text(title, style: const TextStyle(color: Colors.white)),
      content: Text(msg, style: TextStyle(color: textMuted)),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text("OK", style: TextStyle(color: primaryPurple)))],
    ),
    );
  }

  void _continueToPayment(int bookingId) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => Payment(bookingId: bookingId))).then((_) => setState(() {}));
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.receipt_long_outlined, size: 80, color: Colors.white10),
      const SizedBox(height: 16),
      Text("No transactions found", style: TextStyle(color: textMuted, fontSize: 18)),
    ]));
  }
}