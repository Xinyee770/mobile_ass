import 'package:supabase_flutter/supabase_flutter.dart';

class WalletService {
  final _supabase = Supabase.instance.client;

  // ---------------------------------------------------------
  // 1. GLOBAL TEST CONFIGURATION
  // ---------------------------------------------------------
  // Change this once to update the whole service
  String get _userId {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      // For testing, you could temporarily return a real UUID string here
      // if you aren't logged in yet.
      return "";
    }
    return user.id; // This is the UUID from Supabase Auth
  }

  // ---------------------------------------------------------
  // 2. BALANCE OPERATIONS
  // ---------------------------------------------------------

  // Get current balance from your ACTUAL 'wallets' table
  Future<double> getBalance() async {
    try {
      if (_userId.isEmpty) return 0.0;

      final data = await _supabase
          .from('wallets')
          .select('balance')
          .eq('user_id', _userId)
          .maybeSingle();

      // --- NEW LOGIC: If no row exists, CREATE it ---
      if (data == null) {
        print("Initializing new wallet for user: $_userId");
        await _supabase.from('wallets').insert({
          'user_id': _userId,
          'balance': 0.0,
        });
        return 0.0;
      }

      return (data['balance'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      print("Error fetching wallet balance: $e");
      return 0.0;
    }
  }

  // ---------------------------------------------------------
  // 3. TRANSACTION OPERATIONS
  // ---------------------------------------------------------

  // TOP UP: Add money to 'wallets' table
  Future<bool> topUpWallet(double amount, String refId, int paymentMethodId) async {
    try {
      double currentBalance = await getBalance();

      // Update the balance in the 'wallets' table
      await _supabase.from('wallets').update({
        'balance': currentBalance + amount
      }).eq('user_id', _userId);

      // Log the credit in 'wallet_transactions'
      await _supabase.from('wallet_transactions').insert({
        'user_id': _userId,
        'amount': amount,
        'transaction_type': 'credit',
        'category': 'topup',
        'reference_id': refId,
        'payment_method_id': paymentMethodId,
        'payment_id': null,
        'description': 'Wallet Top-up',
      });

      return true;
    } catch (e) {
      print("DEBUG: Wallet Top-Up Failed! Error: $e");
      return false;
    }
  }

  // PAY WITH WALLET: Deduct money from 'wallets' table
  Future<bool> payWithWallet(double amount, int paymentId, String courseName) async {
    try {
      final String refId = "PAY-BK-${DateTime.now().millisecondsSinceEpoch}";
      double currentBalance = await getBalance();

      if (currentBalance < amount) {
        print("Payment Error: Insufficient funds");
        return false;
      }

      // Deduct from 'wallets' table
      await _supabase.from('wallets').update({
        'balance': currentBalance - amount,
      }).eq('user_id', _userId);

      // Log the debit in 'wallet_transactions'
      await _supabase.from('wallet_transactions').insert({
        'user_id': _userId,
        'amount': -amount,
        'transaction_type': 'debit',
        'category': 'booking',
        'reference_id': refId,
        'payment_id': paymentId,
        'payment_method_id': null,
        'description': 'Paid for $courseName',
      });

      return true;
    } catch (e) {
      print("Wallet Payment Error: $e");
      return false;
    }
  }

  // ---------------------------------------------------------
  // 4. HISTORY & SAVED METHODS
  // ---------------------------------------------------------

  Future<List<Map<String, dynamic>>> getTransactionHistory() async {
    try {
      final response = await _supabase
          .from('wallet_transactions')
          .select()
          .eq('user_id', _userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print("Error fetching history: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSavedPaymentMethods() async {
    try {
      final data = await _supabase
          .from('saved_payment_methods')
          .select()
          .eq('user_id', _userId);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print("Error fetching saved methods: $e");
      return [];
    }
  }

  Future<bool> addSavedMethod({
    required String type,
    required String nickname,
    required String identifier,
    String? expiry,
  }) async {
    try {
      await _supabase.from('saved_payment_methods').insert({
        'user_id': _userId,
        'method_type': type,
        'nickname': nickname,
        'identifier': identifier,
        'expiry_date': expiry,
      });
      return true;
    } catch (e) {
      print("Error saving method: $e");
      return false;
    }
  }

  Future<bool> deletePaymentMethod(int id) async {
    try {
      await _supabase.from('saved_payment_methods').delete().eq('id', id);
      return true;
    } catch (e) {
      print("Delete Method Error: $e");
      return false;
    }
  }

  Future<bool> updatePaymentMethod({
    required int id,
    required String nickname,
    required String expiry,
  }) async {
    try {
      await _supabase
          .from('saved_payment_methods')
          .update({
        'nickname': nickname,
        'expiry_date': expiry,
      })
          .eq('id', id);
      return true;
    } catch (e) {
      print("Update Method Error: $e");
      return false;
    }
  }

  Future<bool> refundToWallet({
    required int paymentId,
    required double amount,
    required String reason
  }) async {
    try {
      // A. Generate a reference for the refund
      final String refId = "REF-${DateTime.now().millisecondsSinceEpoch}";

      // B. Get current balance and add the refund amount
      double currentBalance = await getBalance();

      await _supabase.from('wallets').update({
        'balance': currentBalance + amount
      }).eq('user_id', _userId);

      // C. Log the refund in wallet_transactions
      await _supabase.from('wallet_transactions').insert({
        'user_id': _userId,
        'amount': amount, // Positive because money is coming in
        'transaction_type': 'credit',
        'category': 'refund',
        'reference_id': refId,
        'payment_id': paymentId, // Link to the original payment ID
        'description': 'Refund for #$paymentId: $reason',
      });

      return true;
    } catch (e) {
      print("Wallet Refund Logic Error: $e");
      return false;
    }
  }
}