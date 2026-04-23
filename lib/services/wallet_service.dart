import 'package:supabase_flutter/supabase_flutter.dart';

class WalletService {
  final _supabase = Supabase.instance.client;

  // 1. Get current balance
  Future<double> getBalance() async {
    try {
      // Ensure this matches your testing ID!
      const String tempUserId = "1";

      final data = await _supabase
          .from('wallets')
          .select('balance')
          .eq('user_id', tempUserId)
          .maybeSingle();

      print("Fetched Balance for User 1: ${data?['balance']}"); // Debug log
      return (data?['balance'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      print("Error fetching wallet: $e");
      return 0.0;
    }
  }

  // 2. Updated Top Up (Using Upsert)
  Future<bool> topUpWallet(double amount) async {
    try {
      // TEMPORARY: Hardcoding user_id to 1 for testing
      // Change this back to _supabase.auth.currentUser?.id later!
      const String tempUserId = "1";

      print("DEBUG: Testing Top Up for User: $tempUserId");

      // 1. Get current balance
      final walletResponse = await _supabase
          .from('wallets')
          .select('balance')
          .eq('user_id', tempUserId)
          .maybeSingle();

      double currentBalance = (walletResponse?['balance'] as num?)?.toDouble() ?? 0.0;
      double newBalance = currentBalance + amount;

      // 2. UPSERT the balance
      await _supabase.from('wallets').upsert({
        'user_id': tempUserId,
        'balance': newBalance,
      }, onConflict: 'user_id');

      // 3. Log the transaction
      await _supabase.from('wallet_transactions').insert({
        'user_id': tempUserId,
        'amount': amount,
        'transaction_type': 'credit',
        'category': 'topup',
        'description': 'Manual Testing Top Up',
      });

      return true;
    } catch (e) {
      print("Top up error: $e");
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getTransactionHistory() async {
    try {
      final response = await _supabase
          .from('wallet_transactions')
          .select()
          .eq('user_id', '1') // Using your test user_id
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print("Error fetching history: $e");
      return [];
    }
  }
}