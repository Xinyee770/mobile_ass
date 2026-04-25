import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

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
      final course = booking['courses'] ?? {'course_name': 'Course Payment'};
      final amount = (item['amount'] ?? course['course_price'] ?? 0.0) as num;
      final paymentId = item['payment_id'] ?? 'Pending';

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // --- Header with Brand ---
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("ABC APP", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(5),
                      decoration: const pw.BoxDecoration(color: PdfColors.green),
                      child: pw.Text("PAID", style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Text("Official Payment Receipt"),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 20),

                // --- Transaction Details ---
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("Invoice To:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text("User One"), // You can pass user name here
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("Transaction ID: TXN-$paymentId"),
                        pw.Text("Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}"),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),

                // --- Item Table ---
                pw.Table(
                  border: const pw.TableBorder(bottom: pw.BorderSide(width: 1, color: PdfColors.grey300)),
                  children: [
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("Description", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("Total", style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("${course['course_name']} - ${booking['location'] ?? 'Online'}")),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("RM ${amount.toDouble().toStringAsFixed(2)}", textAlign: pw.TextAlign.right)),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 20),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text("Grand Total: RM ${amount.toDouble().toStringAsFixed(2)}",
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
                ),

                pw.Spacer(),
                pw.Center(child: pw.Text("This is a computer-generated receipt. No signature required.", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey))),
                pw.Center(child: pw.Text("Thank you for choosing ABC APP!", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
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