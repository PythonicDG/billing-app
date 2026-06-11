import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../report_provider.dart';
import '../widgets/app_drawer.dart';
import '../constants.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  _ReportScreenState createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchInitialData();
    });
  }

  void _fetchInitialData() {
    final provider = Provider.of<ReportProvider>(context, listen: false);
    provider.fetchOutstandingList();
    provider.fetchTopCustomers();
    provider.fetchAnalytics(30);
    provider.fetchDailySnapshot();
    provider.fetchLowStockAudit();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Business Reports', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [
              Tab(icon: Icon(Icons.people_alt_outlined), text: 'Customers'),
              Tab(icon: Icon(Icons.analytics_outlined), text: 'Analytics'),
              Tab(icon: Icon(Icons.account_balance_wallet_outlined), text: 'Operations'),
            ],
          ),
        ),
        drawer: const AppDrawer(),
        body: const TabBarView(
          children: [
            CustomerInsightsTab(),
            SalesAnalyticsTab(),
            OperationsFinanceTab(),
          ],
        ),
      ),
    );
  }
}

class CustomerInsightsTab extends StatelessWidget {
  const CustomerInsightsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ReportProvider>(context);
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    if (provider.isLoading && provider.outstandingList == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        await provider.fetchOutstandingList();
        await provider.fetchTopCustomers();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              title: 'Outstanding Payments',
              subtitle: 'Collection helper list',
              action: ElevatedButton.icon(
                onPressed: () => _downloadReport(context, ApiConstants.reportCustomersUrl, {'type': 'outstanding'}),
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('Collection Sheet'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              ),
            ),
            const SizedBox(height: 12),
            _buildOutstandingList(provider.outstandingList, currencyFormat),
            const SizedBox(height: 32),
            _buildSectionHeader(
              title: 'Top Customers',
              subtitle: 'Based on total business',
            ),
            const SizedBox(height: 12),
            _buildTopCustomersList(provider.topCustomers, currencyFormat),
          ],
        ),
      ),
    );
  }

  Widget _buildOutstandingList(List? list, NumberFormat format) {
    if (list == null || list.isEmpty) {
      return _buildEmptyState('No outstanding payments');
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: list.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = list[index];
          return ListTile(
            title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(item['phone']),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(format.format(item['outstanding']), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626), fontSize: 16)),
                Text('${item['days_overdue']} days overdue', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
            onTap: () => _shareOnWhatsApp(item['phone'], item['name'], item['outstanding']),
          );
        },
      ),
    );
  }

  Widget _buildTopCustomersList(List? list, NumberFormat format) {
    if (list == null || list.isEmpty) {
      return _buildEmptyState('No customer data available');
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: list.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = list[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFEFF6FF),
              child: Text('${index + 1}', style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
            ),
            title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Visits: ${item['visit_frequency']}'),
            trailing: Text(format.format(item['total_business']), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
          );
        },
      ),
    );
  }

  void _shareOnWhatsApp(String phone, String name, dynamic amount) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final message = "Dear $name, a friendly reminder that your outstanding balance with Vighnaharta Fataka is ₹$amount. Please clear it at your earliest convenience. Thank you!";
    final url = "https://wa.me/91$cleanPhone?text=${Uri.encodeComponent(message)}";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}

class SalesAnalyticsTab extends StatelessWidget {
  const SalesAnalyticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ReportProvider>(context);
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    if (provider.isLoading && provider.analyticsData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final data = provider.analyticsData;
    if (data == null) return _buildEmptyState('No analytics data available');

    final salesOverTime = data['sales_over_time'] as List;
    final paymentSplit = data['payment_split'] as List;
    final productPerformance = data['product_performance'] as List;
    final categoryPerformance = data['category_performance'] as List? ?? [];

    return RefreshIndicator(
      onRefresh: () => provider.fetchAnalytics(30),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(title: 'Revenue Over Time', subtitle: 'Last 30 days performance'),
            const SizedBox(height: 12),
            _buildRevenueChart(salesOverTime),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(title: 'Payment Modes', subtitle: 'Cash vs UPI'),
                      const SizedBox(height: 12),
                      _buildPaymentSplitPie(paymentSplit),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(title: 'Product Mix', subtitle: 'Top moving items'),
                      const SizedBox(height: 12),
                      _buildProductPerformanceList(productPerformance),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSectionHeader(title: 'Category Performance', subtitle: 'Revenue by category'),
            const SizedBox(height: 12),
            _buildCategoryPerformanceList(categoryPerformance, currencyFormat),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPerformanceList(List data, NumberFormat format) {
    if (data.isEmpty) return _buildEmptyState('No category data');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8),
        itemCount: data.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = data[index];
          return ListTile(
            title: Text(item['category'], style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: Text(format.format(item['revenue']), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
          );
        },
      ),
    );
  }

