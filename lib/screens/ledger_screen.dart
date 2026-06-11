import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:printing/printing.dart';
import '../billing_provider.dart';
import '../dashboard_provider.dart';
import '../widgets/app_drawer.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  _LedgerScreenState createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  final _searchController = TextEditingController();
  List<Customer> _customers = [];
  bool _isLoadingCustomers = false;
  Customer? _selectedCustomer;
  Map<String, dynamic>? _selectedLedger;
  bool _isLoadingLedger = false;
  Timer? _debounce;

  // Filter and Sorting State
  String _filterOption = 'ALL'; // 'ALL' or 'OUTSTANDING'
  String _invoiceFilter = 'ALL'; // 'ALL' or 'UNPAID_PARTIAL'
  String _invoiceSort = 'NEWEST'; // 'NEWEST', 'OLDEST', 'HIGHEST_OUTSTANDING'
  
  // Expanded invoice tracking
  String? _expandedInvoiceNumber;

  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs.');

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Customer) {
        _selectCustomer(args);
      }
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _fetchCustomers([String query = '']) {
    setState(() {
      _isLoadingCustomers = true;
    });
    Provider.of<BillingProvider>(context, listen: false)
        .searchCustomers(query)
        .then((list) {
      setState(() {
        _customers = list;
        _isLoadingCustomers = false;
        
        // Update selected customer if it exists in the new list to ensure it has latest balance
        if (_selectedCustomer != null) {
          try {
            _selectedCustomer = list.firstWhere((c) => c.id == _selectedCustomer!.id);
          } catch (e) {
            // Keep existing if not found in filtered list
          }
        }
      });
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _fetchCustomers(query);
    });
  }

  void _selectCustomer(Customer customer) {
    setState(() {
      _selectedCustomer = customer;
      _isLoadingLedger = true;
      _selectedLedger = null;
      _expandedInvoiceNumber = null;
    });
    Provider.of<BillingProvider>(context, listen: false)
        .getCustomerLedger(customer.id)
        .then((ledger) {
      setState(() {
        _selectedLedger = ledger;
        _isLoadingLedger = false;
      });
    });
  }

  void _sendWhatsAppReminder(Customer customer) async {
    final outstanding = customer.outstandingBalance;
    final message = "Hi ${customer.name}, your outstanding balance at Fataka App is ${currencyFormat.format(outstanding)}. Please settle your pending bills. Thank you!";
    final encodedMessage = Uri.encodeComponent(message);
    // Format phone number to be international if needed, but for India standard 10 digits usually works with wa.me
    String phone = customer.phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.length == 10) phone = "91$phone";
    
    final url = "https://wa.me/$phone?text=$encodedMessage";
    
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp')),
        );
      }
    }
  }

  void _showBulkPaymentDialog() {
    if (_selectedCustomer == null) return;
    
    final outstanding = double.tryParse(_selectedLedger?['total_outstanding']?.toString() ?? '0.0') ?? 0.0;
    if (outstanding <= 0) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No outstanding balance to settle.')),
      );
      return;
    }

    final amountController = TextEditingController(text: outstanding.toStringAsFixed(2));
    final notesController = TextEditingController();
    String selectedMode = 'CASH';

    showDialog(
      context: context,
      builder: (context) {
        return CallbackShortcuts(
          bindings: {
            SingleActivator(LogicalKeyboardKey.escape): () {
              Navigator.pop(context);
            },
          },
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                title: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    const Text(
                      'Record Bulk Payment',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Outstanding: ${currencyFormat.format(outstanding)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF4444), fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Payment Amount',
                          prefixText: 'Rs. ',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          helperText: 'This amount will be applied to the oldest bills first.',
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setDialogState(() => selectedMode = 'CASH'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: selectedMode == 'CASH' ? const Color(0xFFEFF6FF) : Colors.white,
                                  border: Border.all(color: selectedMode == 'CASH' ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.money, color: selectedMode == 'CASH' ? const Color(0xFF2563EB) : const Color(0xFF64748B), size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      'CASH',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: selectedMode == 'CASH' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () => setDialogState(() => selectedMode = 'UPI'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: selectedMode == 'UPI' ? const Color(0xFFEFF6FF) : Colors.white,
                                  border: Border.all(color: selectedMode == 'UPI' ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.qr_code, color: selectedMode == 'UPI' ? const Color(0xFF2563EB) : const Color(0xFF64748B), size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      'UPI',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: selectedMode == 'UPI' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Notes (Optional)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL', style: TextStyle(color: Color(0xFF64748B))),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F2C59),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      minimumSize: const Size(120, 40),
                    ),
                    onPressed: () {
                      final amount = double.tryParse(amountController.text) ?? 0.0;
                      if (amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invalid payment amount')),
                        );
                        return;
                      }
                      Navigator.pop(context);
                      setState(() {
                        _isLoadingLedger = true;
                      });
                      Provider.of<BillingProvider>(context, listen: false)
                          .recordBulkPayment(_selectedCustomer!.id, amount, selectedMode, notesController.text)
                          .then((success) {
                        if (!mounted) return;
                        if (success) {
                          Provider.of<DashboardProvider>(context, listen: false).refreshAll();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bulk payment recorded successfully')),
                          );
                          
                          // Refresh customer list to update outstanding balance in the sidebar/list
                          _fetchCustomers(_searchController.text);
                          
                          if (_selectedCustomer != null) {
                            _selectCustomer(_selectedCustomer!);
                          }
                        } else {
                          setState(() {
                            _isLoadingLedger = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to record bulk payment')),
                          );
                        }
                      });
                    },
                    child: const Text('RECORD PAYMENT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _showRecordPaymentDialog(Map<String, dynamic> bill) {
    final outstanding = double.tryParse(bill['outstanding'].toString()) ?? 0.0;
    final amountController = TextEditingController(text: outstanding.toStringAsFixed(2));
    final notesController = TextEditingController();
    String selectedMode = 'CASH';

    showDialog(
      context: context,
      builder: (context) {
        return CallbackShortcuts(
          bindings: {
            SingleActivator(LogicalKeyboardKey.escape): () {
              Navigator.pop(context);
            },
          },
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              const buttonText = 'RECORD';

              return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              title: Row(
                children: [
                  const Icon(Icons.payment_outlined, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Text(
                    'Record Payment - ${bill['invoice_number']}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Outstanding Balance: ${currencyFormat.format(outstanding)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF4444), fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (val) {
                        setDialogState(() {});
                      },
                      decoration: InputDecoration(
                        labelText: 'Payment Amount',
                        prefixText: 'Rs. ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setDialogState(() => selectedMode = 'CASH'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: selectedMode == 'CASH' ? const Color(0xFFEFF6FF) : Colors.white,
                                border: Border.all(color: selectedMode == 'CASH' ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.money, color: selectedMode == 'CASH' ? const Color(0xFF2563EB) : const Color(0xFF64748B), size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'CASH',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: selectedMode == 'CASH' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => setDialogState(() => selectedMode = 'UPI'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: selectedMode == 'UPI' ? const Color(0xFFEFF6FF) : Colors.white,
                                border: Border.all(color: selectedMode == 'UPI' ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.qr_code, color: selectedMode == 'UPI' ? const Color(0xFF2563EB) : const Color(0xFF64748B), size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'UPI',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: selectedMode == 'UPI' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F2C59),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(120, 40),
                  ),
                  onPressed: () {
                    final amount = double.tryParse(amountController.text) ?? 0.0;
                    if (amount <= 0 || amount > outstanding) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invalid payment amount')),
                      );
                      return;
                    }
                    Navigator.pop(context);
                    setState(() {
                      _isLoadingLedger = true;
                    });
                    Provider.of<BillingProvider>(context, listen: false)
                        .recordPayment(bill['id'], amount, selectedMode, notesController.text)
                        .then((success) {
                      if (success) {
                        Provider.of<DashboardProvider>(context, listen: false).refreshAll();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Payment recorded successfully')),
                        );
                        
                        // Refresh customer list to update outstanding balance in the sidebar/list
                        _fetchCustomers(_searchController.text);
                        
                        if (_selectedCustomer != null) {
                          _selectCustomer(_selectedCustomer!);
                        }
                      } else {
                        setState(() {
                          _isLoadingLedger = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to record payment')),
                        );
                      }
                    });
                  },
                  child: Text(buttonText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

  Widget _buildCustomerList() {
    // 1. Filter
    final List<Customer> filteredCustomers = _customers.where((c) {
      if (_filterOption == 'OUTSTANDING') {
        return c.outstandingBalance > 0;
      }
      return true;
    }).toList();

    // Separate into sections for a cleaner layout
    final outstanding = filteredCustomers.where((c) => c.outstandingBalance > 0).toList();
    final settled = filteredCustomers.where((c) => c.outstandingBalance == 0).toList();

    // Sort: Outstanding by amount (highest first), Settled alphabetically
    outstanding.sort((a, b) => b.outstandingBalance.compareTo(a.outstandingBalance));
    settled.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Container(
      color: const Color(0xFFF8FAFC), // Subtle background for the sidebar
      child: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search customer...',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF2563EB), size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildFilterToggle('ALL', 'All Customers'),
                      _buildFilterToggle('OUTSTANDING', 'Outstanding'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoadingCustomers
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB), strokeWidth: 3))
                : filteredCustomers.isEmpty
                    ? _buildEmptyState()
                    : ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          if (outstanding.isNotEmpty) ...[
                             _buildSectionHeader('DUE NOW', Icons.priority_high_rounded, const Color(0xFFEF4444)),
                             ...outstanding.map((c) => _buildCustomerTile(c)),
                          ],
                          if (settled.isNotEmpty && _filterOption == 'ALL') ...[
                             const SizedBox(height: 16),
                             _buildSectionHeader('FULLY SETTLED', Icons.check_circle_rounded, const Color(0xFF10B981)),
                             ...settled.map((c) => _buildCustomerTile(c)),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToggle(String option, String label) {
    final isSelected = _filterOption == option;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _filterOption = option),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    const BoxShadow(
                      color: Color(0x0F000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: color.withOpacity(0.15), thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_rounded, size: 48, color: const Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          const Text(
            'No customers found',
            style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerTile(Customer customer) {
    final isSelected = _selectedCustomer?.id == customer.id;
    final isOutstanding = customer.outstandingBalance > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFFBFDBFE) : Colors.transparent,
          width: 1,
        ),
        boxShadow: isSelected
            ? null
            : [
                const BoxShadow(
                  color: Color(0x05000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () => _selectCustomer(customer),
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: isOutstanding 
                  ? const Color(0xFFFEE2E2) 
                  : (isSelected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9)),
              radius: 20,
              child: Text(
                customer.name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: isOutstanding 
                      ? const Color(0xFFEF4444) 
                      : (isSelected ? Colors.white : const Color(0xFF475569)),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (!isOutstanding)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 14),
                ),
              ),
          ],
        ),
        title: Text(
          customer.name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 14,
            color: const Color(0xFF0F172A),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          customer.phone,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isOutstanding) ...[
              Text(
                currencyFormat.format(customer.outstandingBalance),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFEF4444),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildQuickAction(
                    icon: Icons.message_rounded,
                    color: const Color(0xFF25D366),
                    onTap: () => _sendWhatsAppReminder(customer),
                    tooltip: 'Send Reminder',
                  ),
                  const SizedBox(width: 10),
                  _buildQuickAction(
                    icon: Icons.add_card_rounded,
                    color: const Color(0xFF2563EB),
                    onTap: () {
                      _selectCustomer(customer);
                      Future.delayed(const Duration(milliseconds: 300), () {
                        _showBulkPaymentDialog();
                      });
                    },
                    tooltip: 'Record Payment',
                  ),
                ],
              ),
            ] else
               const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({required IconData icon, required Color color, required VoidCallback onTap, required String tooltip}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Icon(icon, size: 13, color: color),
      ),
    );
  }

  Widget _buildLedgerDetail() {
    if (_selectedCustomer == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Color(0xFF94A3B8)),
            SizedBox(height: 16),
            Text(
              'Select a Customer to view outstanding ledger details',
              style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    if (_isLoadingLedger) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));
    }

    if (_selectedLedger == null) {
      return const Center(child: Text('Failed to load ledger information.', style: TextStyle(color: Color(0xFFEF4444))));
    }

    final bills = _selectedLedger!['bills'] as List? ?? [];
    
    // Compute Summary Stats
    double totalBilled = 0.0;
    double totalPaid = 0.0;
    double calculatedOutstanding = 0.0;
    for (var bill in bills) {
      totalBilled += double.tryParse(bill['total'].toString()) ?? 0.0;
      totalPaid += double.tryParse(bill['paid'].toString()) ?? 0.0;
      calculatedOutstanding += double.tryParse(bill['outstanding'].toString()) ?? 0.0;
    }

    // Apply Filter on Invoice
    final List<dynamic> filteredBills = bills.where((bill) {
      final outstandingVal = double.tryParse(bill['outstanding'].toString()) ?? 0.0;
      if (_invoiceFilter == 'UNPAID_PARTIAL') {
        return outstandingVal > 0;
      }
      return true;
    }).toList();

    // Apply Sorting on Invoice
    filteredBills.sort((a, b) {
      if (_invoiceSort == 'NEWEST') {
        return DateTime.parse(b['date']).compareTo(DateTime.parse(a['date']));
      } else if (_invoiceSort == 'OLDEST') {
        return DateTime.parse(a['date']).compareTo(DateTime.parse(b['date']));
      } else if (_invoiceSort == 'HIGHEST_OUTSTANDING') {
        final outstandingA = double.tryParse(a['outstanding'].toString()) ?? 0.0;
        final outstandingB = double.tryParse(b['outstanding'].toString()) ?? 0.0;
        return outstandingB.compareTo(outstandingA);
      }
      return 0;
    });

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer Name/Phone Panel with Actions (Card Style)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                const BoxShadow(
                  color: Color(0x05000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Avatar for consistent look with the list
                CircleAvatar(
                  backgroundColor: (calculatedOutstanding > 0) ? const Color(0xFFFEE2E2) : const Color(0xFF2563EB),
                  radius: 24,
                  child: Text(
                    (_selectedLedger!['customer_name'] as String? ?? 'C').substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: (calculatedOutstanding > 0) ? const Color(0xFFEF4444) : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedLedger!['customer_name'] ?? '',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Phone: ${_selectedLedger!['customer_phone'] ?? ''}',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _showStatementPreviewDialog,
                      icon: const Icon(Icons.description_outlined, size: 18, color: Colors.white),
                      label: const Text('STATEMENT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                    if (calculatedOutstanding > 0)
                      ElevatedButton.icon(
                        onPressed: _showBulkPaymentDialog,
                        icon: const Icon(Icons.account_balance_wallet_outlined, size: 18, color: Colors.white),
                        label: const Text('RECORD BULK PAYMENT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          
          // Proper Summary Bar Card (Sticky)
          Container(
            margin: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _invoiceFilter = 'ALL'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TOTAL BILLED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                        const SizedBox(height: 4),
                        Text(
                          currencyFormat.format(totalBilled),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        if (_invoiceFilter == 'ALL')
                           Container(height: 2, width: 40, color: const Color(0xFF2563EB), margin: const EdgeInsets.only(top: 4)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TOTAL PAID', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormat.format(totalPaid),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _invoiceFilter = 'UNPAID_PARTIAL'),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: calculatedOutstanding > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _invoiceFilter == 'UNPAID_PARTIAL' ? const Color(0xFFEF4444) : (calculatedOutstanding > 0 ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC))),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OUTSTANDING',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: calculatedOutstanding > 0 ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currencyFormat.format(calculatedOutstanding),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: calculatedOutstanding > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search, Filter and Sort Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Filter Dropdown
                Row(
                  children: [
                    const Text('Filter: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    DropdownButton<String>(
                      value: _invoiceFilter,
                      underline: Container(),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Bills')),
                        DropdownMenuItem(value: 'UNPAID_PARTIAL', child: Text('Unpaid/Partial')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _invoiceFilter = val);
                      },
                    ),
                  ],
                ),
                // Sort Dropdown
                Row(
                  children: [
                    const Text('Sort: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    DropdownButton<String>(
                      value: _invoiceSort,
                      underline: Container(),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                      items: const [
                        DropdownMenuItem(value: 'NEWEST', child: Text('Newest First')),
                        DropdownMenuItem(value: 'OLDEST', child: Text('Oldest First')),
                        DropdownMenuItem(value: 'HIGHEST_OUTSTANDING', child: Text('Highest Outstanding')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _invoiceSort = val);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Custom Expandable Table-like Rows
          Expanded(
            child: filteredBills.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.receipt_long_outlined, size: 64, color: Color(0xFF94A3B8)),
                        SizedBox(height: 16),
                        Text(
                          'No invoices found for this customer',
                          style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Header Card Style
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: const [
                            Expanded(flex: 3, child: Text('DATE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                            Expanded(flex: 3, child: Text('BILL NUMBER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                            Expanded(flex: 3, child: Text('TOTAL AMOUNT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                            Expanded(flex: 3, child: Text('PAID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                            Expanded(flex: 3, child: Text('OUTSTANDING', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                            Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                            Expanded(flex: 2, child: Text('PREVIEW', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                          ],
                        ),
                      ),
                      
                      // Rows List
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: filteredBills.length,
                          itemBuilder: (context, index) {
                            final bill = filteredBills[index];
                            final isExpanded = _expandedInvoiceNumber == bill['invoice_number'];
                            final dateStr = DateFormat('dd MMM yyyy').format(DateTime.parse(bill['date']).toLocal());
                            final total = double.tryParse(bill['total'].toString()) ?? 0.0;
                            final paid = double.tryParse(bill['paid'].toString()) ?? 0.0;
                            final outstanding = double.tryParse(bill['outstanding'].toString()) ?? 0.0;
                            
                            // Status Badge
                            String statusLabel = 'PAID';
                            Color badgeBg = const Color(0xFFDCFCE7);
                            Color badgeText = const Color(0xFF16A34A);
                            if (outstanding > 0) {
                              if (paid > 0) {
                                statusLabel = 'PARTIAL';
                                badgeBg = const Color(0xFFFFEDD5);
                                badgeText = const Color(0xFFF97316);
                              } else {
                                statusLabel = 'UNPAID';
                                badgeBg = const Color(0xFFFEE2E2);
                                badgeText = const Color(0xFFEF4444);
                              }
                            }

                            final payments = bill['payments'] as List? ?? [];
                            final double totalPaid = double.tryParse(bill['paid'].toString()) ?? 0.0;
                            
                            // Calculate sum of recorded payments in database
                            double recordedPaymentsSum = 0.0;
                            for (var p in payments) {
                              recordedPaymentsSum += double.tryParse(p['amount']?.toString() ?? '0.0') ?? 0.0;
                            }
                            
                            // Virtualized initial payment
                            final double initialPaid = totalPaid - recordedPaymentsSum;
                            
                            // Create unified payments list
                            final List<Map<String, dynamic>> unifiedPayments = [];
                            if (initialPaid > 0.01) {
                              unifiedPayments.add({
                                'payment_date': bill['date'],
                                'amount': initialPaid,
                                'mode': bill['payment_method']?.toString().toUpperCase() ?? 'CASH',
                                'notes': 'Paid at invoice creation',
                              });
                            }
                            for (var p in payments) {
                              unifiedPayments.add({
                                'payment_date': p['payment_date'],
                                'amount': double.tryParse(p['amount']?.toString() ?? '0.0') ?? 0.0,
                                'mode': p['mode']?.toString().toUpperCase() ?? 'CASH',
                                'notes': p['notes']?.toString() ?? '',
                              });
                            }

                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isExpanded ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                                boxShadow: [
                                  const BoxShadow(
                                    color: Color(0x05000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Column(
                                  children: [
                                    // Clickable Header Row
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _expandedInvoiceNumber = isExpanded ? null : bill['invoice_number'];
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                        child: Row(
                                          children: [
                                            Expanded(flex: 3, child: Text(dateStr, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)))),
                                            Expanded(flex: 3, child: Text(bill['invoice_number'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)))),
                                            Expanded(flex: 3, child: Text(currencyFormat.format(total), style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)))),
                                            Expanded(flex: 3, child: Text(currencyFormat.format(paid), style: const TextStyle(fontSize: 13, color: Color(0xFF16A34A)))),
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                currencyFormat.format(outstanding),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: outstanding > 0 ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Container(
                                                  width: 80,
                                                  height: 24,
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                    color: badgeBg,
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Text(
                                                    statusLabel,
                                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeText),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: GestureDetector(
                                                  onTap: () {}, // Prevents expansion/collapse of the row
                                                  child: PopupMenuButton<String>(
                                                    icon: const Icon(Icons.visibility_outlined, size: 20, color: Color(0xFF64748B)),
                                                    tooltip: 'Preview Invoice',
                                                    onSelected: (value) async {
                                                      final provider = Provider.of<BillingProvider>(context, listen: false);
                                                      final invoiceId = bill['id'].toString();
                                                      if (value == 'view') {
                                                        if (context.mounted) {
                                                          _showPdfPreviewDialog(context, invoiceId, bill['invoice_number'].toString());
                                                        }
                                                      } else if (value == 'download') {
                                                        final url = await provider.getInvoicePdfUrl(invoiceId);
                                                        if (context.mounted) _launchInvoiceUrl(context, url, inApp: false);
                                                      } else if (value == 'print') {
                                                        final url = await provider.getInvoicePrintHtmlUrl(invoiceId);
                                                        if (context.mounted && url != null) {
                                                          final printUrl = '$url&autoprint=true';
                                                          _launchInvoiceUrl(context, printUrl, inApp: false);
                                                        }
                                                      } else if (value == 'delete') {
                                                        if (context.mounted) {
                                                          _showDeleteConfirmationDialog(context, invoiceId, bill['invoice_number'].toString());
                                                        }
                                                      }
                                                    },
                                                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                                      const PopupMenuItem<String>(
                                                        value: 'view',
                                                        height: 36,
                                                        child: Row(
                                                          children: [
                                                            Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF64748B)),
                                                            SizedBox(width: 8),
                                                            Text('View inside app', style: TextStyle(fontSize: 12, color: Color(0xFF1E293B))),
                                                          ],
                                                        ),
                                                      ),
                                                      const PopupMenuItem<String>(
                                                        value: 'download',
                                                        height: 36,
                                                        child: Row(
                                                          children: [
                                                            Icon(Icons.file_download_outlined, size: 16, color: Color(0xFF64748B)),
                                                            SizedBox(width: 8),
                                                            Text('Download PDF', style: TextStyle(fontSize: 12, color: Color(0xFF1E293B))),
                                                          ],
                                                        ),
                                                      ),
                                                      const PopupMenuItem<String>(
                                                        value: 'print',
                                                        height: 36,
                                                        child: Row(
                                                          children: [
                                                            Icon(Icons.print_outlined, size: 16, color: Color(0xFF64748B)),
                                                            SizedBox(width: 8),
                                                            Text('Print', style: TextStyle(fontSize: 12, color: Color(0xFF1E293B))),
                                                          ],
                                                        ),
                                                      ),
                                                      const PopupMenuDivider(),
                                                      const PopupMenuItem<String>(
                                                        value: 'delete',
                                                        height: 36,
                                                        child: Row(
                                                          children: [
                                                            Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                                                            SizedBox(width: 8),
                                                            Text('Delete Bill', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    
                                    // Inline Expanded Payment History & Action Panel
                                    if (isExpanded)
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        color: const Color(0xFFF1F5F9).withOpacity(0.5),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text(
                                                  'PAYMENT HISTORY',
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                                ),
                                                if (outstanding > 0)
                                                  ElevatedButton.icon(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFF0F2C59),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    ),
                                                    onPressed: () => _showRecordPaymentDialog(bill),
                                                    icon: const Icon(Icons.add, size: 14, color: Colors.white),
                                                    label: const Text(
                                                      'Add Payment',
                                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            if (unifiedPayments.isEmpty)
                                              const Padding(
                                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                                child: Text('No payments recorded for this invoice.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                              )
                                            else
                                              Table(
                                                border: TableBorder.all(color: const Color(0xFFE2E8F0), width: 1, borderRadius: BorderRadius.circular(6)),
                                                columnWidths: const {
                                                  0: FlexColumnWidth(3),
                                                  1: FlexColumnWidth(3),
                                                  2: FlexColumnWidth(2),
                                                  3: FlexColumnWidth(4),
                                                },
                                                children: [
                                                  TableRow(
                                                    decoration: const BoxDecoration(color: Color(0xFFE2E8F0)),
                                                    children: const [
                                                      Padding(padding: EdgeInsets.all(8.0), child: Text('DATE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                                                      Padding(padding: EdgeInsets.all(8.0), child: Text('AMOUNT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                                                      Padding(padding: EdgeInsets.all(8.0), child: Text('MODE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                                                      Padding(padding: EdgeInsets.all(8.0), child: Text('NOTES', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                                                    ],
                                                  ),
                                                  ...unifiedPayments.map((p) {
                                                    final paymentDateRaw = p['payment_date'];
                                                     final paymentDateTime = paymentDateRaw != null
                                                        ? (DateTime.tryParse(paymentDateRaw.toString())?.toLocal() ?? DateTime.now())
                                                        : DateTime.now();
                                                    final pDateStr = DateFormat('dd MMM yyyy HH:mm').format(paymentDateTime);
                                                    final pAmt = double.tryParse(p['amount'].toString()) ?? 0.0;
                                                    return TableRow(
                                                      children: [
                                                        Padding(padding: const EdgeInsets.all(8.0), child: Text(pDateStr, style: const TextStyle(fontSize: 11))),
                                                        Padding(padding: const EdgeInsets.all(8.0), child: Text(currencyFormat.format(pAmt), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)))),
                                                        Padding(padding: const EdgeInsets.all(8.0), child: Text(p['mode'].toString(), style: const TextStyle(fontSize: 11))),
                                                        Padding(padding: const EdgeInsets.all(8.0), child: Text(p['notes'].toString(), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
                                                      ],
                                                    );
                                                  })
                                                ],
                                              ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.account_balance_outlined, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Outstanding Ledgers', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Color(0xFF0F172A))),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      drawer: const AppDrawer(),
      body: isWide
          ? Container(
              color: const Color(0xFFF1F5F9),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Container(
                    width: 320,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _buildCustomerList(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _buildLedgerDetail(),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : _selectedCustomer == null
              ? _buildCustomerList()
              : WillPopScope(
                  onWillPop: () async {
                    setState(() {
                      _selectedCustomer = null;
                      _selectedLedger = null;
                    });
                    return false;
                  },
                  child: _buildLedgerDetail(),
                ),
    );
  }

  Future<void> _launchInvoiceUrl(BuildContext context, String? url, {bool inApp = false}) async {
    if (url == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error generating link. Please ensure you are logged in.')));
      }
      return;
    }
    
    final uri = Uri.parse(url);
    try {
      final success = await launchUrl(
        uri,
        mode: inApp ? LaunchMode.inAppWebView : LaunchMode.externalApplication,
      );
      if (!success) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open browser. Please check settings.')));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showPdfPreviewDialog(BuildContext context, String invoiceId, String invoiceNumber) {
    showDialog(
      context: context,
      builder: (context) {
        final billingProvider = Provider.of<BillingProvider>(context, listen: false);
        return CallbackShortcuts(
          bindings: {
            SingleActivator(LogicalKeyboardKey.escape): () {
              Navigator.pop(context);
            },
          },
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
            width: 900,
            height: 700,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.picture_as_pdf, color: Color(0xFFEF4444)),
                        const SizedBox(width: 8),
                        Text(
                          'Invoice Preview - $invoiceNumber',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: PdfPreview(
                    build: (format) async {
                      final bytes = await billingProvider.getInvoicePdfBytes(invoiceId);
                      if (bytes == null) {
                        throw Exception('Failed to load PDF');
                      }
                      return bytes;
                    },
                    allowPrinting: true,
                    allowSharing: false,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    loadingWidget: const Center(
                      child: CircularProgressIndicator(),
                    ),
                    onError: (context, error) {
                      return Center(
                        child: Text(
                          'Error loading PDF: $error',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

  void _showDeleteConfirmationDialog(BuildContext context, String invoiceId, String invoiceNumber) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
              SizedBox(width: 8),
              Text('Confirm Delete', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text('Are you sure you want to delete bill $invoiceNumber?\n\nThis action cannot be undone and will restore the product stock quantities.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () async {
                final provider = Provider.of<BillingProvider>(context, listen: false);
                Navigator.of(dialogContext).pop();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 12),
                        Text('Deleting bill...'),
                      ],
                    ),
                    duration: Duration(seconds: 1),
                  ),
                );

                final success = await provider.deleteInvoice(invoiceId);
                
                if (context.mounted) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Bill deleted successfully'),
                        backgroundColor: Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    // Refresh ledger
                    if (_selectedCustomer != null) {
                      _selectCustomer(_selectedCustomer!);
                      // Also refresh customers list to update balances
                      _fetchCustomers(_searchController.text);
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to delete bill'),
                        backgroundColor: Color(0xFFEF4444),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Delete Bill', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showStatementPreviewDialog() {
    if (_selectedCustomer == null) return;

    showDialog(
      context: context,
      builder: (context) {
        final billingProvider = Provider.of<BillingProvider>(context, listen: false);
        return CallbackShortcuts(
          bindings: {
            SingleActivator(LogicalKeyboardKey.escape): () {
              Navigator.pop(context);
            },
          },
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              width: 900,
              height: 700,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.description_outlined, color: Color(0xFF2563EB)),
                          const SizedBox(width: 8),
                          Text(
                            'Statement Preview - ${_selectedCustomer!.name}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: PdfPreview(
                      build: (format) async {
                        final bytes = await billingProvider.getCustomerStatementBytes(_selectedCustomer!.id);
                        if (bytes == null) {
                          throw Exception('Failed to load Statement PDF');
                        }
                        return bytes;
                      },
                      allowPrinting: true,
                      allowSharing: true,
                      canChangePageFormat: false,
                      canChangeOrientation: false,
                      canDebug: false,
                      loadingWidget: const Center(
                        child: CircularProgressIndicator(),
                      ),
                      onError: (context, error) {
                        return Center(
                          child: Text(
                            'Error loading PDF: $error',
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
