import 'package:flutter/material.dart';
import '../services/wallet_service.dart';
import 'add_payment_method.dart';
import 'package:confetti/confetti.dart';

class WalletTopUp extends StatefulWidget {
  const WalletTopUp({super.key});

  @override
  State<WalletTopUp> createState() => _WalletTopUpState();
}

class _WalletTopUpState extends State<WalletTopUp> {
  final WalletService _walletService = WalletService();
  final TextEditingController _amountController = TextEditingController();
  final PageController _cardController = PageController(viewportFraction: 0.85);
  late ConfettiController _confettiController;

  final List<double> _amounts = [10.0, 50.0, 100.0, 200.0];

  List<Map<String, dynamic>> _savedMethods = [];
  Map<String, dynamic>? _selectedMethod;
  bool _isLoadingMethods = true;
  bool _isProcessing = false;
  double walletBalance = 0.00;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _loadBalance();
    _fetchSavedMethods();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _amountController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    final balance = await _walletService.getBalance();
    if (mounted) setState(() => walletBalance = balance);
  }

  Future<void> _fetchSavedMethods() async {
    final methods = await _walletService.getSavedPaymentMethods();
    if (mounted) {
      setState(() {
        _savedMethods = methods;
        _isLoadingMethods = false;
        if (methods.isNotEmpty) _selectedMethod = methods[0];
      });
    }
  }

  void _onAmountSelected(double amount) {
    setState(() {
      _amountController.text = amount.toStringAsFixed(2);
      FocusScope.of(context).unfocus();
    });
  }

  // --- SUCCESS DIALOG WITH CELEBRATION ---
  void _showSuccessDialog(double amount) {
    _confettiController.play();

    // Define the colors to match your Payment page
    const Color surfaceDark = Color(0xFF1A1D29);
    const Color primaryPurple = Color(0xFF9D59FF);
    const Color textMuted = Color(0xFF9496A1);

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
                  // Matching the "Verified" look from Payment page
                  const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 90),
                  const SizedBox(height: 20),
                  const Text(
                    "Top Up Successful",
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        decoration: TextDecoration.none // Fix for Dialog text style
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "RM ${amount.toStringAsFixed(2)}",
                    style: const TextStyle(
                        fontSize: 28,
                        color: primaryPurple,
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.none
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Divider(color: Colors.white10),

                  // Detail rows matching the Payment page style
                  _buildPopupDetailRow("Status", "Completed", textMuted),
                  _buildPopupDetailRow("Availability", "Instant", textMuted),

                  const SizedBox(height: 30),

                  // Primary Button matching Payment style
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryPurple,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      _confettiController.stop();
                      Navigator.of(dialogContext).pop(); // Close Dialog
                      Navigator.of(context).pop(true);   // Go back to Dashboard
                    },
                    child: const Text(
                        "AWESOME",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Confetti Widget matching Payment page settings
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [primaryPurple, Colors.white, Colors.deepPurpleAccent],
            numberOfParticles: 20,
            gravity: 0.1,
          ),
        ],
      ),
    );
  }

