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

  // Local pagination state for stock status alerts
  int _stockCurrentPage = 1;
  static const int _stockItemsPerPage = 5;

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

  void _loadDashboard({String? range}) {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    
    // Explicitly set the range in the provider and fetch data
    if (range != null) {
      provider.setDashboardRange(range).then((_) {
        if (mounted) {
          setState(() {
            _lastRefreshed = DateTime.now();
            _stockCurrentPage = 1;
          });
        }
      });
    } else {
      provider.fetchDashboardSummary().then((_) {
        if (mounted) {
          setState(() {
            _lastRefreshed = DateTime.now();
            _stockCurrentPage = 1;
          });
        }
      });
    }
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
    final todayProfit = (data['today_profit'] as num?)?.toDouble() ?? 0.0;
    final todayCash = (data['today_cash'] as num?)?.toDouble() ?? 0.0;
    final todayUpi = (data['today_upi'] as num?)?.toDouble() ?? 0.0;
    final todayBillCount = (data['today_bill_count'] as num?)?.toInt() ?? 0;
    final totalOutstanding = (data['total_outstanding'] as num?)?.toDouble() ?? 0.0;
    final lowStockProducts = data['low_stock_products'] as List? ?? [];
    final topProducts = data['top_products_today'] as List? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Range Selector Chips
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
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
          ),

          // --- Top stat cards (Responsive) ---
          LayoutBuilder(builder: (context, constraints) {
            int crossAxisCount = 2;
            if (constraints.maxWidth > 1200) {
              crossAxisCount = 5;
            } else if (constraints.maxWidth > 900) {
              crossAxisCount = 3;
            } else if (constraints.maxWidth > 600) {
              crossAxisCount = 2;
            } else {
              crossAxisCount = 1;
            }

            double spacing = 16.0;
            return GridView.count(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: crossAxisCount == 1 ? 4.0 : (crossAxisCount == 5 ? 1.8 : 2.8),
              children: [
                _buildStatCard(
                  icon: Icons.trending_up_outlined,
                  iconColor: const Color(0xFF2563EB),
                  label: data['sales_label']?.toString().toUpperCase() ?? "TODAY'S SALES",
                  value: currencyFormat.format(todaySales),
                  valueColor: const Color(0xFF0F172A),
                  accentColor: const Color(0xFF2563EB),
                ),
                _buildStatCard(
                  icon: Icons.insights_outlined,
                  iconColor: const Color(0xFF10B981),
                  label: data['profit_label']?.toString().toUpperCase() ?? "EST. PROFIT",
                  value: currencyFormat.format(todayProfit),
                  valueColor: const Color(0xFF059669),
                  accentColor: const Color(0xFF10B981),
                ),
                _buildStatCard(
                  icon: Icons.receipt_long_outlined,
                  iconColor: const Color(0xFF7C3AED),
                  label: data['bills_label']?.toString().toUpperCase() ?? "BILLS CREATED",
                  value: todayBillCount.toString(),
                  valueColor: const Color(0xFF0F172A),
                  accentColor: const Color(0xFF7C3AED),
                ),
                _buildStatCard(
                  icon: Icons.money_outlined,
                  iconColor: const Color(0xFF16A34A),
                  label: data['cash_label']?.toString().toUpperCase() ?? "CASH COLLECTED",
                  value: currencyFormat.format(todayCash),
                  valueColor: const Color(0xFF16A34A),
                  accentColor: const Color(0xFF16A34A),
                ),
                _buildStatCard(
                  icon: Icons.qr_code_outlined,
                  iconColor: const Color(0xFF0891B2),
                  label: data['upi_label']?.toString().toUpperCase() ?? "UPI COLLECTED",
                  value: currencyFormat.format(todayUpi),
                  valueColor: const Color(0xFF0891B2),
                  accentColor: const Color(0xFF0891B2),
                ),
              ],
            );
          }),
          const SizedBox(height: 16),

          // --- Outstanding card ---
          _buildOutstandingCard(totalOutstanding),
          const SizedBox(height: 16),

          // --- Side-by-side or stacked responsive layout for Stock Status & Top Products ---
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final stockWidget = _buildStockStatusTable(data['all_stock_products'] as List? ?? [], lowStockProducts);
              final topProductsWidget = _buildTopProductsPanel(topProducts, title: data['top_label']?.toString());
              
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: stockWidget),
                    const SizedBox(width: 20),
                    Expanded(child: topProductsWidget),
                  ],
                );
              } else {
                return Column(
                  children: [
                    stockWidget,
                    const SizedBox(height: 16),
                    topProductsWidget,
                  ],
                );
              }
            },
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
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
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isPositive
                  ? const Color(0xFFEF4444).withOpacity(0.12)
                  : const Color(0xFF16A34A).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPositive ? Icons.warning_amber_outlined : Icons.check_circle_outline,
              color: isPositive ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL OUTSTANDING',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isPositive ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currencyFormat.format(totalOutstanding),
                  style: TextStyle(
                    fontSize: 22,
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

  Widget _buildStockStatusTable(List allProducts, List lowStockProducts) {
    // Sort and filter: only include products where stock <= min_stock_level (low or out of stock)
    final sorted = List<Map<String, dynamic>>.from(
      allProducts.map((p) => Map<String, dynamic>.from(p as Map))
    );
    final filtered = sorted.where((p) {
      final double stockCent = (p['total_stock_in_cent'] as num?)?.toDouble() ?? 0.0;
      final int minLevel = (p['min_stock_level'] as num?)?.toInt() ?? 5;
      return stockCent <= minLevel;
    }).toList();

    // Sort: Out of stock (stockCent <= 0) first, then low stock, then alphabetically by name
    filtered.sort((a, b) {
      final double stockA = (a['total_stock_in_cent'] as num?)?.toDouble() ?? 0.0;
      final double stockB = (b['total_stock_in_cent'] as num?)?.toDouble() ?? 0.0;
      final bool isOutA = stockA <= 0;
      final bool isOutB = stockB <= 0;
      if (isOutA != isOutB) {
        return isOutA ? -1 : 1;
      }
      return (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
    });

    final totalItems = filtered.length;
    final totalPages = (totalItems / _stockItemsPerPage).ceil().clamp(1, 99999);
    if (_stockCurrentPage > totalPages) {
      _stockCurrentPage = totalPages;
    }
    final startIndex = (_stockCurrentPage - 1) * _stockItemsPerPage;
    final endIndex = startIndex + _stockItemsPerPage;
    final paginated = totalItems == 0
        ? <Map<String, dynamic>>[]
        : filtered.sublist(
            startIndex,
            endIndex > totalItems ? totalItems : endIndex,
          );

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
                  child: const Icon(Icons.inventory_2_outlined, color: Color(0xFFF97316), size: 18),
                ),
                const SizedBox(width: 12),
                const Text(
                  'STOCK STATUS',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569), letterSpacing: 0.5),
                ),
                const Spacer(),
                if (totalItems > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_outlined, color: Color(0xFFEF4444), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '$totalItems alert${totalItems > 1 ? "s" : ""}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10)),
                    child: const Text('All Good ✓', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                  ),
              ],
            ),
          ),

          if (totalItems == 0)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF0FDF4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_outline,
                          color: Color(0xFF16A34A),
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'All stock levels healthy',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'No low stock or out of stock products detected.',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: paginated.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final product = paginated[index];
                final double stockCent = (product['total_stock_in_cent'] as num?)?.toDouble() ?? 0.0;
                final int minLevel = (product['min_stock_level'] as num?)?.toInt() ?? 5;
                final bool isOut = stockCent <= 0;
                final String brand = product['brand']?.toString() ?? '';
                final String statusLabel = isOut ? 'OUT OF STOCK' : 'LOW STOCK';
                final Color statusColor = isOut ? const Color(0xFFEF4444) : const Color(0xFFF97316);
                final Color statusBg = isOut ? const Color(0xFFFEF2F2) : const Color(0xFFFFF7ED);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              product['name']?.toString() ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (brand.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      brand.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  'Stock: ${stockCent.toStringAsFixed(1)} cent / Min: $minLevel cent',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: statusColor.withOpacity(0.2)),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (totalPages > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Page $_stockCurrentPage of $totalPages',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: const Color(0xFF475569),
                          disabledColor: const Color(0xFFCBD5E1),
                          onPressed: _stockCurrentPage > 1
                              ? () {
                                  setState(() {
                                    _stockCurrentPage--;
                                  });
                                }
                              : null,
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: const Color(0xFF475569),
                          disabledColor: const Color(0xFFCBD5E1),
                          onPressed: _stockCurrentPage < totalPages
                              ? () {
                                  setState(() {
                                    _stockCurrentPage++;
                                  });
                                }
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
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
          _loadDashboard(range: value);
        }
      },
    );
  }
}
