import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../services/payment_service.dart';
import '../utils/ui_helpers.dart';
import 'payment.dart';

class PaymentHistoryPage extends StatefulWidget {
  const PaymentHistoryPage({super.key});

  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  final PaymentService _service = PaymentService();
  late ConfettiController _confettiController;

  String _sortBy = 'Date (Newest)';
  String _filterStatus = 'All';

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
              _buildFilterSection(),
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

  // --- 2. DATA LOGIC ---
  List<Map<String, dynamic>> _processData(List<Map<String, dynamic>> data) {
    var list = data.where((item) {
      if (_filterStatus == 'All') return true;
      return item['status'].toString().toLowerCase() == _filterStatus.toLowerCase();
    }).toList();

    if (_sortBy == 'Amount (High)') {
      list.sort((a, b) => (b['amount'] as num).compareTo(a['amount'] as num));
    } else if (_sortBy == 'Amount (Low)') {
      list.sort((a, b) => (a['amount'] as num).compareTo(b['amount'] as num));
    } else if (_sortBy == 'Date (Oldest)') {
      // Sort by ID ascending (smallest ID first = oldest)
      list.sort((a, b) => (a['payment_id'] as num).compareTo(b['payment_id'] as num));
    } else {
      // Default: Date (Newest) - Largest ID first
      list.sort((a, b) => (b['payment_id'] as num).compareTo(a['payment_id'] as num));
    }
    return list;
  }

  // --- 3. UI COMPONENTS ---
  Widget _loading() => Center(child: CircularProgressIndicator(color: primaryPurple));
  Widget _error(String err) => Center(child: Text("Error: $err", style: const TextStyle(color: Colors.white)));

  Widget _buildStatusBadge(String status, {bool isBooking = false}) {
    Color color = primaryPurple;
    final s = status.toLowerCase();
    if (s == 'pending') color = Colors.orangeAccent;
    else if (s == 'refunded' || s == 'cancelled') color = Colors.redAccent;
    else if (s == 'success') color = Colors.greenAccent;
    else if (isBooking) color = Colors.cyanAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: isBooking ? 9 : 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> item) {
    final status = item['status'].toString().toLowerCase();
    final booking = item['booking'];

    return GestureDetector(
      onTap: () => _showReceiptDetail(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: surfaceDark, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    _buildStatusBadge(status),
                    const SizedBox(width: 8),
                    _buildStatusBadge(booking['booking_status'] ?? 'Confirmed', isBooking: true),
                  ]),
                  Text("#${item['booking_id']}", style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
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

  // --- 4. SHEETS & DIALOGS ---
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

  // --- 5. REFUND PROCESS ---
  void _showRefundReasonSheet(Map<String, dynamic> item) {
    String selectedReason = 'Schedule Conflict';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: BoxDecoration(
              color: surfaceDark,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(25))
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            // --- WRAP STARTS HERE ---
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
                  const SizedBox(height: 10), // Reduced spacing slightly to help mobile fit

                  ...['Schedule Conflict', 'Accidental Booking', 'Health Issues', 'Others'].map((reason) =>
                      RadioListTile<String>(
                        title: Text(reason, style: const TextStyle(color: Colors.white, fontSize: 15)),
                        value: reason,
                        groupValue: selectedReason,
                        activeColor: primaryPurple,
                        onChanged: (val) => setModalState(() => selectedReason = val!),
                        contentPadding: EdgeInsets.zero, // Helps save space
                      ),
                  ).toList(),

                  const SizedBox(height: 10),
                  _buildDarkTextField("Comments", "Tell us more...", Icons.chat_bubble_outline),
                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.withOpacity(0.8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _submitRefund(item['payment_id'], selectedReason);
                      },
                      child: const Text("Submit Request", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            // --- WRAP ENDS HERE ---
          ),
        ),
      ),
    );
  }

// inside _PaymentHistoryPageState
  void _submitRefund(int paymentId, String reason) async {
    // 1. Show UI feedback
    UIHelpers.showSnack(context, "Submitting to Audit Team...", isError: false);

    try {
      // 2. Pass BOTH the ID and the Reason to the service
      await _service.refundPayment(paymentId, reason);

      // 3. Simulate process delay for "Premium" feel
      await Future.delayed(const Duration(seconds: 2));

      // 4. Success UI
      _confettiController.play();
      _showRefundSuccessDialog();

      // 5. Refresh the list
      setState(() {});
    } catch (e) {
      UIHelpers.showSnack(context, "Refund failed: $e", isError: true);
    }
  }

  // --- 6. UTILITIES ---
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
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: surfaceDark, title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(msg, style: TextStyle(color: textMuted)),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text("OK", style: TextStyle(color: primaryPurple)))],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: ["All", "Success", "Pending", "Refunded"].map((s) => _buildFilterChip(s)).toList()),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Icon(Icons.sort, size: 18, color: textMuted), const SizedBox(width: 8),
            Text("Sort by:", style: TextStyle(color: textMuted, fontSize: 13)), const SizedBox(width: 10),
            DropdownButton<String>(
              value: _sortBy, dropdownColor: surfaceDark, underline: const SizedBox(),
              style: TextStyle(color: primaryPurple, fontWeight: FontWeight.bold, fontSize: 13),
              // Inside _buildFilterSection -> DropdownButton
              items: ['Date (Newest)', 'Date (Oldest)', 'Amount (High)', 'Amount (Low)']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (value) => setState(() => _sortBy = value!),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String status) {
    bool isSelected = _filterStatus == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(status), selected: isSelected, onSelected: (val) => setState(() => _filterStatus = status),
        selectedColor: primaryPurple.withOpacity(0.2), backgroundColor: Colors.transparent,
        labelStyle: TextStyle(color: isSelected ? primaryPurple : textMuted, fontSize: 13),
        shape: StadiumBorder(side: BorderSide(color: isSelected ? primaryPurple : Colors.white10)),
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