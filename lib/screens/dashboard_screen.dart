import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../dashboard_provider.dart';
import '../auth_provider.dart';
import 'products_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _autoRefreshTimer;
  DateTime? _lastRefreshed;
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _loadDashboard();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _loadDashboard() {
    Provider.of<DashboardProvider>(context, listen: false)
        .fetchDashboardSummary()
        .then((_) {
      if (mounted) {
        setState(() {
          _lastRefreshed = DateTime.now();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final dashProvider = Provider.of<DashboardProvider>(context);
    final data = dashProvider.dashboardData;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.dashboard_outlined, color: Color(0xFF2563EB)),
            const SizedBox(width: 8),
            const Text(
              'Dashboard',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Color(0xFF0F172A)),
            ),
            const Spacer(),
            if (_lastRefreshed != null)
              Text(
                'Updated ${DateFormat('hh:mm a').format(_lastRefreshed!)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: dashProvider.isDashboardLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)))
                : const Icon(Icons.refresh_outlined, color: Color(0xFF2563EB)),
            tooltip: 'Refresh',
            onPressed: dashProvider.isDashboardLoading ? null : _loadDashboard,
          ),
          const SizedBox(width: 8),
        ],
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      drawer: const AppDrawer(),
      body: _buildBody(dashProvider, data),
    );
  }

  Widget _buildBody(DashboardProvider provider, Map<String, dynamic>? data) {
    if (provider.isDashboardLoading && data == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF2563EB)),
            SizedBox(height: 16),
            Text('Loading dashboard...', style: TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    if (provider.dashboardError != null && data == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Color(0xFFEF4444)),
            const SizedBox(height: 16),
            Text(
              provider.dashboardError!,
              style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadDashboard,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F2C59),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }

    if (data == null) {
      return const Center(child: Text('No data available'));
    }

    final todaySales = (data['today_sales'] as num?)?.toDouble() ?? 0.0;
    final todayCash = (data['today_cash'] as num?)?.toDouble() ?? 0.0;
    final todayUpi = (data['today_upi'] as num?)?.toDouble() ?? 0.0;
    final todayBillCount = (data['today_bill_count'] as num?)?.toInt() ?? 0;
    final totalOutstanding = (data['total_outstanding'] as num?)?.toDouble() ?? 0.0;
    final lowStockProducts = data['low_stock_products'] as List? ?? [];
    final topProducts = data['top_products_today'] as List? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Range Selector Chips
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.calendar_view_day_outlined, size: 18, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  const Text(
                    'Reporting Range: ',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13.5),
                  ),
                  const SizedBox(width: 16),
                  _buildRangeChip(provider, 'today', 'Today'),
                  const SizedBox(width: 8),
                  _buildRangeChip(provider, 'weekly', 'This Week'),
                  const SizedBox(width: 8),
                  _buildRangeChip(provider, 'monthly', 'This Month'),
                  const SizedBox(width: 8),
                  _buildRangeChip(provider, 'yearly', 'This Year'),
                  const SizedBox(width: 8),
                  _buildRangeChip(provider, 'all_time', 'All Time'),
                ],
              ),
            ),
          ),

          // --- Top stat cards ---
          Row(
            children: [
              Expanded(child: _buildStatCard(
                icon: Icons.trending_up_outlined,
                iconColor: const Color(0xFF2563EB),
                label: data['sales_label']?.toString().toUpperCase() ?? "TODAY'S SALES",
                value: currencyFormat.format(todaySales),
                valueColor: const Color(0xFF0F172A),
                accentColor: const Color(0xFF2563EB),
              )),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard(
                icon: Icons.receipt_long_outlined,
                iconColor: const Color(0xFF7C3AED),
                label: data['bills_label']?.toString().toUpperCase() ?? "BILLS CREATED",
                value: todayBillCount.toString(),
                valueColor: const Color(0xFF0F172A),
                accentColor: const Color(0xFF7C3AED),
              )),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard(
                icon: Icons.money_outlined,
                iconColor: const Color(0xFF16A34A),
                label: data['cash_label']?.toString().toUpperCase() ?? "CASH COLLECTED",
                value: currencyFormat.format(todayCash),
                valueColor: const Color(0xFF16A34A),
                accentColor: const Color(0xFF16A34A),
              )),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard(
                icon: Icons.qr_code_outlined,
                iconColor: const Color(0xFF0891B2),
                label: data['upi_label']?.toString().toUpperCase() ?? "UPI COLLECTED",
                value: currencyFormat.format(todayUpi),
                valueColor: const Color(0xFF0891B2),
                accentColor: const Color(0xFF0891B2),
              )),
            ],
          ),
          const SizedBox(height: 20),

          // --- Outstanding card ---
          _buildOutstandingCard(totalOutstanding),
          const SizedBox(height: 20),

          // --- Side-by-side panels ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildLowStockPanel(lowStockProducts)),
              const SizedBox(width: 16),
              Expanded(child: _buildTopProductsPanel(topProducts, title: data['top_label']?.toString())),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutstandingCard(double totalOutstanding) {
    final isPositive = totalOutstanding > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: isPositive ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isPositive ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
        ),
        boxShadow: [
          BoxShadow(
            color: (isPositive ? const Color(0xFFEF4444) : const Color(0xFF16A34A)).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isPositive
                  ? const Color(0xFFEF4444).withOpacity(0.12)
                  : const Color(0xFF16A34A).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPositive ? Icons.warning_amber_outlined : Icons.check_circle_outline,
              color: isPositive ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL OUTSTANDING',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isPositive ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currencyFormat.format(totalOutstanding),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isPositive ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),
          if (isPositive)
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/ledger');
              },
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('View Ledgers', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLowStockPanel(List lowStockProducts) {
    return Container(
      constraints: const BoxConstraints(minHeight: 320),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.warning_amber_outlined, color: Color(0xFFF97316), size: 18),
                ),
                const SizedBox(width: 12),
                const Text(
                  'LOW STOCK ALERTS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF475569),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: lowStockProducts.isNotEmpty ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${lowStockProducts.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: lowStockProducts.isNotEmpty ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // List
          if (lowStockProducts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline, size: 48, color: Color(0xFF16A34A)),
                    SizedBox(height: 12),
                    Text('All products are well stocked!', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: lowStockProducts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final product = lowStockProducts[index];
                final stockQty = product['stock_quantity'] ?? 0;
                final minLevel = product['min_stock_level'] ?? 0;
                final isCritical = stockQty == 0;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isCritical ? const Color(0xFFEF4444) : const Color(0xFFF97316),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['name'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A)),
                            ),
                            if (product['brand'] != null && product['brand'].toString().isNotEmpty)
                              Text(
                                product['brand'],
                                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$stockQty pcs',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isCritical ? const Color(0xFFEF4444) : const Color(0xFFF97316),
                            ),
                          ),
                          Text(
                            'Min: $minLevel',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTopProductsPanel(List topProducts, {String? title}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 320),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.emoji_events_outlined, color: Color(0xFF2563EB), size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  title?.toUpperCase() ?? 'TOP 5 PRODUCTS TODAY',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF475569),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // List
          if (topProducts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.storefront_outlined, size: 48, color: Color(0xFF94A3B8)),
                    SizedBox(height: 12),
                    Text('No sales recorded today', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topProducts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final product = topProducts[index];
                final rank = index + 1;
                final totalQty = product['total_quantity'] ?? 0;

                // Rank badge colors
                Color rankBg;
                Color rankText;
                if (rank == 1) {
                  rankBg = const Color(0xFFFEF3C7);
                  rankText = const Color(0xFFD97706);
                } else if (rank == 2) {
                  rankBg = const Color(0xFFF1F5F9);
                  rankText = const Color(0xFF475569);
                } else if (rank == 3) {
                  rankBg = const Color(0xFFFED7AA);
                  rankText = const Color(0xFFEA580C);
                } else {
                  rankBg = const Color(0xFFF8FAFC);
                  rankText = const Color(0xFF64748B);
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: rankBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '#$rank',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: rankText),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          product['product_name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$totalQty sold',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRangeChip(DashboardProvider provider, String value, String label) {
    final isSelected = provider.dashboardRange == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFFEFF6FF),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF475569),
        fontWeight: FontWeight.bold,
        fontSize: 11.5,
      ),
      onSelected: (selected) {
        if (selected) {
          provider.setDashboardRange(value);
        }
      },
    );
  }
}