  Widget _buildRevenueChart(List data) {
    if (data.isEmpty) return _buildEmptyState('No sales data');

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['revenue'] as num).toDouble())).toList(),
              isCurved: true,
              color: const Color(0xFF2563EB),
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: const Color(0xFF2563EB).withOpacity(0.1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSplitPie(List data) {
    if (data.isEmpty) return _buildEmptyState('No payment data');

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: PieChart(
        PieChartData(
          sections: data.map((e) {
            final isCash = e['mode'] == 'CASH';
            return PieChartSectionData(
              value: (e['total'] as num).toDouble(),
              title: e['mode'],
              color: isCash ? const Color(0xFF16A34A) : const Color(0xFF0891B2),
              radius: 50,
              titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildProductPerformanceList(List data) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: data.take(5).length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = data[index];
          return ListTile(
            dense: true,
            title: Text(item['name'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            trailing: Text('${item['units_sold']} sold', style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
          );
        },
      ),
    );
  }
}

class OperationsFinanceTab extends StatelessWidget {
  const OperationsFinanceTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ReportProvider>(context);
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    if (provider.isLoading && provider.dailySnapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final snapshot = provider.dailySnapshot;

    return RefreshIndicator(
      onRefresh: () async {
        await provider.fetchDailySnapshot();
        await provider.fetchLowStockAudit();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(title: "Today's Closing", subtitle: "Snapshot of daily operations"),
            const SizedBox(height: 12),
            if (snapshot != null)
              _buildDailyClosingGrid(snapshot, currencyFormat)
            else
              _buildEmptyState('No snapshot data'),
            const SizedBox(height: 32),
            _buildSectionHeader(
              title: 'Low Stock Audit',
              subtitle: 'Items needing purchase',
              action: ElevatedButton.icon(
                onPressed: () => _downloadReport(context, ApiConstants.reportOperationsUrl, {'type': 'low_stock'}),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Purchase List'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              ),
            ),
            const SizedBox(height: 12),
            _buildLowStockList(provider.lowStockAudit),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyClosingGrid(Map snapshot, NumberFormat format) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _buildClosingCard('Total Sales', format.format(snapshot['total_sales']), const Color(0xFF2563EB), Icons.trending_up),
        _buildClosingCard('Est. Profit', format.format(snapshot['total_profit'] ?? 0), const Color(0xFF7C3AED), Icons.account_balance),
        _buildClosingCard('Cash Received', format.format(snapshot['cash_received']), const Color(0xFF16A34A), Icons.payments_outlined),
        _buildClosingCard('UPI Received', format.format(snapshot['upi_received']), const Color(0xFF0891B2), Icons.qr_code_scanner),
        _buildClosingCard('New Credit', format.format(snapshot['new_credit']), const Color(0xFFDC2626), Icons.money_off),
        _buildClosingCard('Bills Today', '${snapshot['bill_count'] ?? 0}', const Color(0xFFF59E0B), Icons.receipt_long),
      ],
    );
  }

  Widget _buildClosingCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockList(List? list) {
    if (list == null || list.isEmpty) {
      return _buildEmptyState('All stock levels are healthy');
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: list.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = list[index];
          return ListTile(
            title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(item['brand'] ?? 'No Brand'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${item['stock']} Cent', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF97316))),
                Text('Min: ${item['min_level']}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Reusable components
Widget _buildSectionHeader({required String title, required String subtitle, Widget? action}) {
  return Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ],
        ),
      ),
      if (action != null) action,
    ],
  );
}

Widget _buildEmptyState(String message) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(Icons.info_outline, size: 48, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Color(0xFF64748B))),
        ],
      ),
    ),
  );
}

Future<void> _downloadReport(BuildContext context, String url, Map<String, String> params) async {
  final provider = Provider.of<ReportProvider>(context, listen: false);
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating PDF...')));
  final bytes = await provider.downloadReport(url, params);
  if (bytes != null) {
    await Printing.layoutPdf(onLayout: (format) async => bytes);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to generate PDF'), backgroundColor: Colors.red));
  }
}
