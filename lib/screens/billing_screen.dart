import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../billing_provider.dart';
import '../product_provider.dart';
import '../auth_provider.dart';
import 'products_screen.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  _BillingScreenState createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _paidAmountController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  String _paymentMethod = 'CASH';
  final Map<String, String> _tempUnits = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductProvider>(context, listen: false).fetchProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final billingProvider = Provider.of<BillingProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing System'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => productProvider.fetchProducts(),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () => _showCartSummary(context, billingProvider),
              ),
              if (billingProvider.cart.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '${billingProvider.cart.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      drawer: AppDrawer(currentRole: authProvider.role ?? 'VIEWER'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) => productProvider.setSearch(v),
            ),
          ),
          Expanded(
            child: productProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.60, // Optimized for more content
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: productProvider.products.length,
                    itemBuilder: (context, index) {
                      final product = productProvider.products[index];
                      final isInCart = billingProvider.cart.any((item) => item.product.uuid == product.uuid);
                      final selectedUnit = isInCart 
                          ? billingProvider.cart.firstWhere((item) => item.product.uuid == product.uuid).unit 
                          : (_tempUnits[product.uuid] ?? 'PIECE');
                      final currentPrice = selectedUnit == 'CENT' ? product.sellingPrice * 10 : product.sellingPrice;

                      return Card(
                        elevation: 6,
                        shadowColor: Colors.black45,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.03),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.white.withOpacity(0.05), Colors.transparent],
                                  ),
                                ),
                                child: product.image != null
                                    ? Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Image.network(
                                              product.image!,
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 40, color: Colors.white24),
                                              loadingBuilder: (context, child, loadingProgress) {
                                                if (loadingProgress == null) return child;
                                                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                              },
                                            ),
                                          ),
                                          if (product.stockQuantity <= 0)
                                            Container(
                                              color: Colors.black54,
                                              child: const Center(
                                                child: Text(
                                                  'OUT OF STOCK',
                                                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 10),
                                                ),
                                              ),
                                            ),
                                        ],
                                      )
                                    : const Icon(Icons.shopping_bag_outlined, size: 40, color: Colors.white24),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    product.brand,
                                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '₹${currentPrice.toStringAsFixed(0)}',
                                        style: const TextStyle(color: Color(0xFFFF5722), fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      Text(
                                        '/${selectedUnit == 'CENT' ? 'Cent' : 'Pc'}',
                                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _buildUnitToggle(
                                    currentUnit: selectedUnit,
                                    onToggle: (newUnit) {
                                      if (isInCart) {
                                        billingProvider.toggleUnit(product.uuid);
                                      } else {
                                        setState(() {
                                          _tempUnits[product.uuid] = newUnit;
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: 36,
                                    width: double.infinity,
                                    child: isInCart
                                        ? Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.05),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                _buildQtyBtn(Icons.remove, () => billingProvider.updateQuantity(product.uuid, billingProvider.cart.firstWhere((item) => item.product.uuid == product.uuid).quantity - 1, product.stockQuantity)),
                                                GestureDetector(
                                                  onTap: () => _showCustomQtyDialog(context, billingProvider, product),
                                                  child: Text(
                                                    '${billingProvider.cart.firstWhere((item) => item.product.uuid == product.uuid).quantity}',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                  ),
                                                ),
                                                _buildQtyBtn(Icons.add, () => billingProvider.updateQuantity(product.uuid, billingProvider.cart.firstWhere((item) => item.product.uuid == product.uuid).quantity + 1, product.stockQuantity)),
                                              ],
                                            ),
                                          )
                                        : ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFFF5722),
                                              padding: EdgeInsets.zero,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            onPressed: product.stockQuantity > 0 ? () => billingProvider.addToCart(product, unit: selectedUnit) : null,
                                            child: const Text('Add to Cart', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          if (billingProvider.cart.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, -2))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Total Amount', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      Text('₹${billingProvider.grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFF5722))),
                    ],
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
                    onPressed: () => _showCheckoutBottomSheet(context, billingProvider),
                    child: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 16, color: const Color(0xFFFF5722)),
      ),
    );
  }

  Widget _buildUnitToggle({required String currentUnit, required Function(String) onToggle}) {
    return Container(
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Expanded(child: _buildUnitOption('Pc', currentUnit == 'PIECE', () => onToggle('PIECE'))),
          Expanded(child: _buildUnitOption('Cent', currentUnit == 'CENT', () => onToggle('CENT'))),
        ],
      ),
    );
  }

  Widget _buildUnitOption(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF5722) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFFFF5722).withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))] : null,
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : Colors.white60),
        ),
      ),
    );
  }

  void _showCartSummary(BuildContext context, BillingProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Cart Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: provider.cart.length,
                itemBuilder: (context, index) {
                  final item = provider.cart[index];
                  return ListTile(
                    title: Text(item.product.name),
                    subtitle: Text('₹${item.unitPrice} x ${item.quantity} ${item.unit}'),
                    trailing: Text('₹${item.totalPrice.toStringAsFixed(2)}'),
                  );
                },
              ),
            ),
            const Divider(),
            Text('Grand Total: ₹${provider.grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFF5722))),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      ),
    );
  }

  void _showCustomQtyDialog(BuildContext context, BillingProvider provider, Product product) {
    final item = provider.cart.firstWhere((item) => item.product.uuid == product.uuid);
    final controller = TextEditingController(text: '${item.quantity}');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Qty in ${item.unit}'),
        content: TextField(controller: controller, keyboardType: TextInputType.number, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () {
            provider.updateQuantity(product.uuid, int.tryParse(controller.text) ?? 0, product.stockQuantity);
            Navigator.pop(context);
          }, child: const Text('OK')),
        ],
      ),
    );
  }

  final _formKey = GlobalKey<FormState>();

  void _showCheckoutBottomSheet(BuildContext context, BillingProvider provider) {
    _paidAmountController.text = provider.grandTotal.toString();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Checkout', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextFormField(controller: _customerNameController, decoration: const InputDecoration(labelText: 'Customer Name', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 12),
                TextFormField(controller: _customerPhoneController, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                TextFormField(controller: _discountController, decoration: const InputDecoration(labelText: 'Discount', border: OutlineInputBorder()), keyboardType: TextInputType.number, onChanged: (v) => provider.discount = double.tryParse(v) ?? 0),
                const SizedBox(height: 12),
                TextFormField(controller: _paidAmountController, decoration: const InputDecoration(labelText: 'Paid Amount', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  items: const [DropdownMenuItem(value: 'CASH', child: Text('CASH')), DropdownMenuItem(value: 'CARD', child: Text('CARD')), DropdownMenuItem(value: 'ONLINE', child: Text('ONLINE'))],
                  onChanged: (v) => _paymentMethod = v!,
                  decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                if (provider.isLoading) const CircularProgressIndicator()
                else Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        final preview = await provider.previewInvoice(customerName: _customerNameController.text, customerPhone: _customerPhoneController.text, paidAmount: double.tryParse(_paidAmountController.text) ?? provider.grandTotal, paymentMethod: _paymentMethod);
                        if (preview != null) _showPreviewDialog(context, preview);
                      }
                    }, child: const Text('Preview'))),
                    const SizedBox(width: 10),
                    Expanded(child: ElevatedButton(onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        final invoiceId = await provider.createInvoice(customerName: _customerNameController.text, customerPhone: _customerPhoneController.text, paidAmount: double.tryParse(_paidAmountController.text) ?? provider.grandTotal, paymentMethod: _paymentMethod);
                        if (invoiceId != null) {
                          Navigator.pop(context);
                          _showSuccessWithDownload(context, provider, invoiceId);
                        }
                      }
                    }, child: const Text('Confirm'))),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPreviewDialog(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preview'),
        content: Text('Total: ₹${data['grand_total']}'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _showSuccessWithDownload(BuildContext context, BillingProvider provider, String invoiceId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 60),
              const SizedBox(height: 16),
              const Text('Success!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Text('Order has been placed successfully.', style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 24),
              const Divider(color: Colors.white10),
              const SizedBox(height: 12),
              const Text('Print Options', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFF5722))),
              const SizedBox(height: 16),
              _buildPrintOption(
                icon: Icons.picture_as_pdf,
                label: 'Standard PDF (A4)',
                subtitle: 'Download professional invoice',
                onTap: () async => _launchInvoiceUrl(context, await provider.getInvoicePdfUrl(invoiceId)),
              ),
              const SizedBox(height: 12),
              _buildPrintOption(
                icon: Icons.print,
                label: 'Print HTML',
                subtitle: 'Direct browser printing',
                onTap: () async => _launchInvoiceUrl(context, await provider.getInvoicePrintHtmlUrl(invoiceId)),
              ),
              const SizedBox(height: 12),
              _buildPrintOption(
                icon: Icons.receipt,
                label: 'Thermal Receipt (80mm)',
                subtitle: 'Print using thermal printer',
                onTap: () async => _launchInvoiceUrl(context, await provider.getInvoiceThermalReceiptUrl(invoiceId)),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrintOption({required IconData icon, required String label, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFFF5722).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: const Color(0xFFFF5722), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  Future<void> _launchInvoiceUrl(BuildContext context, String? url) async {
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error generating link. Please ensure you are logged in.')));
      return;
    }
    
    final uri = Uri.parse(url);
    try {
      final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open browser. Please check settings.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

class AppDrawer extends StatelessWidget {
  final String currentRole;
  const AppDrawer({super.key, required this.currentRole});
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(decoration: BoxDecoration(color: Color(0xFFFF5722)), child: Center(child: Text('Vighnaharta Fataka', style: TextStyle(color: Colors.white, fontSize: 20)))),
          ListTile(leading: const Icon(Icons.dashboard), title: const Text('Dashboard'), onTap: () => Navigator.pushReplacementNamed(context, '/dashboard')),
          ListTile(leading: const Icon(Icons.inventory), title: const Text('Inventory'), onTap: () => Navigator.pushReplacementNamed(context, '/inventory')),
          ListTile(leading: const Icon(Icons.receipt), title: const Text('Billing'), onTap: () => Navigator.pop(context)),
          if (currentRole == 'OWNER') ListTile(leading: const Icon(Icons.people), title: const Text('Staff'), onTap: () => Navigator.pushReplacementNamed(context, '/staff')),
          const Divider(),
          ListTile(leading: const Icon(Icons.logout), title: const Text('Logout'), onTap: () async {
            await Provider.of<AuthProvider>(context, listen: false).logout();
            Navigator.pushReplacementNamed(context, '/login');
          }),
        ],
      ),
    );
  }
}
