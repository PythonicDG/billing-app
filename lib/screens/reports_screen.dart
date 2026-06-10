import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../dashboard_provider.dart';
import '../billing_provider.dart';
import '../auth_provider.dart';
import 'products_screen.dart'; // To use AppDrawer

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  bool get wantKeepAlive => true;

  // Daily Sales Tab State
  DateTime _dailySalesDate = DateTime.now();

  // Outstanding Customers Tab State
  // (No extra local state needed, fetched on demand)

  // Stock Summary Tab State
  String _stockFilter = 'ALL'; // 'ALL' | 'LOW_STOCK'
  String _stockSortBy = 'NAME'; // 'NAME' | 'STOCK_QTY' | 'STOCK_VALUE'
  bool _stockSortAscending = true;

  // Customer Sales Tab State
  Customer? _selectedCustomer;
  DateTime _customerSalesFrom = DateTime.now().subtract(const Duration(days: 30));
  DateTime _customerSalesTo = DateTime.now();
  final _customerSearchController = TextEditingController();

  // Expansion tracking for Invoice Tables
  String? _expandedDailyInvoice;
  String? _expandedCustomerInvoice;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabSelection);

    // Initial fetch for the first tab (Daily Sales)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDailySales();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _customerSearchController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;

    final dashProvider = Provider.of<DashboardProvider>(context, listen: false);

    // Load data when shifting to a tab if not loaded yet
    if (_tabController.index == 0) {
      if (dashProvider.dailySalesData == null && !dashProvider.isDailySalesLoading) {
        _loadDailySales();
      }
    } else if (_tabController.index == 1) {
      if (dashProvider.outstandingData == null && !dashProvider.isOutstandingLoading) {
        _loadOutstandingCustomers();
      }
    } else if (_tabController.index == 2) {
      if (dashProvider.stockData == null && !dashProvider.isStockLoading) {
        _loadStockSummary();
      }
    }
  }

  // API loaders
  void _loadDailySales() {
    final formattedDate = DateFormat('yyyy-MM-dd').format(_dailySalesDate);
    Provider.of<DashboardProvider>(context, listen: false).fetchDailySales(formattedDate);
  }

  void _loadOutstandingCustomers() {
    Provider.of<DashboardProvider>(context, listen: false).fetchOutstandingCustomers();
  }

  void _loadStockSummary() {
    Provider.of<DashboardProvider>(context, listen: false).fetchStockSummary();
  }

  void _loadCustomerSales() {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer first.')),
      );
      return;
    }
    final formattedFrom = DateFormat('yyyy-MM-dd').format(_customerSalesFrom);
    final formattedTo = DateFormat('yyyy-MM-dd').format(_customerSalesTo);

    Provider.of<DashboardProvider>(context, listen: false)
        .fetchCustomerSales(_selectedCustomer!.id, formattedFrom, formattedTo);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.assessment_outlined, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text(
              'Reports & Analytics',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF2563EB),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.today_outlined), text: 'Daily Sales'),
            Tab(icon: Icon(Icons.people_outline), text: 'Outstanding Customers'),
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Stock Summary'),
            Tab(icon: Icon(Icons.person_search_outlined), text: 'Customer Sales'),
          ],
        ),
      ),
      drawer: const AppDrawer(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDailySalesTab(),
          _buildOutstandingCustomersTab(),
          _buildStockSummaryTab(),
          _buildCustomerSalesTab(),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: DAILY SALES
  // ==========================================
  Widget _buildDailySalesTab() {
    final dashProvider = Provider.of<DashboardProvider>(context);
    final data = dashProvider.dailySalesData;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter section
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Text(
                    'Select Date: ',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 14),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEFF6FF),
                      foregroundColor: const Color(0xFF2563EB),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Color(0xFF2563EB), width: 1),
                      ),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dailySalesDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null && picked != _dailySalesDate) {
                        setState(() {
                          _dailySalesDate = picked;
                          _expandedDailyInvoice = null;
                        });
                        _loadDailySales();
                      }
                    },
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(
                      DateFormat('dd MMM yyyy').format(_dailySalesDate),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh_outlined, color: Color(0xFF2563EB)),
                    onPressed: _loadDailySales,
                    tooltip: 'Refresh Data',
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (dashProvider.isDailySalesLoading && data != null)
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: LinearProgressIndicator(color: Color(0xFF2563EB), minHeight: 2),
            ),

          if (dashProvider.isDailySalesLoading && (data == null || (data['invoices'] as List).isEmpty))
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF2563EB)),
              ),
            )
          else if (dashProvider.dailySalesError != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
                    const SizedBox(height: 16),
                    Text(dashProvider.dailySalesError!, style: const TextStyle(color: Color(0xFFEF4444))),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadDailySales,
                      child: const Text('Retry'),
                    )
                  ],
                ),
              ),
            )
          else if (data == null || (data['invoices'] as List).isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    const Text(
                      'No invoices found for this date.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Total Sales',
                          currencyFormat.format(data['total_sales'] ?? 0),
                          Icons.currency_rupee,
                          const Color(0xFFEFF6FF),
                          const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSummaryCard(
                          'Cash Collected',
                          currencyFormat.format(data['total_cash'] ?? 0),
                          Icons.money,
                          const Color(0xFFECFDF5),
                          const Color(0xFF16A34A),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSummaryCard(
                          'UPI Collected',
                          currencyFormat.format(data['total_upi'] ?? 0),
                          Icons.qr_code_scanner,
                          const Color(0xFFF0FDF4),
                          const Color(0xFF15803D),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSummaryCard(
                          'Bills Created',
                          (data['bill_count'] ?? 0).toString(),
                          Icons.description_outlined,
                          const Color(0xFFFFF7ED),
                          const Color(0xFFEA580C),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Table header title
                  const Text(
                    'Invoices List',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 12),

                  // Invoices list table
                  Expanded(
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                      color: Colors.white,
                      child: ListView.builder(
                        itemCount: (data['invoices'] as List).length,
                        itemBuilder: (context, index) {
                          final invoice = data['invoices'][index] as Map<String, dynamic>;
                          final isExpanded = _expandedDailyInvoice == invoice['id'];

                          return Column(
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                title: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        invoice['invoice_number'] ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        DateFormat('hh:mm a').format(DateTime.parse(invoice['date']).toLocal()),
                                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        invoice['customer_name'] ?? 'Walk-In',
                                        style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        currencyFormat.format(invoice['total'] ?? 0),
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        currencyFormat.format(invoice['paid'] ?? 0),
                                        style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        currencyFormat.format(invoice['outstanding'] ?? 0),
                                        style: TextStyle(
                                          color: (invoice['outstanding'] ?? 0) > 0 ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                                          fontWeight: (invoice['outstanding'] ?? 0) > 0 ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: _buildStatusBadge(invoice['payment_status'] ?? ''),
                                    ),
                                    Icon(
                                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  setState(() {
                                    _expandedDailyInvoice = isExpanded ? null : invoice['id'];
                                  });
                                },
                              ),
                              if (isExpanded) _buildInvoiceExpansionPanel(invoice),
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            )
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: OUTSTANDING CUSTOMERS
  // ==========================================
  Widget _buildOutstandingCustomersTab() {
    final dashProvider = Provider.of<DashboardProvider>(context);
    final data = dashProvider.outstandingData;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dashProvider.isOutstandingLoading && data != null)
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: LinearProgressIndicator(color: Color(0xFF2563EB), minHeight: 2),
            ),
          if (dashProvider.isOutstandingLoading && (data == null || (data['customers'] as List).isEmpty))
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF2563EB)),
              ),
            )
          else if (dashProvider.outstandingError != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
                    const SizedBox(height: 16),
                    Text(dashProvider.outstandingError!, style: const TextStyle(color: Color(0xFFEF4444))),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadOutstandingCustomers,
                      child: const Text('Retry'),
                    )
                  ],
                ),
              ),
            )
          else if (data == null || (data['customers'] as List).isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified, size: 64, color: Colors.green[100]),
                    const SizedBox(height: 16),
                    const Text(
                      'All settled! No outstanding customers found.',
                      style: TextStyle(color: Color(0xFF16A34A), fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Banner
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFCA5A5), width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 40),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Total Outstanding Balance',
                                    style: TextStyle(color: Color(0xFF7F1D1D), fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    currencyFormat.format(data['total_outstanding'] ?? 0),
                                    style: const TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.w900, fontSize: 28),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${data['customer_count'] ?? 0} Customers',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Outstanding Balance by Customer',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 12),

                  // Table of customers
                  Expanded(
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                      color: Colors.white,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                            columns: const [
                              DataColumn(label: Text('Customer Name', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                              DataColumn(label: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                              DataColumn(label: Text('Unpaid Bills', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                              DataColumn(label: Text('Outstanding Amount', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                              DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                            ],
                            rows: (data['customers'] as List).map<DataRow>((c) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: const Color(0xFFFEF2F2),
                                          child: Text(
                                            c['name']?[0]?.toUpperCase() ?? 'C',
                                            style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(c['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                      ],
                                    ),
                                  ),
                                  DataCell(Text(c['phone'] ?? '', style: const TextStyle(color: Color(0xFF475569)))),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF7ED),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        (c['unpaid_bill_count'] ?? 0).toString(),
                                        style: const TextStyle(color: Color(0xFFEA580C), fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      currencyFormat.format(c['outstanding_balance'] ?? 0),
                                      style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  DataCell(
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFEFF6FF),
                                        foregroundColor: const Color(0xFF2563EB),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () {
                                        // Create a temporary Customer object to pass
                                        final cust = Customer(
                                          id: c['id'],
                                          name: c['name'],
                                          phone: c['phone'],
                                          outstandingBalance: (c['outstanding_balance'] as num).toDouble(),
                                        );
                                        // Navigate to Ledgers screen
                                        Navigator.pushReplacementNamed(context, '/ledger', arguments: cust);
                                      },
                                      icon: const Icon(Icons.account_balance_wallet_outlined, size: 14),
                                      label: const Text('View Ledger', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: STOCK SUMMARY
  // ==========================================
  Widget _buildStockSummaryTab() {
    final dashProvider = Provider.of<DashboardProvider>(context);
    final data = dashProvider.stockData;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dashProvider.isStockLoading && data != null)
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: LinearProgressIndicator(color: Color(0xFF2563EB), minHeight: 2),
            ),
          if (dashProvider.isStockLoading && (data == null || (data['products'] as List).isEmpty))
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF2563EB)),
              ),
            )
          else if (dashProvider.stockError != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
                    const SizedBox(height: 16),
                    Text(dashProvider.stockError!, style: const TextStyle(color: Color(0xFFEF4444))),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadStockSummary,
                      child: const Text('Retry'),
                    )
                  ],
                ),
              ),
            )
          else if (data == null)
            const SizedBox.shrink()
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Total Products',
                          (data['total_products'] ?? 0).toString(),
                          Icons.inventory_2_outlined,
                          const Color(0xFFEFF6FF),
                          const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSummaryCard(
                          'Low Stock Items',
                          (data['low_stock_count'] ?? 0).toString(),
                          Icons.warning_amber_outlined,
                          (data['low_stock_count'] ?? 0) > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                          (data['low_stock_count'] ?? 0) > 0 ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSummaryCard(
                          'Total Inventory Value',
                          currencyFormat.format(data['total_stock_value'] ?? 0),
                          Icons.auto_graph_outlined,
                          const Color(0xFFECFDF5),
                          const Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Filter & Sorting controls
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Text('Filter: ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('All Products'),
                            selected: _stockFilter == 'ALL',
                            onSelected: (val) {
                              if (val) setState(() => _stockFilter = 'ALL');
                            },
                            selectedColor: const Color(0xFFEFF6FF),
                            labelStyle: TextStyle(
                              color: _stockFilter == 'ALL' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Low Stock Only'),
                            selected: _stockFilter == 'LOW_STOCK',
                            onSelected: (val) {
                              if (val) setState(() => _stockFilter = 'LOW_STOCK');
                            },
                            selectedColor: const Color(0xFFFEF2F2),
                            labelStyle: TextStyle(
                              color: _stockFilter == 'LOW_STOCK' ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          const Text('Sort By: ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: _stockSortBy,
                            underline: const SizedBox.shrink(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  if (_stockSortBy == val) {
                                    _stockSortAscending = !_stockSortAscending;
                                  } else {
                                    _stockSortBy = val;
                                    _stockSortAscending = true;
                                  }
                                });
                              }
                            },
                            items: const [
                              DropdownMenuItem(value: 'NAME', child: Text('Product Name')),
                              DropdownMenuItem(value: 'STOCK_QTY', child: Text('Stock Quantity')),
                              DropdownMenuItem(value: 'STOCK_VALUE', child: Text('Inventory Value')),
                            ],
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: Icon(
                              _stockSortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                              size: 16,
                              color: const Color(0xFF2563EB),
                            ),
                            onPressed: () {
                              setState(() {
                                _stockSortAscending = !_stockSortAscending;
                              });
                            },
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stock Table
                  Expanded(
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                      color: Colors.white,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                            columns: const [
                              DataColumn(label: Text('Product Name', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Brand', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Stock Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Min Level', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Purchase Price', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Selling Price', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Inventory Value', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: _processStockProducts(data['products'] as List).map<DataRow>((p) {
                              final isLow = p['is_low_stock'] == true;

                              return DataRow(
                                cells: [
                                  DataCell(Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(Text(p['brand'] ?? '', style: const TextStyle(color: Color(0xFF64748B)))),
                                  DataCell(Text('${p['stock_quantity']}', style: TextStyle(fontWeight: isLow ? FontWeight.bold : FontWeight.normal, color: isLow ? const Color(0xFFEF4444) : const Color(0xFF0F172A)))),
                                  DataCell(Text('${p['min_stock_level']}', style: const TextStyle(color: Color(0xFF64748B)))),
                                  DataCell(Text(currencyFormat.format(p['purchase_price'] ?? 0))),
                                  DataCell(Text(currencyFormat.format(p['selling_price'] ?? 0))),
                                  DataCell(Text(currencyFormat.format(p['stock_value'] ?? 0), style: const TextStyle(fontWeight: FontWeight.w600))),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isLow ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isLow ? 'Low Stock' : 'In Stock',
                                        style: TextStyle(
                                          color: isLow ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<dynamic> _processStockProducts(List<dynamic> products) {
    // 1. Filter
    List<dynamic> list = products;
    if (_stockFilter == 'LOW_STOCK') {
      list = list.where((p) => p['is_low_stock'] == true).toList();
    } else {
      list = List.from(list);
    }

    // 2. Sort
    list.sort((a, b) {
      dynamic valA;
      dynamic valB;

      if (_stockSortBy == 'NAME') {
        valA = (a['name'] ?? '').toString().toLowerCase();
        valB = (b['name'] ?? '').toString().toLowerCase();
      } else if (_stockSortBy == 'STOCK_QTY') {
        valA = a['stock_quantity'] ?? 0;
        valB = b['stock_quantity'] ?? 0;
      } else if (_stockSortBy == 'STOCK_VALUE') {
        valA = a['stock_value'] ?? 0.0;
        valB = b['stock_value'] ?? 0.0;
      }

      int comparison = 0;
      if (valA is String && valB is String) {
        comparison = valA.compareTo(valB);
      } else if (valA is num && valB is num) {
        comparison = valA.compareTo(valB);
      }

      return _stockSortAscending ? comparison : -comparison;
    });

    return list;
  }

  // ==========================================
  // TAB 4: CUSTOMER SALES
  // ==========================================
  Widget _buildCustomerSalesTab() {
    final billingProvider = Provider.of<BillingProvider>(context, listen: false);
    final dashProvider = Provider.of<DashboardProvider>(context);
    final data = dashProvider.customerSalesData;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selection parameters card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Autocomplete<Customer>(
                      optionsBuilder: (TextEditingValue textEditingValue) async {
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<Customer>.empty();
                        }
                        return await billingProvider.searchCustomers(textEditingValue.text);
                      },
                      displayStringForOption: (Customer option) => '${option.name} (${option.phone})',
                      onSelected: (Customer selection) {
                        setState(() {
                          _selectedCustomer = selection;
                          _customerSearchController.text = selection.name;
                        });
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        if (_selectedCustomer == null && controller.text.isNotEmpty) {
                          controller.clear();
                        }
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            labelText: 'Search Customer',
                            prefixIcon: const Icon(Icons.person_outline),
                            suffixIcon: _selectedCustomer != null
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setState(() {
                                        _selectedCustomer = null;
                                        controller.clear();
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          initialDateRange: DateTimeRange(start: _customerSalesFrom, end: _customerSalesTo),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() {
                            _customerSalesFrom = picked.start;
                            _customerSalesTo = picked.end;
                          });
                        }
                      },
                      icon: const Icon(Icons.date_range, size: 16, color: Color(0xFF64748B)),
                      label: Text(
                        '${DateFormat('dd MMM').format(_customerSalesFrom)} - ${DateFormat('dd MMM yyyy').format(_customerSalesTo)}',
                        style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w500, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: _loadCustomerSales,
                    child: const Text('Generate Report', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (dashProvider.isCustomerSalesLoading && data != null)
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: LinearProgressIndicator(color: Color(0xFF2563EB), minHeight: 2),
            ),

          if (dashProvider.isCustomerSalesLoading && (data == null || (data['invoices'] as List).isEmpty))
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF2563EB)),
              ),
            )
          else if (dashProvider.customerSalesError != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
                    const SizedBox(height: 16),
                    Text(dashProvider.customerSalesError!, style: const TextStyle(color: Color(0xFFEF4444))),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadCustomerSales,
                      child: const Text('Retry'),
                    )
                  ],
                ),
              ),
            )
          else if (data == null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_search_outlined, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    const Text(
                      'Search for a customer and select a date range to generate a report.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            )
          else if ((data['invoices'] as List).isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'No invoices found for ${data['customer_name']} in this period.',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Total Billed',
                          currencyFormat.format(data['total_billed'] ?? 0),
                          Icons.receipt_long_outlined,
                          const Color(0xFFEFF6FF),
                          const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSummaryCard(
                          'Total Paid',
                          currencyFormat.format(data['total_paid'] ?? 0),
                          Icons.check_circle_outline,
                          const Color(0xFFECFDF5),
                          const Color(0xFF16A34A),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSummaryCard(
                          'Total Outstanding',
                          currencyFormat.format(data['total_outstanding'] ?? 0),
                          Icons.warning_amber_outlined,
                          (data['total_outstanding'] ?? 0) > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                          (data['total_outstanding'] ?? 0) > 0 ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSummaryCard(
                          'Total Invoices',
                          (data['invoice_count'] ?? 0).toString(),
                          Icons.description_outlined,
                          const Color(0xFFFFF7ED),
                          const Color(0xFFEA580C),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Invoices for ${data['customer_name']}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 12),

                  // Invoices List
                  Expanded(
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                      color: Colors.white,
                      child: ListView.builder(
                        itemCount: (data['invoices'] as List).length,
                        itemBuilder: (context, index) {
                          final invoice = data['invoices'][index] as Map<String, dynamic>;
                          final isExpanded = _expandedCustomerInvoice == invoice['id'];

                          return Column(
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                title: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        invoice['invoice_number'] ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(invoice['date']).toLocal()),
                                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        currencyFormat.format(invoice['total'] ?? 0),
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        currencyFormat.format(invoice['paid'] ?? 0),
                                        style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        currencyFormat.format(invoice['outstanding'] ?? 0),
                                        style: TextStyle(
                                          color: (invoice['outstanding'] ?? 0) > 0 ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                                          fontWeight: (invoice['outstanding'] ?? 0) > 0 ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: _buildStatusBadge(invoice['payment_status'] ?? ''),
                                    ),
                                    Icon(
                                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  setState(() {
                                    _expandedCustomerInvoice = isExpanded ? null : invoice['id'];
                                  });
                                },
                              ),
                              if (isExpanded) _buildInvoiceExpansionPanel(invoice),
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================

  Widget _buildSummaryCard(String title, String value, IconData icon, Color bgColor, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    Color bgColor;

    switch (status) {
      case 'PAID':
        color = const Color(0xFF16A34A);
        bgColor = const Color(0xFFECFDF5);
        break;
      case 'PARTIAL':
        color = const Color(0xFFEA580C);
        bgColor = const Color(0xFFFFF7ED);
        break;
      default: // UNPAID
        color = const Color(0xFFDC2626);
        bgColor = const Color(0xFFFEF2F2);
        break;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          status,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildInvoiceExpansionPanel(Map<String, dynamic> invoice) {
    final items = invoice['items'] as List? ?? [];
    final payments = invoice['payments'] as List? ?? [];

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Items table
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ITEMS LISTED',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, idx) {
                      final item = items[idx] as Map<String, dynamic>;
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        title: Text(item['product_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${item['quantity']} ${item['unit']} x ${currencyFormat.format(item['unit_price'])}'),
                        trailing: Text(
                          currencyFormat.format(item['total_price'] ?? 0),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Payments logs
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PAYMENT TRANSACTIONS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8),
                ),
                const SizedBox(height: 8),
                if (payments.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('No transactions recorded.', style: TextStyle(color: Color(0xFF64748B), fontStyle: FontStyle.italic, fontSize: 13)),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: payments.length,
                      itemBuilder: (context, idx) {
                        final payment = payments[idx] as Map<String, dynamic>;
                        final date = DateTime.tryParse(payment['payment_date'] ?? '')?.toLocal();
                        final dateStr = date != null ? DateFormat('dd MMM yyyy').format(date) : '';

                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(payment['mode'] ?? 'CASH', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(currencyFormat.format(payment['amount'] ?? 0), style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                            ],
                          ),
                          subtitle: Text(
                            [dateStr, payment['notes'] as String?].where((s) => s != null && s.isNotEmpty).join(' - '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
