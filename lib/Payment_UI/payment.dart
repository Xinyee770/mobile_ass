import 'package:flutter/material.dart';
import '../services/payment_service.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io'; // Needed for File
import 'package:path_provider/path_provider.dart'; // Needed for folder access
import 'package:share_plus/share_plus.dart'; // Needed for the share menu

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

  Future<void> _handlePayment(BuildContext context, double amount, Map<String, dynamic> data) async {
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

      _showAdvancedSuccess(context, amount, data);

    } catch (e) {
      // If the code above still fails, it's likely a platform setup error
      _showSnack(context, "Security Error: $e", isError: true);
    }
  }

  void _showAdvancedSuccess(BuildContext context, double amount, Map<String, dynamic> data) {
    // 1. Capture the "Main Screen" Navigator before entering the dialog builder
    final mainNavigator = Navigator.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog( // Note: changed name to dialogContext to avoid confusion
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified, color: Colors.blueAccent, size: 90),
              const SizedBox(height: 20),
              const Text("Transaction Secured",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("RM ${amount.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 28, color: Colors.blueAccent, fontWeight: FontWeight.w900)),
              const SizedBox(height: 15),
              const Divider(),
              const SizedBox(height: 15),
              _buildInfoRow("Auth Method", "Biometric ID"),
              _buildInfoRow("Status", "Success"),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  // 2. Close the Dialog using the dialog's context
                  Navigator.of(dialogContext).pop();

                  // 3. Use the mainNavigator we saved earlier to go back to Home
                  mainNavigator.popUntil((route) => route.isFirst);
                },
                child: const Text("Return to Dashboard"),
              ),
              const SizedBox(height: 12),
              // Inside your _showAdvancedSuccess function
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () => shareReceipt(data, amount, _selectedMethod),
                icon: const Icon(Icons.share), // Changed icon to share
                label: const Text("Share / Save Receipt"), // Changed label
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> shareReceipt(Map<String, dynamic> data, double amount, String method) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(level: 0, child: pw.Text("OFFICIAL RECEIPT")),
                pw.SizedBox(height: 20),
                pw.Text("Transaction ID: TXN-${DateTime.now().millisecondsSinceEpoch}"),
                pw.Text("Date: ${DateTime.now().toString()}"),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Text("Course: ${data['courses']['course_name']}"),
                pw.Text("Booking ID: #${data['id']}"),
                pw.Text("Location: ${data['location']}"),
                pw.Text("Payment Method: $method"),
                pw.SizedBox(height: 20),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text("Total Paid: RM ${amount.toStringAsFixed(2)}",
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20)),
                ),
                pw.SizedBox(height: 40),
                pw.Center(child: pw.Text("Thank you for your booking!")),
              ],
            );
          },
        ),
      );

      // 1. Get a temporary directory to save the file
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/Receipt_${data['id']}.pdf");

      // 2. Write the PDF to that file
      await file.writeAsBytes(await pdf.save());

      // 3. Open the Share Sheet
      await Share.shareXFiles([XFile(file.path)], text: 'My Booking Receipt');

    } catch (e) {
      debugPrint("Error sharing PDF: $e");
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
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
                    onPressed: () => _handlePayment(context, price,data),
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