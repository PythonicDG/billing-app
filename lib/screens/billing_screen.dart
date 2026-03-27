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
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showCartSummary(context, billingProvider),
            child: Container(
              margin: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFF5722), Color(0xFFFF8A65)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: const Color(0xFFFF5722).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  const Icon(Icons.shopping_cart, size: 18, color: Colors.white),
                  if (billingProvider.cart.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      '${billingProvider.cart.length}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      drawer: AppDrawer(currentRole: authProvider.role ?? 'VIEWER'),
      body: Column(
        children: [
          // Product Search & Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onChanged: (v) => productProvider.setSearch(v),
              ),
            ),
          ),
          
          Expanded(
            child: productProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.68,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: productProvider.products.length,
                    itemBuilder: (context, index) {
                      final product = productProvider.products[index];
                      final isInCart = billingProvider.cart.any((item) => item.product.uuid == product.uuid);
                      final selectedUnit = isInCart ? billingProvider.cart.firstWhere((item) => item.product.uuid == product.uuid).unit : (_tempUnits[product.uuid] ?? 'PIECE');
                      final currentPrice = selectedUnit == 'CENT' ? product.sellingPrice * 10 : product.sellingPrice;
                      
                      return Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                                child: Container(
                                  width: double.infinity,
                                  color: Colors.white10,
                                  child: const Icon(Icons.shopping_bag_outlined, size: 40, color: Colors.white24),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      product.brand,
                                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                                    ),
                                    const Spacer(),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '₹$currentPrice',
                                          style: const TextStyle(color: Color(0xFFFF5722), fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        Text(
                                          'Qty: ${selectedUnit == 'CENT' ? 'Cent' : 'Pc'}',
                                          style: const TextStyle(color: Colors.white54, fontSize: 10),
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
                                            _tempUnits[product.uuid] = selectedUnit == 'PIECE' ? 'CENT' : 'PIECE';
                                          });
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      height: 36,
                                      width: double.infinity,
                                      child: isInCart
                                          ? _buildCartQuantityRow(context, billingProvider, product)
                                          : ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFFFF5722),
                                                padding: EdgeInsets.zero,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              ),
                                              onPressed: product.stockQuantity > 0 ? () => billingProvider.addToCart(product, unit: selectedUnit) : null,
                                              child: const Text('ADD TO CART', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          
          if (billingProvider.cart.isNotEmpty)
            _buildBottomSummary(billingProvider),
        ],
      ),
    );
  }

  Widget _buildCartQuantityRow(BuildContext context, BillingProvider billingProvider, Product product) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5722).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFF5722).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildTinyQtyBtn(
            Icons.remove,
            () => billingProvider.updateQuantity(
              product.uuid,
              billingProvider.cart.firstWhere((item) => item.product.uuid == product.uuid).quantity - 1,
              product.stockQuantity,
            ),
          ),
          InkWell(
            onTap: () => _showCustomQtyDialog(context, billingProvider, product),
            child: Text(
              '${billingProvider.cart.firstWhere((item) => item.product.uuid == product.uuid).quantity}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
            ),
          ),
          _buildTinyQtyBtn(
            Icons.add,
            () => billingProvider.updateQuantity(
              product.uuid,
              billingProvider.cart.firstWhere((item) => item.product.uuid == product.uuid).quantity + 1,
              product.stockQuantity,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTinyQtyBtn(IconData icon, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: 16, color: const Color(0xFFFF5722)),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      onPressed: onPressed,
    );
  }

  Widget _buildUnitToggle({required String currentUnit, required Function(String) onToggle}) {
    return Container(
      width: double.infinity,
      height: 32,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
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
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.bold,
            color: isSelected ? Colors.white : Colors.white24,
          ),
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
        title: Text('Enter Quality in ${item.unit == 'PIECE' ? 'Pieces' : 'Cents'}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Max: ${item.unit == 'CENT' ? product.stockQuantity ~/ 10 : product.stockQuantity}',
            suffixText: item.unit == 'PIECE' ? 'pcs' : 'cents',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final val = int.tryParse(controller.text) ?? 0;
              provider.updateQuantity(product.uuid, val, product.stockQuantity);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSummary(BillingProvider billingProvider) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${billingProvider.cart.length} items', style: const TextStyle(color: Colors.white38, fontSize: 13)),
              Text('₹${billingProvider.grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFF5722))),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5722),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 0,
              ),
              onPressed: () => _showCheckoutBottomSheet(context, billingProvider),
              child: const Text('CHECKOUT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
            ),
          ),
        ],
      ),
    );
  }

  void _showCartSummary(BuildContext context, BillingProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Your Cart', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  if (provider.cart.isNotEmpty)
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      label: const Text('Clear all', style: TextStyle(color: Colors.redAccent)),
                      onPressed: () {
                        provider.clearCart();
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (provider.cart.isEmpty)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.white10),
                        SizedBox(height: 16),
                        Text('Your cart is empty', style: TextStyle(color: Colors.white38, fontSize: 18)),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: provider.cart.length,
                    separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 24),
                    itemBuilder: (context, index) {
                      final item = provider.cart[index];
                      return Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.shopping_bag_outlined, color: Colors.white24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${item.unitPrice} / ${item.unit == 'PIECE' ? 'Pc' : 'Cent'}',
                                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  _buildUnitBtn(item.unit == 'PIECE' ? 'Pc' : 'Cent', () {
                                    provider.toggleUnit(item.product.uuid);
                                    setModalState(() {});
                                  }),
                                  const SizedBox(width: 8),
                                  _buildSmallQtyBtn(Icons.remove, () {
                                    provider.updateQuantity(item.product.uuid, item.quantity - 1, item.product.stockQuantity);
                                    setModalState(() {});
                                    if (provider.cart.isEmpty) Navigator.pop(context);
                                  }),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                                  ),
                                  _buildSmallQtyBtn(Icons.add, () {
                                    provider.updateQuantity(item.product.uuid, item.quantity + 1, item.product.stockQuantity);
                                    setModalState(() {});
                                  }),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('₹${item.totalPrice.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFFF5722), fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              if (provider.cart.isNotEmpty) ...[
                const Divider(color: Colors.white12, height: 32),
                _buildSummaryRow('Sub-total', '₹${provider.subTotal.toStringAsFixed(2)}', false),
                _buildSummaryRow('Tax (GST 18%)', '₹${provider.taxAmount.toStringAsFixed(2)}', false),
                const SizedBox(height: 8),
                _buildSummaryRow('Grand Total', '₹${provider.grandTotal.toStringAsFixed(2)}', true),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5722),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 8,
                      shadowColor: const Color(0xFFFF5722).withOpacity(0.5),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _showCheckoutBottomSheet(context, provider);
                    },
                    child: const Text('PROCEED TO CHECKOUT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnitBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFF5722).withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFF5722).withOpacity(0.3)),
        ),
        child: Text(label, style: const TextStyle(color: Color(0xFFFF5722), fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSmallQtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)),
        child: Icon(icon, size: 16, color: Colors.white70),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, bool isTotal) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: isTotal ? Colors.white : Colors.white54, fontSize: isTotal ? 18 : 14, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(color: isTotal ? const Color(0xFFFF5722) : Colors.white, fontSize: isTotal ? 22 : 14, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  final _formKey = GlobalKey<FormState>();

  void _showCheckoutBottomSheet(BuildContext context, BillingProvider provider) {
    _paidAmountController.text = provider.grandTotal.toString();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Checkout', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text('Complete the payment details', style: TextStyle(fontSize: 13, color: Colors.white38)),
                      ],
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
                        child: const Icon(Icons.edit_note, color: Colors.blueAccent, size: 20),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _showCartSummary(context, provider);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                _buildCheckoutField(_customerNameController, 'Customer Name', Icons.person),
                const SizedBox(height: 16),
                _buildCheckoutField(_customerPhoneController, 'Customer Phone', Icons.phone, keyboardType: TextInputType.phone),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildCheckoutField(_discountController, 'Discount', Icons.discount, keyboardType: TextInputType.number, onChanged: (v) => provider.discount = double.tryParse(v) ?? 0)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildCheckoutField(_paidAmountController, 'Paid Amt', Icons.payments, keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  dropdownColor: const Color(0xFF2C2C2C),
                  decoration: InputDecoration(
                    labelText: 'Payment Method',
                    prefixIcon: const Icon(Icons.account_balance_wallet, size: 20),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'CASH', child: Text('CASH')),
                    DropdownMenuItem(value: 'CARD', child: Text('CARD')),
                    DropdownMenuItem(value: 'ONLINE', child: Text('ONLINE')),
                    DropdownMenuItem(value: 'CREDIT', child: Text('CREDIT')),
                  ],
                  onChanged: (v) => _paymentMethod = v!,
                ),
                const SizedBox(height: 30),
                const Divider(color: Colors.white12),
                const SizedBox(height: 16),
                _buildSummaryRow('Payable Amount', '₹${provider.grandTotal.toStringAsFixed(2)}', true),
                const SizedBox(height: 32),
                if (provider.isLoading)
                  const CircularProgressIndicator()
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            side: const BorderSide(color: Colors.white10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              final preview = await provider.previewInvoice(
                                customerName: _customerNameController.text,
                                customerPhone: _customerPhoneController.text,
                                paidAmount: double.tryParse(_paidAmountController.text) ?? provider.grandTotal,
                                paymentMethod: _paymentMethod,
                              );
                              if (preview != null) {
                                _showPreviewDialog(context, preview);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage ?? 'Preview failed')));
                              }
                            }
                          },
                          child: const Text('PREVIEW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5722),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 8,
                            shadowColor: const Color(0xFFFF5722).withOpacity(0.4),
                          ),
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              final invoiceId = await provider.createInvoice(
                                customerName: _customerNameController.text,
                                customerPhone: _customerPhoneController.text,
                                paidAmount: double.tryParse(_paidAmountController.text) ?? provider.grandTotal,
                                paymentMethod: _paymentMethod,
                              );
                              if (invoiceId != null) {
                                Navigator.pop(context);
                                _showSuccessWithDownload(context, provider, invoiceId);
                                _customerNameController.clear();
                                _customerPhoneController.clear();
                                _discountController.text = '0';
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage ?? 'Failed to create order'), backgroundColor: Colors.red));
                              }
                            }
                          },
                          child: const Text('CONFIRM ORDER', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckoutField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType, Function(String)? onChanged}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: (v) => v!.isEmpty ? 'Required' : null,
    );
  }

  void _showPreviewDialog(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invoice Preview'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Customer: ${data['customer_name'] ?? 'N/A'}'),
              Text('Phone: ${data['customer_phone'] ?? 'N/A'}'),
              const Divider(),
              Text('Sub-total: ₹${data['sub_total']}'),
              Text('Tax: ₹${data['tax_amount']}'),
              Text('Discount: ₹${data['discount_amount']}'),
              Text('Grand Total: ₹${data['grand_total']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF5722))),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _showSuccessWithDownload(BuildContext context, BillingProvider provider, String invoiceId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Text('Order Placed Successfully!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
             SizedBox(height: 8),
             Text('Would you like to download the PDF bill?'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')),
          ElevatedButton(
            onPressed: () async {
              final url = await provider.getInvoicePdfUrl(invoiceId);
              if (url != null) {
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                }
              }
              Navigator.pop(context);
            },
            child: const Text('Download PDF'),
          ),
        ],
      ),
    );
  }
}
