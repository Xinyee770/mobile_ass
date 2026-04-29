import 'package:flutter/material.dart';
import '../services/wallet_service.dart';
import 'package:flutter/services.dart';

class AddPaymentMethodPage extends StatefulWidget {
  final Map<String, dynamic>? existingMethod; // Pass this when editing
  const AddPaymentMethodPage({super.key, this.existingMethod});

  @override
  State<AddPaymentMethodPage> createState() => _AddPaymentMethodPageState();
}

class _AddPaymentMethodPageState extends State<AddPaymentMethodPage> {
  final _formKey = GlobalKey<FormState>();
  final WalletService _walletService = WalletService();

  String _selectedType = 'Credit Card';
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Fill data if editing
    if (widget.existingMethod != null) {
      _nicknameController.text = widget.existingMethod!['nickname'] ?? "";
      _selectedType = widget.existingMethod!['method_type'] ?? 'Credit Card';
      _numberController.text = widget.existingMethod!['identifier'] ?? "";
      _expiryController.text = widget.existingMethod!['expiry_date'] ?? "";
    }
  }

  Future<void> _saveMethod() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    String identifier = _numberController.text.trim();

    // Only mask if it's a new credit card entry
    if (widget.existingMethod == null && _selectedType == 'Credit Card') {
      identifier = "**** **** **** ${identifier.substring(identifier.length - 4)}";
    }

    try {
      bool success;
      if (widget.existingMethod != null) {
        // UPDATE LOGIC
        success = await _walletService.updatePaymentMethod(
          id: widget.existingMethod!['id'],
          nickname: _nicknameController.text.trim(),
          expiry: _expiryController.text.trim(),
        );
      } else {
        // CREATE LOGIC
        success = await _walletService.addSavedMethod(
          type: _selectedType,
          nickname: _nicknameController.text.trim(),
          identifier: identifier,
          expiry: _selectedType == 'Credit Card' ? _expiryController.text.trim() : null,
        );
      }

      if (success && mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color scaffoldBg = Color(0xFF101018);
    final theme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(widget.existingMethod != null ? "Edit Method" : "Link New Method",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: scaffoldBg,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          children: [
            const Text("PAYMENT DETAILS", style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // 1. SHRUNK DROPDOWN
            Row(
              children: [
                SizedBox(
                  width: 180, // Shrinks the width to fit the field size
                  child: DropdownButtonFormField<String>(
                    value: _selectedType,
                    dropdownColor: const Color(0xFF1A1A2E),
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: _inputDecoration("Method Type"),
                    items: ['Credit Card', 'TNG'].map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                    onChanged: widget.existingMethod != null ? null : (val) => setState(() => _selectedType = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 2. NICKNAME
            TextFormField(
              controller: _nicknameController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration("Card Nickname"),
              validator: (val) => val!.isEmpty ? "Please enter a nickname" : null,
            ),
            const SizedBox(height: 20),

            // 3. IDENTIFIER (Validation Fixed)
            TextFormField(
              controller: _numberController,
              enabled: widget.existingMethod == null,
              style: TextStyle(color: widget.existingMethod == null ? Colors.white : Colors.white38),
              keyboardType: TextInputType.number,
              inputFormatters: _selectedType == 'Credit Card'
                  ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(16)]
                  : [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
              decoration: _inputDecoration(
                _selectedType == 'Credit Card' ? "Card Number" : "Phone Number",
                hint: _selectedType == 'Credit Card' ? "1234 5678 1234 5678" : "0123456789",
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return "Field required";
                if (widget.existingMethod != null) return null;
                if (_selectedType == 'Credit Card' && val.length != 16) return "Enter 16 digits";
                return null;
              },
            ),
            const SizedBox(height: 20),

            // 4. EXPIRY (Simple & Stable Version)
            if (_selectedType == 'Credit Card')
              TextFormField(
                controller: _expiryController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.datetime, // Shows a keyboard better for dates
                inputFormatters: [
                  // Only allow digits and the slash
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                  LengthLimitingTextInputFormatter(5), // Limits to "MM/YY" (5 chars)
                ],
                decoration: _inputDecoration(
                    "Expiry Date",
                    hint: "MM/YY (e.g. 12/28)"
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return "Required";
                  // Basic check for the slash position
                  if (!RegExp(r'^(0[1-9]|1[0-2])\/[0-9]{2}$').hasMatch(val)) {
                    return "Use MM/YY format";
                  }
                  return null;
                },
              ),

            const SizedBox(height: 50),

            // 5. FIXED ACTION BUTTON WITH TEXT
            SizedBox(
              height: 60,
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 8,
                ),
                onPressed: _isSaving ? null : _saveMethod,
                child: _isSaving
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(widget.existingMethod != null ? "UPDATE PAYMENT METHOD" : "LINK PAYMENT METHOD",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white10, fontSize: 14),
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 14),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.white10)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.deepPurpleAccent, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.red.shade800)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.red.shade800, width: 2)),
    );
  }
}