// Helper widget for the detail rows in the popup
  Widget _buildPopupDetailRow(String label, String value, Color mutedColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: mutedColor, fontSize: 14, decoration: TextDecoration.none)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
        ],
      ),
    );
  }

  void _handleTopUp() async {
    // Capture the current selection into a local variable
    final method = _selectedMethod;

    // 1. Safe Guard: Check if a method is actually selected
    if (method == null || method['id'] == null) {
      _showErrorSnackBar("Please select a saved card first.");
      return;
    }

    String input = _amountController.text.trim();
    if (input.isEmpty) {
      _showErrorSnackBar("Enter an amount");
      return;
    }

    double finalAmount = double.tryParse(input) ?? 0.0;
    if (finalAmount < 5.0) {
      _showErrorSnackBar("Minimum top-up is RM 5.00.");
      return;
    }

    setState(() => _isProcessing = true);

    try {
      String refId = "PAY-${DateTime.now().millisecondsSinceEpoch}";

      // Use the safe local variable 'method' instead of '_selectedMethod!'
      int paymentMethodId = method['id'];

      bool success = await _walletService.topUpWallet(finalAmount, refId, paymentMethodId);

      if (success) {
        if (!mounted) return;
        _showSuccessDialog(finalAmount);
        _loadBalance();
      } else {
        _showErrorSnackBar("Transaction rejected by server.");
      }
    } catch (e) {
      // If the error was a null check operator inside WalletService, this will catch it
      _showErrorSnackBar("Error: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade800, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    const Color scaffoldBg = Color(0xFF101018);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text("Top Up Wallet", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: scaffoldBg,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 24, top: 10),
              child: Text("SELECT SOURCE", style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1.2)),
            ),
            const SizedBox(height: 10),
            _buildCardCarousel(theme),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Balance: RM ${walletBalance.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white54)),
                  const SizedBox(height: 30),
                  const Text("Top Up Amount", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  _buildAmountField(theme),
                  const SizedBox(height: 25),
                  _buildQuickSelectGrid(theme),
                  const SizedBox(height: 40),
                  _buildTopUpButton(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- REMAINING UI BUILDERS ---
  Widget _buildCardCarousel(ColorScheme theme) {
    if (_isLoadingMethods) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    return SizedBox(
      height: 220,
      child: PageView.builder(
        controller: _cardController,
        itemCount: _savedMethods.length + 1,
        onPageChanged: (index) {
          setState(() => _selectedMethod = (index < _savedMethods.length) ? _savedMethods[index] : null);
        },
        itemBuilder: (context, index) {
          if (index < _savedMethods.length) return _buildCreditCardUI(theme, _savedMethods[index]);
          return _buildAddNewCardUI(theme);
        },
      ),
    );
  }

  Widget _buildCreditCardUI(ColorScheme theme, Map<String, dynamic> method) {
    bool isTNG = method['method_type'] == 'TNG';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isTNG ? [const Color(0xFF0052CC), const Color(0xFF2684FF)] : [theme.primary, theme.primary.withOpacity(0.7)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(method['method_type'].toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white70),
                onPressed: () => _showCardOptions(method),
              ),
            ],
          ),
          const Spacer(),
          Text(method['identifier'], style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(method['nickname'] ?? "PRIMARY CARD", style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text(method['expiry_date'] ?? "", style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildAddNewCardUI(ColorScheme theme) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddPaymentMethodPage())).then((_) => _fetchSavedMethods()),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.white10)),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: Colors.white24, size: 40),
            SizedBox(height: 10),
            Text("Link New Card", style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField(ColorScheme theme) {
    return TextField(
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        prefixText: "RM ",
        prefixStyle: TextStyle(color: theme.primary, fontSize: 24),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildQuickSelectGrid(ColorScheme theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _amounts.map((amt) => Expanded(
        child: InkWell(
          onTap: () => _onAmountSelected(amt),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
            child: Center(child: Text("RM ${amt.toInt()}", style: const TextStyle(color: Colors.white70))),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildTopUpButton(ColorScheme theme) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: theme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        onPressed: (_isProcessing || _selectedMethod == null) ? null : _handleTopUp,
        child: _isProcessing
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text("Confirm Top Up", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showCardOptions(Map<String, dynamic> method) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.white),
            title: const Text("Edit Nickname / Expiry", style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => AddPaymentMethodPage(existingMethod: method))).then((_) => _fetchSavedMethods());
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.redAccent),
            title: const Text("Remove Card", style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              Navigator.pop(context);
              bool deleted = await _walletService.deletePaymentMethod(method['id']);
              if (deleted) {
                _fetchSavedMethods();
                _showErrorSnackBar("Card removed successfully");
              }
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}