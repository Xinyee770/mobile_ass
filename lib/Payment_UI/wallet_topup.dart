import 'package:flutter/material.dart';
import '../services/wallet_service.dart';

class WalletTopUp extends StatefulWidget {
  const WalletTopUp({super.key});

  @override
  State<WalletTopUp> createState() => _WalletTopUpState();
}

class _WalletTopUpState extends State<WalletTopUp> {
  final WalletService _walletService = WalletService();
  final List<double> _amounts = [10.0, 50.0, 100.0, 200.0];
  double _selectedAmount = 50.0;
  bool _isProcessing = false;

  // Variable to store the balance locally
  double walletBalance = 0.00;

  @override
  void initState() {
    super.initState();
    _loadBalance(); // Load the current balance when screen opens
  }

  Future<void> _loadBalance() async {
    final balance = await _walletService.getBalance();
    if (mounted) {
      setState(() => walletBalance = balance);
    }
  }

  void _handleTopUp() async {
    setState(() => _isProcessing = true);

    try {
      bool success = await _walletService.topUpWallet(_selectedAmount);

      if (success) {
        if (!mounted) return;

        // --- UPDATED SUCCESS SNACKBAR ---
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Successfully added RM ${_selectedAmount.toStringAsFixed(2)}!",
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold
              ),
            ),
            backgroundColor: Colors.green.shade600, // Vibrant green
            behavior: SnackBarBehavior.floating, // Makes it look modern/detached
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        Navigator.pop(context);
      } else {
        // Show error if success is false
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Transaction failed. Please try again."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      print("Error in UI _handleTopUp: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // --- UPDATED: Integrated with image_1.png color theme ---
  Widget _buildBalanceCard(ColorScheme theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        // GRADIENT UPDATE: Dark Purple to Light Purple
        gradient: LinearGradient(
          colors: [
            theme.primary.withOpacity(0.8), // Rich Deep Purple
            theme.primary.withOpacity(0.4), // Softer Glow Purple
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.primary.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Current Balance",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const Icon(Icons.wifi_tethering, color: Colors.white24, size: 24),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "RM ${walletBalance.toStringAsFixed(2)}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 25),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "ABC WALLET",
                style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Icon(Icons.contactless_outlined, color: Colors.white54, size: 28),
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    // Main background from image_1.png (scaffold)
    const Color scaffoldBg = Color(0xFF101018);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text("Top Up", style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: scaffoldBg,
        elevation: 0,
        // Close button to match the [X] in image_1.png
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // THE INTEGRATED BALANCE CARD
            _buildBalanceCard(theme),

            const SizedBox(height: 40),

            Text(
                "Add Funds",
                style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 18,
                    fontWeight: FontWeight.bold
                )
            ),
            const SizedBox(height: 20),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _amounts.length,
              itemBuilder: (context, index) {
                bool isSelected = _selectedAmount == _amounts[index];
                return InkWell(
                  onTap: () => setState(() => _selectedAmount = _amounts[index]),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      // Subtle BG, and Purple border ONLY when selected
                      color: isSelected ? theme.primary.withOpacity(0.08) : Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? theme.primary : Colors.white.withOpacity(0.06),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      "RM ${_amounts[index].toStringAsFixed(0)}",
                      style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.bold,
                          fontSize: 18
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 50),

            // THE SAVE/CONFIRM ACCENT BUTTON (Matches "Save receipt")
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primary, // This is your powerful Purple
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isProcessing ? null : _handleTopUp,
                child: _isProcessing
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                  "Top Up RM ${_selectedAmount.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}