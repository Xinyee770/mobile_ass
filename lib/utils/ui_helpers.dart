import 'package:flutter/material.dart';

class UIHelpers {
  // 1. Unified Snackbar
  static void showSnack(BuildContext context, String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // 2. Time Formatter
  static String formatTime(String? time) {
    if (time == null || time.isEmpty) return "N/A";
    return time.length >= 5 ? time.substring(0, 5) : time;
  }

  // 3. Status Badge Builder (Moved from History Page)
  static Widget buildStatusBadge(String status) {
    status = status.toLowerCase();
    Color color;
    if (status == 'success') color = Colors.green;
    else if (status == 'pending') color = Colors.orange;
    else if (status == 'refunded') color = Colors.grey;
    else color = Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20)
      ),
      child: Text(
          status.toUpperCase(),
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)
      ),
    );
  }

  // 4. Common Receipt Row
  static Widget buildInfoRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: isTotal ? 16 : 14)),
          Text(value, style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isTotal ? 20 : 14,
              color: isTotal ? Colors.blueAccent : Colors.black
          )),
        ],
      ),
    );
  }
}