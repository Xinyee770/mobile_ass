import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class PaymentService {
  final _supabase = Supabase.instance.client;

  // ---------------------------------------------------------
  // 1. GLOBAL TEST CONFIGURATION
  // ---------------------------------------------------------
  // Hardcode your test user ID here once.
  final String _userId = "1";

  // ---------------------------------------------------------
  // 2. DATABASE READ OPERATIONS
  // ---------------------------------------------------------

  // Get specific booking details for the Checkout screen
  Future<Map<String, dynamic>> getBookingDetails(int bookingId) async {
    return await _supabase
        .from('booking')
        .select('*, courses(course_name, course_price)')
        .eq('booking_id', bookingId)
        .single();
  }

  // Get full history with joined tables for the History screen
  Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    final response = await _supabase
        .from('payment')
        .select('*, booking(*, courses(course_name))')
        .eq('user_id', _userId) // Added filter to use the centralized ID
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // ---------------------------------------------------------
  // 3. DATABASE CREATE & UPDATE OPERATIONS
  // ---------------------------------------------------------

  // IMPROVED: Check if a payment record exists before creating a new one
  Future<int> createPendingPayment({required int bookingId, required double amount}) async {
    // 1. Check if a record already exists for this booking
    final existing = await _supabase
        .from('payment')
        .select('payment_id')
        .eq('booking_id', bookingId)
        .maybeSingle();

    if (existing != null) {
      // 2. If it exists, just return that ID (don't create a new row)
      return existing['payment_id'];
    }

    // 3. If it doesn't exist, create it using the centralized _userId
    final response = await _supabase.from('payment').insert({
      'booking_id': bookingId,
      'user_id': _userId, // Using centralized ID
      'amount': amount,
      'status': 'pending',
      'payment_method': 'Not Selected',
    }).select().single();

    return response['payment_id'];
  }

  // UPDATE: Finalize payment after biometric success
  Future<void> completePayment({
    required int paymentId,
    required int bookingId,
    required String method,
  }) async {
    // Mark payment as success
    await _supabase.from('payment').update({
      'status': 'success',
      'payment_method': method,
    }).eq('payment_id', paymentId);

    // Update the booking itself to 'Paid'
    await _supabase
        .from('booking')
        .update({'booking_status': 'Paid'})
        .eq('booking_id', bookingId);
  }

  // UPDATE (Soft Delete): Mark as refunded
  Future<void> refundPayment(int paymentId, String reason) async {
    try {
      await _supabase // Simplified reference
          .from('payment')
          .update({
        'status': 'refunded',
        'refund_reasons': reason,
      })
          .eq('payment_id', paymentId);
    } catch (e) {
      throw Exception("Failed to update refund: $e");
    }
  }

  // ---------------------------------------------------------
  // 4. UTILITY: PDF GENERATION & SHARING
  // ---------------------------------------------------------

  Future<void> shareReceipt(Map<String, dynamic> item) async {
    try {
      final pdf = pw.Document();

      final booking = item['booking'] ?? item;
      final course = booking['courses'] ?? {'course_name': 'N/A'};
      final amount = (item['amount'] ?? course['course_price'] ?? 0.0) as num;
      final paymentId = item['payment_id'] ?? 'Pending';

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(level: 0, child: pw.Text("OFFICIAL RECEIPT")),
                pw.SizedBox(height: 20),
                pw.Text("Transaction ID: TXN-$paymentId"),
                pw.Text("Date: ${DateTime.now().toString().substring(0, 16)}"),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Text("Course: ${course['course_name']}"),
                pw.Text("Booking ID: #${item['booking_id'] ?? item['id']}"),
                pw.Text("Location: ${booking['location'] ?? 'Main Studio'}"),
                pw.Text("Method: ${item['payment_method'] ?? 'Digital Payment'}"),
                pw.SizedBox(height: 20),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text("Total Paid: RM ${amount.toDouble().toStringAsFixed(2)}",
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20)),
                ),
                pw.SizedBox(height: 40),
                pw.Center(child: pw.Text("Thank you for your support!")),
              ],
            );
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/Receipt_$paymentId.pdf");
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], text: 'My Receipt');

    } catch (e) {
      print("PDF Error: $e");
    }
  }
}