import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/wallet_service.dart';
import 'package:intl/intl.dart';

class WalletTransactionHistory extends StatefulWidget {
  const WalletTransactionHistory({super.key});

  @override
  State<WalletTransactionHistory> createState() => _WalletTransactionHistoryState();
}

class _WalletTransactionHistoryState extends State<WalletTransactionHistory> {
  final WalletService _walletService = WalletService();
  late Future<List<Map<String, dynamic>>> _transactionsFuture;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  List<Map<String, dynamic>> _rawPayments = [];

  @override
  void initState() {
    super.initState();
    // Fetch both tables at once
    _transactionsFuture = Future.wait([
      _walletService.getTransactionHistory(),
      _walletService.getRawPayments(),
    ]).then((results) {
      // Save the payment table results to our local variable
      _rawPayments = List<Map<String, dynamic>>.from(results[1]);

      // Return the wallet transactions for the main list
      return List<Map<String, dynamic>>.from(results[0]);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildSummaryHeader(List<Map<String, dynamic>> data, ColorScheme theme) {
    // Card 1 & 2 Data (Calculated from transactions list)
    double totalCredits = 0;
    double totalDebits = 0;
    int creditCount = 0;
    int debitCount = 0;
    Map<String, double> categoryMap = {};

    // Card 3 Data (Calculated from raw payments list)
    int walletCount = 0;
    int directCount = 0;

    // --- LOOP 1: Process Transaction History for Cards 1 & 2 ---
    for (var item in data) {
      double amt = (item['amount'] ?? 0).toDouble().abs();
      if (item['transaction_type'] == 'credit') {
        totalCredits += amt;
        creditCount++;
      } else {
        totalDebits += amt;
        debitCount++;
        // Category Spending logic
        String cat = item['description'] ?? "Other";
        categoryMap[cat] = (categoryMap[cat] ?? 0) + amt;
      }
    }

    // --- LOOP 2: Process Raw Payments for Card 3 ---
    for (var payment in _rawPayments) {
      String method = (payment['payment_method'] ?? "").toString();
      if (method == "My Wallet") {
        walletCount++;
      } else if (method.isNotEmpty) {
        directCount++;
      }
    }

    double walletFinal = walletCount.toDouble();
    double directFinal = directCount.toDouble();

    return Column(
      children: [
        SizedBox(
          height: 240,
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            children: [
              // CARD 1: Cash Flow
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: _buildOriginalCashFlow(totalCredits, totalDebits, creditCount, debitCount, theme),
              ),
              // CARD 2: Category Spending
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: _buildCategorySpending(categoryMap, totalDebits, theme),
              ),
              // CARD 3: Payment Preference
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: _buildPaymentMethodInsights(walletFinal, directFinal, theme),
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDot(0),
            const SizedBox(width: 8),
            _buildDot(1),
            const SizedBox(width: 8),
            _buildDot(2),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }


  Widget _buildOriginalCashFlow(double totalCredits, double totalDebits, int creditCount, int debitCount, ColorScheme theme) {
    double totalFlow = totalCredits + totalDebits;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 38, // Slightly larger for text
                    sections: [
                      PieChartSectionData(color: Colors.greenAccent, value: totalCredits == 0 ? 1 : totalCredits, title: '', radius: 18),
                      PieChartSectionData(color: Colors.redAccent, value: totalDebits == 0 ? 0.1 : totalDebits, title: '', radius: 14),
                    ],
                  ),
                ),
                // --- CENTER TEXT ---
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("TOTAL", style: TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold)),
                    Text(
                        "RM ${(totalFlow).toStringAsFixed(0)}",
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 25),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatDetail("TOTAL CREDITS", "RM ${totalCredits.toStringAsFixed(2)}", Colors.greenAccent, Icons.add_chart),
                const SizedBox(height: 16),
                _buildStatDetail("TOTAL DEBITS", "RM ${totalDebits.toStringAsFixed(2)}", Colors.redAccent, Icons.analytics_outlined),
                const Divider(color: Colors.white10, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _miniCounter("$creditCount Credits", Colors.greenAccent),
                    _miniCounter("$debitCount Debits", Colors.redAccent),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

// The new Category Spending UI
  Widget _buildCategorySpending(Map<String, double> categories, double totalDebits, ColorScheme theme) {
    List<Color> palette = [
      Colors.purpleAccent,
      Colors.cyanAccent,
      Colors.orangeAccent,
      Colors.pinkAccent,
      Colors.blueAccent,
      Colors.lightGreenAccent,
      Colors.yellowAccent,
      Colors.greenAccent,
    ];
    int i = 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 38,
                    sections: categories.entries.map((e) {
                      final color = palette[i % palette.length];
                      i++;
                      return PieChartSectionData(
                        color: color,
                        value: e.value,
                        title: '', // Titles inside slices can look messy, so we hide them
                        radius: 16,
                      );
                    }).toList(),
                  ),
                ),
                // --- CENTER TEXT ---
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("SPENT", style: TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold)),
                    Text(
                        "RM ${totalDebits.toStringAsFixed(0)}",
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 25),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("SPENDING BY COURSE", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 12),
                ...categories.entries.take(4).map((e) {
                  int idx = categories.keys.toList().indexOf(e.key);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: palette[idx % palette.length])),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(
                                "${((e.value / (totalDebits > 0 ? totalDebits : 1)) * 100).toStringAsFixed(0)}% ${e.key}",
                                style: const TextStyle(color: Colors.white70, fontSize: 10),
                                overflow: TextOverflow.ellipsis
                            )
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _currentPage == index ? const Color(0xFF9D59FF) : Colors.white10,
      ),
    );
  }

