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
        .select('*, courses(course_name, course_price), instructor(*)')
        .eq('booking_id', bookingId)
        .single();
  }

  // Get full history with joined tables for the History screen
  // Get full history with joined tables for the History screen
  Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    final response = await _supabase
        .from('payment') // Make sure this matches your table name (payment or payments)
        .select('''
          *,
          booking (
            *,
            courses (course_name),
            instructor (*)
          )
        ''')
        .eq('user_id', _userId)
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

      // --- 1. DEEP DATA EXTRACTION ---
      final booking = item['booking'] ?? {};
      final course = booking['courses'] ?? {};
      final instructor = booking['instructor'] ?? {};

      final DateTime paymentDt = DateTime.parse(item['created_at'] ?? DateTime.now().toString());
      final String formattedDate = DateFormat('dd MMM yyyy').format(paymentDt);
      final String formattedTime = DateFormat('hh:mm a').format(paymentDt);

      final String courseName = course['course_name'] ?? 'General Course';
      final String instructorName = instructor['instructor_name'] ?? 'Assigned Instructor';
      final String location = booking['location'] ?? 'Main Studio';
      final String classType = (instructor['is_private'] == true) ? "Private Lesson" : "Public Class";

      final double amount = (item['amount'] as num).toDouble();
      final int paymentId = item['payment_id'];
      final String status = (item['status'] ?? 'pending').toString().toLowerCase();

      // --- 2. DYNAMIC STYLING LOGIC ---
      String statusLabel = "SUCCESSFUL";
      PdfColor statusColor = PdfColors.green;
      String totalLabel = "TOTAL PAID:";

      if (status == 'pending') {
        statusLabel = "PENDING / UNPAID";
        statusColor = PdfColors.orange;
        totalLabel = "TOTAL DUE:";
      } else if (status == 'refunded') {
        statusLabel = "REFUNDED";
        statusColor = PdfColors.red;
        totalLabel = "TOTAL REFUNDED:";
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // --- BRAND HEADER ---
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("ABC DANCE STUDIO", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.purple)),
                        pw.Text("123 Dance Ave, Kuala Lumpur", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                    ),
                    // FIX: Use statusColor and statusLabel variables here
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: pw.BoxDecoration(color: statusColor, borderRadius: pw.BorderRadius.circular(4)),
                      child: pw.Text(statusLabel, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),

                // --- TRANSACTION SUMMARY ---
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("BILL TO:", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                        pw.Text("Customer ID: $_userId", style: pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("RECEIPT NO: TXN-$paymentId", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text("DATE: $formattedDate"),
                        pw.Text("TIME: $formattedTime"),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 40),

                // --- ITEM TABLE ---
                pw.Table(
                  columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1)},
                  border: const pw.TableBorder(bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5)),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("DESCRIPTION", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("AMOUNT", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.right)),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(courseName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                              pw.SizedBox(height: 4),
                              pw.Text("Type: $classType", style: pw.TextStyle(fontSize: 10)),
                              pw.Text("Instructor: $instructorName", style: pw.TextStyle(fontSize: 10)),
                              pw.Text("Location: $location", style: pw.TextStyle(fontSize: 10)),
                            ],
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text("RM ${amount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 14), textAlign: pw.TextAlign.right),
                        ),
                      ],
                    ),
                  ],
                ),

                // --- REFUND REASON (Only shows if status is refunded) ---
                if (status == 'refunded') ...[
                  pw.SizedBox(height: 10),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(color: PdfColors.red50, borderRadius: pw.BorderRadius.circular(4)),
                    child: pw.Text("Reason: ${item['refund_reasons'] ?? 'User Cancellation'}", style: pw.TextStyle(color: PdfColors.red, fontSize: 10, fontStyle: pw.FontStyle.italic)),
                  ),
                ],

                // --- TOTAL SECTION ---
                pw.SizedBox(height: 20),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Container(
                    width: 200,
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text("Subtotal:", style: pw.TextStyle(color: PdfColors.grey700)),
                            pw.Text("RM ${amount.toStringAsFixed(2)}"),
                          ],
                        ),
                        pw.Divider(color: PdfColors.purple),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            // FIX: Use totalLabel here
                            pw.Text(totalLabel, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                            // FIX: Use statusColor for the price text
                            pw.Text("RM ${amount.toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: statusColor)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                pw.Spacer(),
                pw.Divider(color: PdfColors.grey300),
                pw.Center(child: pw.Text("This receipt was generated automatically by ABC App.", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600))),
              ],
            );
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/Receipt_TXN_$paymentId.pdf");
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], text: 'Transaction Receipt');

    } catch (e) {
      print("PDF Generation Error: $e");
    }
  }
}