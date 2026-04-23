import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../services/payment_service.dart';
import '../utils/ui_helpers.dart';
import 'package:local_auth/local_auth.dart';

class Payment extends StatefulWidget {
  final int bookingId;
  const Payment({super.key, required this.bookingId});

  @override
  State<Payment> createState() => _PaymentState();
}

class _PaymentState extends State<Payment> {
  final PaymentService _service = PaymentService();
  final LocalAuthentication auth = LocalAuthentication();
  late ConfettiController _confettiController;

  int? _pendingPaymentId;
  String _selectedMethod = 'Credit Card';

  // --- Fintech Dark Theme Colors ---
  final Color bgDark = const Color(0xFF0F111A);     // Deep Navy Background
  final Color surfaceDark = const Color(0xFF1A1D29); // Card Surface
  final Color primaryPurple = const Color(0xFF9D59FF); // Brand Purple
  final Color textMuted = const Color(0xFF9496A1);    // Muted Grey Text

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

  // --- PAYMENT LOGIC ---

  Future<void> _handlePayment(BuildContext context, double amount, Map<String, dynamic> data) async {
    try {
      bool canCheck = await auth.canCheckBiometrics;
      bool isSupported = await auth.isDeviceSupported();

      if (canCheck || isSupported) {
        bool didAuthenticate = await auth.authenticate(
          localizedReason: 'Please authenticate to complete your payment',
          biometricOnly: false,
          persistAcrossBackgrounding: true,
        );
        if (!didAuthenticate) return;
      }

      await _service.completePayment(
        paymentId: _pendingPaymentId!,
        bookingId: widget.bookingId,
        method: _selectedMethod,
      );

      final receiptData = Map<String, dynamic>.from(data);
      receiptData['payment_id'] = _pendingPaymentId;
      receiptData['payment_method'] = _selectedMethod;
      receiptData['amount'] = amount;

      _confettiController.play();
      _showAdvancedSuccess(context, amount, receiptData);

    } catch (e) {
      UIHelpers.showSnack(context, "Security Error: $e", isError: true);
    }
  }

  // --- SUCCESS UI ---

  void _showAdvancedSuccess(BuildContext context, double amount, Map<String, dynamic> receiptData) {
    final mainNavigator = Navigator.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Stack(
        alignment: Alignment.topCenter,
        children: [
          Dialog(
            backgroundColor: surfaceDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, color: Colors.green, size: 90),
                  const SizedBox(height: 20),
                  const Text("Transaction Secured",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text("RM ${amount.toStringAsFixed(2)}",
                      style: TextStyle(fontSize: 28, color: primaryPurple, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 15),
                  Divider(color: Colors.white10),
                  _buildDetailRow("Auth Method", "Biometric ID"),
                  _buildDetailRow("Status", "Success"),
                  const SizedBox(height: 30),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryPurple,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      mainNavigator.popUntil((route) => route.isFirst);
                    },
                    child: const Text("Return to Dashboard"),
                  ),
                  const SizedBox(height: 12),

                  TextButton.icon(
                    onPressed: () => _service.shareReceipt(receiptData),
                    icon: Icon(Icons.share, color: primaryPurple, size: 18),
                    label: Text("Export PDF Receipt", style: TextStyle(color: primaryPurple)),
                  ),
                ],
              ),
            ),
          ),
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: [primaryPurple, Colors.white, Colors.deepPurpleAccent],
            numberOfParticles: 20,
            gravity: 0.1,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: const Text("Checkout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: bgDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _service.getBookingDetails(widget.bookingId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryPurple));
          }
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.white)));

          final data = snapshot.data!;
          final price = (data['courses']['course_price'] as num).toDouble();

          if (_pendingPaymentId == null) {
            _service.createPendingPayment(bookingId: widget.bookingId, amount: price).then((id) {
              if (mounted && _pendingPaymentId == null) {
                setState(() => _pendingPaymentId = id);
              }
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Order Summary", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: surfaceDark,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryHeader(data['courses']['course_name'], price),
                      Divider(height: 30, color: Colors.white10),
                      _buildDetailRow("Booking ID", "#${widget.bookingId}"),
                      _buildDetailRow("Location", data['location'] ?? "Main Studio"),
                      _buildDetailRow("Date", data['booking_date'] ?? "TBD"),
                      _buildDetailRow("Time", "${UIHelpers.formatTime(data['start_time'])} - ${UIHelpers.formatTime(data['end_time'])}"),
                      Divider(height: 30, color: Colors.white10),
                      _buildDetailRow("Total Pay", "RM ${price.toStringAsFixed(2)}", isTotal: true),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                const Text("Payment Method", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 15),
                _buildMethodTile(Icons.credit_card, "Credit Card"),
                _buildMethodTile(Icons.account_balance_wallet, "GrabPay"),
                _buildMethodTile(Icons.qr_code_scanner, "TNG eWallet"),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryPurple,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: () => _handlePayment(context, price, data),
                    child: const Text("Pay Now", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- DARK MODE HELPERS ---

  Widget _buildMethodTile(IconData icon, String method) {
    bool isSelected = _selectedMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = method),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? primaryPurple.withOpacity(0.1) : surfaceDark,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
              color: isSelected ? primaryPurple : Colors.white10,
              width: isSelected ? 2 : 1
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? primaryPurple : textMuted),
            const SizedBox(width: 15),
            Text(method, style: const TextStyle(fontSize: 16, color: Colors.white)),
            const Spacer(),
            if (isSelected) Icon(Icons.check_circle, color: primaryPurple),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: textMuted, fontSize: 14)),
          Text(value, style: TextStyle(
            color: isTotal ? primaryPurple : Colors.white,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 18 : 14,
          )),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(String name, double price) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        Text("RM ${price.toStringAsFixed(2)}", style: TextStyle(fontSize: 18, color: primaryPurple, fontWeight: FontWeight.bold)),
      ],
    );
  }
}