import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentService {
  final _supabase = Supabase.instance.client;

  // READ: Get booking & course info
  Future<Map<String, dynamic>> getBookingDetails(int bookingId) async {
    return await _supabase
        .from('booking')
        .select('*, courses(course_name, course_price)')
        .eq('booking_id', bookingId)
        .single();
  }

  // CREATE + UPDATE: Process the money and update the booking status
  Future<void> processPayment({
    required int bookingId,
    required double amount,
    required String method,
  }) async {
    // 1. Insert into payment table (Create)
    await _supabase.from('payment').insert({
      'booking_id': bookingId,
      'user_id': 1, // Test ID
      'amount': amount,
      'status': 'success',
      'payment_method': method,
    });

    // 2. Update booking table (Update)
    await _supabase
        .from('booking')
        .update({'booking_status': 'Paid'})
        .eq('booking_id', bookingId);
  }
}