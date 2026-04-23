import 'package:flutter/material.dart';
import '../services/payment_service.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

class Payment extends StatefulWidget {
  final int bookingId;
  const Payment({super.key, required this.bookingId});

  @override
  State<Payment> createState() => _PaymentState();
}

class _PaymentState extends State<Payment> {
  final PaymentService _service = PaymentService();
  final LocalAuthentication auth = LocalAuthentication();

  // Track selected method
  String _selectedMethod = 'Credit Card';

  Future<void> _handlePayment(BuildContext context, double amount) async {
    try {
      // 1. Basic Check
      bool canCheck = await auth.canCheckBiometrics;
      bool isSupported = await auth.isDeviceSupported();

      if (canCheck || isSupported) {
        // 2. Simple Authentication
        // We pass the settings directly into the function
        bool didAuthenticate = await auth.authenticate(
          localizedReason: 'Please authenticate to complete your payment',
          biometricOnly: false,
          persistAcrossBackgrounding: true, // This is what your version calls 'stickyAuth'
        );
        if (!didAuthenticate) return;
      }

      // 3. Database logic
      await _service.processPayment(
        bookingId: widget.bookingId,
        amount: amount,
        method: _selectedMethod,
      );

      _showSnack(context, "Payment_UI Successful!", isError: false);
      Future.delayed(const Duration(seconds: 2), () => Navigator.pop(context));

    } catch (e) {
      // If the code above still fails, it's likely a platform setup error
      _showSnack(context, "Security Error: $e", isError: true);
    }
  }

  void _showSnack(BuildContext context, String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green),
    );
  }

  String formatTime(String? time) {
    if (time == null) return "N/A";
    return time.length >= 5 ? time.substring(0, 5) : time;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text("Checkout"), centerTitle: true),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _service.getBookingDetails(widget.bookingId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));

          final data = snapshot.data!;
          final price = (data['courses']['course_price'] as num).toDouble();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Order Summary", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),

                // Summary Card
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        _buildSummaryHeader(data['courses']['course_name'], price),
                        const Divider(height: 30),
                        _buildRow("Booking ID", "#${widget.bookingId}"),
                        _buildRow("Location", data['location'] ?? "Main Studio"),
                        _buildRow("Date", data['booking_date'] ?? "TBD"),
                        _buildRow("Time", "${formatTime(data['start_time'])} - ${formatTime(data['end_time'])}"),
                        const Divider(height: 30),
                        _buildTotalRow(price),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 25),
                const Text("Payment_UI Method", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),

                // Selector Buttons
                _buildMethodTile(Icons.credit_card, "Credit Card"),
                _buildMethodTile(Icons.account_balance_wallet, "GrabPay"),
                _buildMethodTile(Icons.qr_code_scanner, "TNG eWallet"),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: () => _handlePayment(context, price),
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

  Widget _buildMethodTile(IconData icon, String method) {
    bool isSelected = _selectedMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = method),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.blueAccent : Colors.grey[300]!, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.blueAccent : Colors.grey),
            const SizedBox(width: 15),
            Text(method, style: const TextStyle(fontSize: 16)),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle, color: Colors.blueAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(String name, double price) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text("RM ${price.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildTotalRow(double price) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Total Pay", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text("RM ${price.toStringAsFixed(2)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      ],
    );
  }
}