// Helper for the stat rows
  Widget _buildStatDetail(String label, String value, Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

// Helper for the count bubbles
  Widget _miniCounter(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    const Color bgDeep = Color(0xFF101018);
    const Color cardGrey = Color(0xFF1E1E2C);

    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AppBar(
        title: const Text("Wallet Insights"),
        backgroundColor: bgDeep,
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _transactionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final transactions = snapshot.data ?? [];
          if (transactions.isEmpty) return _buildEmptyState();

          return Column(
            children: [
              // Integrated Pie Chart Header
              _buildSummaryHeader(transactions, theme),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text("TRANSACTION LOG (WALLET ONLY)",
                      style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12)),
                ),
              ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    return _buildTransactionItem(tx, theme, cardGrey);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx, ColorScheme theme, Color cardColor) {
    DateTime date = DateTime.parse(tx['created_at']);
    String formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);

    final bool isDebit = tx['transaction_type'] == 'debit';
    final double amount = (tx['amount'] as num).toDouble().abs();

    // NEW LOGIC: Determine the display title based on category
    String displayTitle = "";
    if (isDebit) {
      displayTitle = tx['description'] ?? "Course Payment";
    } else {
      // If it's a Credit, check if it's a refund or a normal top-up
      if (tx['category'] == 'refund') {
        displayTitle = "Refunded";
      } else {
        displayTitle = "Wallet Deposit";
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: isDebit ? Colors.redAccent.withOpacity(0.1) : Colors.greenAccent.withOpacity(0.1),
            child: Icon(
              // Change icon for refunds to make it distinct
              tx['category'] == 'refund' ? Icons.assignment_return_rounded :
              (isDebit ? Icons.arrow_outward_rounded : Icons.call_received_rounded),
              color: isDebit ? Colors.redAccent : Colors.greenAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      displayTitle, // Use the new dynamic title here
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)
                  ),
                  const SizedBox(height: 4),
                  // Show the description as a sub-text if it's a refund
                  if (tx['category'] == 'refund' && tx['description'] != null)
                    Text(tx['description'], style: const TextStyle(color: Colors.white38, fontSize: 10))
                  else
                    Text(formattedDate, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
          ),
          Text(
            "${isDebit ? "-" : "+"} RM ${amount.toStringAsFixed(2)}",
            style: TextStyle(
              color: isDebit ? Colors.redAccent : Colors.greenAccent,
              fontWeight: FontWeight.bold,
              fontSize: 15,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 60, color: Colors.white10),
          SizedBox(height: 10),
          Text("No transactions yet", style: TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodInsights(double walletAmt, double directAmt, ColorScheme theme) {
    double total = walletAmt + directAmt;
    double safeTotal = total > 0 ? total : 1;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("PAYMENT PREFERENCE", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 20),

          _buildMethodBar(
              "My Wallet",
              walletAmt / safeTotal,
              const Color(0xFF9D59FF),
              Icons.wallet
          ),

          const SizedBox(height: 20),

          _buildMethodBar(
              "Direct Payment (Card/TNG/GrabPay)",
              directAmt / safeTotal,
              Colors.cyanAccent,
              Icons.payments
          ),

          const Spacer(),
          Text(
            "Based on ${total.toInt()} total transactions.",
            style: const TextStyle(color: Colors.white10, fontSize: 10),
          )
        ],
      ),
    );
  }

  Widget _buildMethodBar(String label, double percentage, Color color, IconData icon) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const Spacer(),
            Text("${(percentage * 100).toStringAsFixed(0)}%",
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.white.withOpacity(0.05),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 10,
          ),
        ),
      ],
    );
  }
}