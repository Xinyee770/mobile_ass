import 'package:flutter/material.dart';
import '../services/wallet_service.dart';

class WalletTopUp extends StatefulWidget {
  const WalletTopUp({super.key});

  @override
  State<WalletTopUp> createState() => _WalletTopUpState();
}

class _WalletTopUpState extends State<WalletTopUp> {
  final WalletService _walletService = WalletService();
  final TextEditingController _amountController = TextEditingController();
  final List<double> _amounts = [10.0, 50.0, 100.0, 200.0];

  double? _selectedAmount;
  bool _isProcessing = false;
  double walletBalance = 0.00;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    final balance = await _walletService.getBalance();
    if (mounted) setState(() => walletBalance = balance);
  }

  void _onAmountSelected(double amount) {
    setState(() {
      _selectedAmount = amount;
      _amountController.clear();
      FocusScope.of(context).unfocus(); // Close keyboard when selecting preset
    });
  }

  void _handleTopUp() async {
    String input = _amountController.text.trim();
    double finalAmount = 0.0;

    // 1. Precise Validation Checks
    if (input.isEmpty && _selectedAmount == null) {
      _showErrorSnackBar("Please enter an amount or pick a quick select option.");
      return;
    }

    if (input.isNotEmpty) {
      finalAmount = double.tryParse(input) ?? -1.0;
      if (finalAmount == -1.0) {
        _showErrorSnackBar("Invalid input. Please enter a valid number (e.g. 10.50)");
        return;
      }
    } else {
      finalAmount = _selectedAmount!;
    }

    if (finalAmount < 5.0) {
      _showErrorSnackBar("Minimum top-up is RM 5.00. You entered RM ${finalAmount.toStringAsFixed(2)}");
      return;
    }

    setState(() => _isProcessing = true);

    try {
      bool success = await _walletService.topUpWallet(finalAmount);
      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Successfully added RM ${finalAmount.toStringAsFixed(2)}!"),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showErrorSnackBar("Transaction Error: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // Helper to ensure all errors are RED
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: Colors.red.shade800, // Strict Red for invalid input
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    const Color scaffoldBg = Color(0xFF101018);

    // FIX: Optimized Button Text logic to ensure it's never blank
    String getButtonLabel() {
      if (_isProcessing) return "Processing...";
      if (_amountController.text.isNotEmpty) {
        return "Top Up RM ${_amountController.text}";
      }
      if (_selectedAmount != null) {
        return "Top Up RM ${_selectedAmount!.toStringAsFixed(2)}";
      }
      return "Confirm Top Up"; // Default fallback so button isn't empty
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text("Top Up", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: scaffoldBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBalanceCard(theme),
            const SizedBox(height: 35),

            const Text("Custom Amount", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 20),
              onChanged: (value) => setState(() => _selectedAmount = null),
              decoration: InputDecoration(
                prefixText: "RM ",
                prefixStyle: TextStyle(color: theme.primary, fontWeight: FontWeight.bold, fontSize: 20),
                hintText: "Enter amount (Min RM 5)",
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 16),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.white10)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: theme.primary, width: 2)),
              ),
            ),

            const SizedBox(height: 30),
            const Text("Quick Select", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, childAspectRatio: 2.2, crossAxisSpacing: 16, mainAxisSpacing: 16,
              ),
              itemCount: _amounts.length,
              itemBuilder: (context, index) {
                bool isSelected = _selectedAmount == _amounts[index];
                return InkWell(
                  onTap: () => _onAmountSelected(_amounts[index]),
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? theme.primary.withOpacity(0.15) : Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: isSelected ? theme.primary : Colors.white10, width: isSelected ? 2 : 1),
                    ),
                    child: Text("RM ${_amounts[index].toStringAsFixed(0)}",
                      style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 50),

            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primary,
                  disabledBackgroundColor: theme.primary.withOpacity(0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 8,
                  shadowColor: theme.primary.withOpacity(0.4),
                ),
                onPressed: _isProcessing ? null : _handleTopUp,
                child: _isProcessing
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(getButtonLabel(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(ColorScheme theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.primary, theme.primary.withOpacity(0.6)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: theme.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("TOTAL BALANCE", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text("RM ${walletBalance.toStringAsFixed(2)}",
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("ACTIVE WALLET", style: TextStyle(color: Colors.white38, fontSize: 11)),
              Icon(Icons.nfc, color: Colors.white24),
            ],
          ),
        ],
      ),
    );
  }
}