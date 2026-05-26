import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
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
  final _searchController = TextEditingController();

  String _paymentMethod = 'CASH';
  String _selectedCategory = 'ALL';
  String _activeOrdering = 'created_at';
  final Map<String, String> _tempUnits = {};

  // For POS calculations
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  // Classified dynamic categories from names
  final List<String> _categories = [
    'ALL',
    'Sparklers',
    'Flower Pots',
    'Chakkars',
    'Rockets',
    'Garlands',
    'Atom Bombs',
    'Fancy Shots',
    'Novelties',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductProvider>(context, listen: false).fetchProducts();
    });
  }

  // Parses name and classifies into categories
  String _getProductCategory(String name) {
    final n = name.toLowerCase();
    if (n.contains('sparkler') || n.contains('fulbajhi')) return 'Sparklers';
    if (n.contains('pot') || n.contains('anar') || n.contains('fountain') || n.contains('rain')) return 'Flower Pots';
    if (n.contains('chakkar') || n.contains('wheel') || n.contains('spinner') || n.contains('circle')) return 'Chakkars';
    if (n.contains('rocket') || n.contains('voyager')) return 'Rockets';
    if (n.contains('garland') || n.contains('lar') || n.contains('maal') || n.contains('chorsa')) return 'Garlands';
    if (n.contains('bomb') || n.contains('hydro') || n.contains('bullet') || n.contains('cracker')) return 'Atom Bombs';
    if (n.contains('shot') || n.contains('shell') || n.contains('aerial') || n.contains('comet')) return 'Fancy Shots';
    if (n.contains('pop') || n.contains('snake') || n.contains('peacock') || n.contains('butterfly') || n.contains('helicopter') || n.contains('bijli') || n.contains('star')) return 'Novelties';
    return 'Novelties'; // Fallback
  }

  @override
  Widget build(BuildContext context) {
    final billingProvider = Provider.of<BillingProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    // Apply dynamic filtering locally over loaded products
    List<Product> displayedProducts = productProvider.products;
    if (_selectedCategory != 'ALL') {
      displayedProducts = productProvider.products.where((p) {
        return _getProductCategory(p.name) == _selectedCategory;
      }).toList();
    }

    double screenWidth = MediaQuery.of(context).size.width;
    bool isWidePOSLayout = screenWidth >= 1024;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.bolt, color: Color(0xFFFFC107)),
            SizedBox(width: 8),
            Text(
              'Vighnaharta POS Billing',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh Inventory',
            onPressed: () => productProvider.fetchProducts(),
          ),
          if (!isWidePOSLayout)
            _buildCartBadgeButton(billingProvider),
          const SizedBox(width: 8),
        ],
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      drawer: AppDrawer(currentRole: authProvider.role ?? 'VIEWER'),
      body: isWidePOSLayout
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Catalog Section
                Expanded(
                  flex: 62,
                  child: _buildCatalogSection(productProvider, displayedProducts, billingProvider),
                ),
                // Persistent Cart / Checkout Section
                VerticalDivider(color: Colors.white10, width: 1, thickness: 1),
                Expanded(
                  flex: 38,
                  child: _buildCheckoutSection(billingProvider),
                ),
              ],
            )
          : _buildCatalogSection(productProvider, displayedProducts, billingProvider),
      bottomNavigationBar: (!isWidePOSLayout && billingProvider.cart.isNotEmpty)
          ? _buildMobileFloatingCartBar(billingProvider)
          : null,
    );
  }

  // Cart badge icon on Top App Bar
  Widget _buildCartBadgeButton(BillingProvider billingProvider) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.shopping_bag_outlined),
          tooltip: 'Active Cart',
          onPressed: () => _showMobileCartBottomSheet(context, billingProvider),
        ),
        if (billingProvider.cart.isNotEmpty)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5722),
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '${billingProvider.cart.fold(0, (sum, i) => sum + i.quantity)}',
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  // Mobile Floating Cart bar
  Widget _buildMobileFloatingCartBar(BillingProvider billingProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${billingProvider.cart.length} Products | ${billingProvider.cart.fold(0, (sum, i) => sum + i.quantity)} Pcs',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  currencyFormat.format(billingProvider.grandTotal),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFF5722)),
                ),
              ],
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5722),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _showMobileCartBottomSheet(context, billingProvider),
              icon: const Icon(Icons.shopping_cart_checkout_outlined, size: 18),
              label: const Text(
                'CHECKOUT',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Main Catalog view
  Widget _buildCatalogSection(
      ProductProvider productProvider, List<Product> displayedProducts, BillingProvider billingProvider) {
    double width = MediaQuery.of(context).size.width;
    // Responsive columns
    int crossAxisCount = width < 500 ? 1 : (width < 900 ? 2 : (width < 1400 ? 2 : 3));
    double childAspectRatio = width < 500 ? 1.6 : 0.64;

    return Column(
      children: [
        // Modern search input and filter buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 3))
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Quick find firecrackers...',
                      prefixIcon: const Icon(Icons.search_outlined, color: Color(0xFFFF5722), size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_outlined, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                productProvider.setSearch('');
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.04)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.04)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFFF5722), width: 1.2),
                      ),
                    ),
                    onChanged: (v) {
                      setState(() {});
                    },
                    onSubmitted: (v) => productProvider.setSearch(v),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.04)),
                ),
                child: IconButton(
                  icon: const Icon(Icons.swap_vert_outlined, color: Colors.white70),
                  tooltip: 'Sort Options',
                  onPressed: () => _showSortOptions(context, productProvider),
                ),
              ),
            ],
          ),
        ),

        // Horizontal Category Scrolling Filter chips
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = _selectedCategory == cat.toUpperCase();
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.white60,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFFFF5722),
                  backgroundColor: const Color(0xFF1E1E1E),
                  elevation: 0,
                  pressElevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(
                    color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.06),
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = cat.toUpperCase();
                    });
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),

        // Products Grid
        Expanded(
          child: productProvider.isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5722)))
              : displayedProducts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_outlined, size: 48, color: Colors.white24),
                          const SizedBox(height: 12),
                          Text('No firecrackers found', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.bold)),
                          Text('Try a different search category or search text.', style: TextStyle(color: Colors.white30, fontSize: 12)),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: childAspectRatio,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: displayedProducts.length,
                      itemBuilder: (context, index) {
                        final product = displayedProducts[index];
                        return _buildECommerceProductCard(product, billingProvider);
                      },
                    ),
        ),
      ],
    );
  }

  // Beautiful Amazon/Flipkart style Product Grid Card
  Widget _buildECommerceProductCard(Product product, BillingProvider billingProvider) {
    final isInCart = billingProvider.cart.any((item) => item.product.uuid == product.uuid);
    final cartItem = isInCart ? billingProvider.cart.firstWhere((item) => item.product.uuid == product.uuid) : null;
    
    final selectedUnit = isInCart ? cartItem!.unit : (_tempUnits[product.uuid] ?? 'PIECE');
    final currentPrice = selectedUnit == 'CENT' ? product.sellingPrice * 10 : product.sellingPrice;
    
    final isOutOfStock = product.stockQuantity <= 0;
    final isLowStock = product.stockQuantity <= product.minStockLevel && !isOutOfStock;

    double discountPercent = 0.0;
    if (product.mrp > 0 && product.mrp > product.sellingPrice) {
      discountPercent = ((product.mrp - product.sellingPrice) / product.mrp) * 100;
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isInCart
              ? const Color(0xFFFF5722).withOpacity(0.5)
              : Colors.white.withOpacity(0.04),
          width: isInCart ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 3))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header aspect frame for product image
          Expanded(
            flex: 11,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: Colors.white.withOpacity(0.02),
                  child: product.image != null && product.image!.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.network(
                            product.image!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image_outlined, size: 28, color: Colors.white24),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                            },
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.local_fire_department_outlined, size: 36, color: Color(0xFFFF5722)),
                        ),
                ),
                // Discount rate badge
                if (discountPercent > 0)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5722),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${discountPercent.toStringAsFixed(0)}% OFF',
                        style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                // Out of stock overlay
                if (isOutOfStock)
                  Container(
                    color: Colors.black87,
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.redAccent),
                      ),
                      child: const Text(
                        'SOLD OUT',
                        style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Details section
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.brand,
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10.5, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Stock status text
                    Text(
                      isOutOfStock
                          ? 'Out of stock'
                          : isLowStock
                              ? 'Only ${product.stockQuantity} left'
                              : '${product.stockQuantity} in stock',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isOutOfStock
                            ? Colors.redAccent
                            : isLowStock
                                ? Colors.orangeAccent
                                : const Color(0xFF4CAF50),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                
                // Price row
                Row(
                  children: [
                    Text(
                      currencyFormat.format(currentPrice),
                      style: const TextStyle(color: Color(0xFFFF5722), fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(width: 4),
                    if (product.mrp > product.sellingPrice)
                      Text(
                        currencyFormat.format(selectedUnit == 'CENT' ? product.mrp * 10 : product.mrp),
                        style: const TextStyle(
                          color: Colors.white30,
                          fontSize: 11,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    const Spacer(),
                    Text(
                      '/${selectedUnit == 'CENT' ? 'Cent' : 'Box'}',
                      style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Unit selection toggle
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
                const SizedBox(height: 8),

                // Elegant action button or quantity controls
                SizedBox(
                  height: 34,
                  width: double.infinity,
                  child: isInCart
                      ? Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFF5722).withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildQtyBtn(
                                Icons.remove_outlined,
                                () => billingProvider.updateQuantity(
                                  product.uuid,
                                  cartItem!.quantity - 1,
                                  product.stockQuantity,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _showCustomQtyDialog(context, billingProvider, product),
                                child: Text(
                                  '${cartItem!.quantity}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              _buildQtyBtn(
                                Icons.add_outlined,
                                () => billingProvider.updateQuantity(
                                  product.uuid,
                                  cartItem.quantity + 1,
                                  product.stockQuantity,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5722),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: !isOutOfStock
                              ? () => billingProvider.addToCart(product, unit: selectedUnit)
                              : null,
                          child: const Text(
                            'ADD TO CART',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
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

  // Active Checkout right side POS panel / sheet
  Widget _buildCheckoutSection(BillingProvider billingProvider) {
    return Container(
      color: const Color(0xFF161616),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shopping_basket_outlined, color: Color(0xFFFF5722), size: 20),
                    SizedBox(width: 8),
                    Text('Active Billing Cart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    if (billingProvider.cart.isNotEmpty) {
                      billingProvider.clearCart();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart cleared successfully.')));
                    }
                  },
                  child: Text(
                    'Clear All',
                    style: TextStyle(
                      color: billingProvider.cart.isNotEmpty ? Colors.redAccent : Colors.white30,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Cart Items
          Expanded(
            child: billingProvider.cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 40, color: Colors.white12),
                        const SizedBox(height: 12),
                        Text('Your cart is empty', style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold)),
                        Text('Click ADD TO CART on any firecracker.', style: TextStyle(color: Colors.white12, fontSize: 11)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: billingProvider.cart.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = billingProvider.cart[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.03)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        '${currencyFormat.format(item.unitPrice)} x ${item.quantity} ${item.unit == 'CENT' ? 'Cent' : 'Box'}',
                                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFC107).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.product.brand,
                                          style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFFFFC107)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Price and Delete option
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  currencyFormat.format(item.totalPrice),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFFF5722)),
                                ),
                                GestureDetector(
                                  onTap: () => billingProvider.removeFromCart(item.product.uuid),
                                  child: const Padding(
                                    padding: EdgeInsets.only(top: 4.0),
                                    child: Icon(Icons.delete_forever_outlined, color: Colors.redAccent, size: 16),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Order summary breakdown and calculations
          if (billingProvider.cart.isNotEmpty)
            _buildBillingCalculationsPanel(billingProvider),
        ],
      ),
    );
  }

  // Beautiful billing computations panel
  Widget _buildBillingCalculationsPanel(BillingProvider billingProvider) {
    // Computing discounts and totals
    double mrpTotal = billingProvider.cart.fold(0.0, (sum, i) {
      double itemMrp = i.unit == 'CENT' ? i.product.mrp * 10 : i.product.mrp;
      return sum + (itemMrp > 0 ? itemMrp * i.quantity : i.unitPrice * i.quantity);
    });

    double retailDiscount = mrpTotal - billingProvider.subTotal;
    if (retailDiscount < 0) retailDiscount = 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('BILLING PAYMENT BREAKDOWN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Colors.white38)),
          const SizedBox(height: 10),
          _summaryRow('Item Total MRP', currencyFormat.format(mrpTotal)),
          _summaryRow('Product Retail Discount (40% OFF)', '- ${currencyFormat.format(retailDiscount)}', textColor: const Color(0xFF4CAF50)),
          const Divider(color: Colors.white10),
          _summaryRow('Cart Subtotal', currencyFormat.format(billingProvider.subTotal)),
          // Broken GST display (18% GST split into 9% CGST and 9% SGST)
          _summaryRow('CGST (9%)', '+ ${currencyFormat.format(billingProvider.subTotal * 0.09)}', fontSize: 11),
          _summaryRow('SGST (9%)', '+ ${currencyFormat.format(billingProvider.subTotal * 0.09)}', fontSize: 11),
          _summaryRow('GST Tax Total (18%)', '+ ${currencyFormat.format(billingProvider.taxAmount)}', textColor: Colors.amber, fontSize: 11.5),
          
          if (billingProvider.grandTotal != billingProvider.totalWithTax)
            _summaryRow('Additional Invoice Discount', '- ${currencyFormat.format(billingProvider.totalWithTax - billingProvider.grandTotal)}', textColor: const Color(0xFF4CAF50)),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(color: Colors.white30, thickness: 1),
          ),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Grand Net Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(
                currencyFormat.format(billingProvider.grandTotal),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFFF5722)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Checkout action button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5722),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
              onPressed: () => _showCheckoutWizard(context, billingProvider),
              icon: const Icon(Icons.security_outlined, size: 20),
              label: const Text(
                'CHECKOUT & GENERATE BILL',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, fontSize: 13.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? textColor, double fontSize = 12.5}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.w600)),
          Text(
            value,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: textColor ?? Colors.white),
          ),
        ],
      ),
    );
  }

  // Interactive Payment & Checkout Wizard
  void _showCheckoutWizard(BuildContext context, BillingProvider provider) {
    _paidAmountController.text = provider.grandTotal.toString();
    _discountController.text = '0';
    provider.discount = 0.0;
    _paymentMethod = 'CASH';
    double changeAmount = 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Live calculation of cash change
          double paidVal = double.tryParse(_paidAmountController.text) ?? provider.grandTotal;
          changeAmount = paidVal - provider.grandTotal;
          if (changeAmount < 0) changeAmount = 0.0;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(Icons.payment_outlined, color: Color(0xFFFF5722)),
                        SizedBox(width: 8),
                        Text('Billing Checkout Portal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 24),

                    // Customer Profile
                    const Text('CUSTOMER PROFILE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Colors.white38)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _customerNameController,
                            style: const TextStyle(fontSize: 14),
                            decoration: const InputDecoration(
                              labelText: 'Customer Name',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v!.isEmpty ? 'Enter customer name' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Quick autocomplete walk-in client
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFF5722)),
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            setModalState(() {
                              _customerNameController.text = 'Walk-In Customer';
                              _customerPhoneController.text = '9999999999';
                            });
                          },
                          child: const Text('WALK-IN', style: TextStyle(color: Color(0xFFFF5722), fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _customerPhoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Mobile Number',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Extra discounts
                    const Text('DISCOUNTS & CHARGES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Colors.white38)),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _discountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Additional Cash Discount (₹)',
                        prefixIcon: Icon(Icons.discount_outlined),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        provider.discount = double.tryParse(v) ?? 0.0;
                        setModalState(() {});
                      },
                    ),
                    const SizedBox(height: 20),

                    // Payment details
                    const Text('PAYMENT DETAILS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Colors.white38)),
                    const SizedBox(height: 10),
                    
                    // Segmented Payment Method Selector
                    Container(
                      height: 46,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.all(3),
                      child: Row(
                        children: [
                          Expanded(child: _paymentSegment('CASH', Icons.money, _paymentMethod == 'CASH', () {
                            setModalState(() { _paymentMethod = 'CASH'; });
                          })),
                          Expanded(child: _paymentSegment('CARD', Icons.credit_card, _paymentMethod == 'CARD', () {
                            setModalState(() { _paymentMethod = 'CARD'; });
                          })),
                          Expanded(child: _paymentSegment('UPI', Icons.qr_code, _paymentMethod == 'UPI', () {
                            setModalState(() { _paymentMethod = 'UPI'; });
                          })),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Simulated Payment panels
                    if (_paymentMethod == 'CASH') ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _paidAmountController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 14),
                              decoration: const InputDecoration(
                                labelText: 'Received Cash (₹)',
                                prefixIcon: Icon(Icons.attach_money),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (v) {
                                setModalState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('RETURN CHANGE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white38)),
                                Text(
                                  currencyFormat.format(changeAmount),
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ] else if (_paymentMethod == 'CARD') ...[
                      // Simulated Credit card details
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('CREDIT / DEBIT TRANSACTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFFFC107))),
                                Icon(Icons.payment, color: Colors.white54, size: 18),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Please swipe or tap the card on your pos terminal. The bill status will automatically settle once authorized.',
                              style: TextStyle(fontSize: 11.5, color: Colors.white38),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_paymentMethod == 'UPI') ...[
                      // Simulated UPI Scan code
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.qr_code_2_outlined, color: Colors.black, size: 50),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('UPI INSTANT QR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))),
                                  SizedBox(height: 4),
                                  Text(
                                    'Instruct client to scan the active POS scanner screen or billing desk card.',
                                    style: TextStyle(fontSize: 10.5, color: Colors.white38),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    const Divider(color: Colors.white10),

                    // Net Pay and Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('NET TO COLLECT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white38)),
                            Text(currencyFormat.format(provider.grandTotal), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFF5722))),
                          ],
                        ),
                        if (provider.isLoading)
                          const CircularProgressIndicator(color: Color(0xFFFF5722))
                        else
                          Row(
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.white.withOpacity(0.12)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                                      _showThermalReceiptPreview(context, preview);
                                    }
                                  }
                                },
                                icon: const Icon(Icons.preview_outlined, size: 16, color: Colors.white),
                                label: const Text('PREVIEW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF5722),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                                    }
                                  }
                                },
                                icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
                                label: const Text('CONFIRM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _paymentSegment(String label, IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFF5722) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
              ? [BoxShadow(color: const Color(0xFFFF5722).withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: active ? Colors.white : Colors.white60),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: active ? Colors.white : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Interactive Receipt Thermal view
  void _showThermalReceiptPreview(BuildContext context, Map<String, dynamic> data) {
    final dateStr = DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now());
    final itemsList = data['items'] as List? ?? [];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4), // Square terminal paper look
            boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 16)],
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top receipt style
                const Center(
                  child: Column(
                    children: [
                      Text(
                        '*** INVOICE PREVIEW ***',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace'),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'VIGHNAHARTA FATAKA',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 16, fontFamily: 'monospace', letterSpacing: 0.8),
                      ),
                      Text(
                        'Wholesale Firecracker Depot',
                        style: TextStyle(color: Colors.black87, fontSize: 10, fontFamily: 'monospace'),
                      ),
                      Text(
                        'Ph: +91 99999 88888',
                        style: TextStyle(color: Colors.black87, fontSize: 10, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('--------------------------------', style: TextStyle(color: Colors.black45, fontSize: 12, fontFamily: 'monospace')),
                
                // Invoice Details
                Text('Date: $dateStr', style: const TextStyle(color: Colors.black, fontSize: 11, fontFamily: 'monospace')),
                Text('Cust: ${data['customer_name'] ?? 'Walk-In'}', style: const TextStyle(color: Colors.black, fontSize: 11, fontFamily: 'monospace')),
                if (data['customer_phone'] != null && data['customer_phone']!.isNotEmpty)
                  Text('Ph  : ${data['customer_phone']}', style: const TextStyle(color: Colors.black, fontSize: 11, fontFamily: 'monospace')),
                
                const Text('--------------------------------', style: TextStyle(color: Colors.black45, fontSize: 12, fontFamily: 'monospace')),
                
                // Item Header
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('Item Name', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
                    Text('Qty', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                    SizedBox(width: 8),
                    Text('Total', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  ],
                ),
                const Text('--------------------------------', style: TextStyle(color: Colors.black45, fontSize: 12, fontFamily: 'monospace')),
                
                // Items Loop
                ...itemsList.map((item) {
                  // Resolve product name from model locally if possible
                  final pProvider = Provider.of<ProductProvider>(context, listen: false);
                  final matchingProduct = pProvider.products.firstWhere(
                    (p) => p.uuid == item['product'],
                    orElse: () => Product(uuid: '', name: 'Firecracker Item', brand: '', sellingPrice: 0, mrp: 0, purchasePrice: 0, stockQuantity: 0, minStockLevel: 0),
                  );

                  double totPrice = (double.tryParse(item['quantity']?.toString() ?? '0') ?? 0.0) * (double.tryParse(item['unit_price']?.toString() ?? '0') ?? 0.0);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            matchingProduct.name,
                            style: const TextStyle(color: Colors.black87, fontSize: 10.5, fontFamily: 'monospace'),
                            maxLines: 2,
                          ),
                        ),
                        Text(
                          '${item['quantity']}',
                          style: const TextStyle(color: Colors.black, fontSize: 10.5, fontFamily: 'monospace'),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '₹${totPrice.toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.black, fontSize: 10.5, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  );
                }),
                
                const Text('--------------------------------', style: TextStyle(color: Colors.black45, fontSize: 12, fontFamily: 'monospace')),
                
                // Calculations
                _receiptRow('Subtotal', '₹${double.parse(data['sub_total']?.toString() ?? '0').toStringAsFixed(2)}'),
                _receiptRow('CGST (9%)', '₹${(double.parse(data['sub_total']?.toString() ?? '0') * 0.09).toStringAsFixed(2)}'),
                _receiptRow('SGST (9%)', '₹${(double.parse(data['sub_total']?.toString() ?? '0') * 0.09).toStringAsFixed(2)}'),
                _receiptRow('GST Tax (18%)', '₹${double.parse(data['tax_amount']?.toString() ?? '0').toStringAsFixed(2)}'),
                if (double.parse(data['discount_amount']?.toString() ?? '0') > 0)
                  _receiptRow('Extra Discount', '-₹${double.parse(data['discount_amount']?.toString() ?? '0').toStringAsFixed(2)}'),
                
                const Text('--------------------------------', style: TextStyle(color: Colors.black45, fontSize: 12, fontFamily: 'monospace')),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('NET PAYABLE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace')),
                    Text(
                      '₹${double.parse(data['grand_total']?.toString() ?? '0').toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'monospace'),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                const Center(
                  child: Column(
                    children: [
                      Text('THANK YOU!', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'monospace')),
                      Text('Wishing you a Safe & Happy Diwali!', style: TextStyle(color: Colors.black54, fontSize: 9, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CLOSE PREVIEW', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 10, fontFamily: 'monospace')),
          Text(val, style: const TextStyle(color: Colors.black, fontSize: 10, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  // Segmented Cart bottom sheet on Mobile devices
  void _showMobileCartBottomSheet(BuildContext context, BillingProvider billingProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _buildCheckoutSection(billingProvider),
            ),
          ],
        ),
      ),
    );
  }

  // Sort popup
  void _showSortOptions(BuildContext context, ProductProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sort Firecrackers By',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const Divider(color: Colors.white10),
              _sortTile(
                title: 'Featured / Newest first',
                icon: Icons.star_border_outlined,
                active: _activeOrdering == 'created_at',
                onTap: () {
                  setState(() { _activeOrdering = 'created_at'; });
                  provider.setOrdering('created_at');
                  Navigator.pop(context);
                },
              ),
              _sortTile(
                title: 'Price: Low to High',
                icon: Icons.trending_up_outlined,
                active: _activeOrdering == 'selling_price',
                onTap: () {
                  setState(() { _activeOrdering = 'selling_price'; });
                  provider.setOrdering('selling_price');
                  Navigator.pop(context);
                },
              ),
              _sortTile(
                title: 'Price: High to Low',
                icon: Icons.trending_down_outlined,
                active: _activeOrdering == '-selling_price',
                onTap: () {
                  setState(() { _activeOrdering = '-selling_price'; });
                  provider.setOrdering('-selling_price');
                  Navigator.pop(context);
                },
              ),
              _sortTile(
                title: 'Stock Availability: Low to High',
                icon: Icons.production_quantity_limits_outlined,
                active: _activeOrdering == 'stock_quantity',
                onTap: () {
                  setState(() { _activeOrdering = 'stock_quantity'; });
                  provider.setOrdering('stock_quantity');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sortTile({
    required String title,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: active ? const Color(0xFFFF5722) : Colors.white60),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          color: active ? const Color(0xFFFF5722) : Colors.white70,
        ),
      ),
      trailing: active ? const Icon(Icons.check, color: Color(0xFFFF5722)) : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  // Active custom Qty Dialog
  void _showCustomQtyDialog(BuildContext context, BillingProvider provider, Product product) {
    final item = provider.cart.firstWhere((item) => item.product.uuid == product.uuid);
    final controller = TextEditingController(text: '${item.quantity}');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Edit Qty (${item.unit == 'CENT' ? 'Cent' : 'Box'})',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5722)),
            onPressed: () {
              provider.updateQuantity(
                product.uuid,
                int.tryParse(controller.text) ?? 0,
                product.stockQuantity,
              );
              Navigator.pop(context);
            },
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: const Color(0xFFFF5722)),
      ),
    );
  }

  Widget _buildUnitToggle({required String currentUnit, required Function(String) onToggle}) {
    return Container(
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Expanded(child: _buildUnitOption('Box', currentUnit == 'PIECE', () => onToggle('PIECE'))),
          Expanded(child: _buildUnitOption('Cent (10x)', currentUnit == 'CENT', () => onToggle('CENT'))),
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
            fontSize: 9.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.white60,
          ),
        ),
      ),
    );
  }

  final _formKey = GlobalKey<FormState>();

  // Bill Success dialog with PDF/HTML triggers
  void _showSuccessWithDownload(BuildContext context, BillingProvider provider, String invoiceId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 54),
              ),
              const SizedBox(height: 16),
              const Text('TRANSACTION COMPLETE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text(
                'Invoice created successfully.',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
              ),
              const SizedBox(height: 24),
              const Divider(color: Colors.white10),
              const SizedBox(height: 12),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(Icons.print_outlined, color: Colors.white.withOpacity(0.3), size: 16),
                  const SizedBox(width: 6),
                  const Text('PRINT & EXPORT OPTIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Colors.white38)),
                ],
              ),
              const SizedBox(height: 12),
              
              _buildPrintOption(
                icon: Icons.picture_as_pdf_outlined,
                label: 'Standard Invoice (A4 PDF)',
                subtitle: 'Export high resolution pdf ledger',
                onTap: () async => _launchInvoiceUrl(context, await provider.getInvoicePdfUrl(invoiceId)),
              ),
              const SizedBox(height: 10),
              _buildPrintOption(
                icon: Icons.chrome_reader_mode_outlined,
                label: 'Responsive HTML Bill',
                subtitle: 'Direct browser layouts & templates',
                onTap: () async => _launchInvoiceUrl(context, await provider.getInvoicePrintHtmlUrl(invoiceId)),
              ),
              const SizedBox(height: 10),
              _buildPrintOption(
                icon: Icons.receipt_long_outlined,
                label: 'Thermal Receipt (80mm)',
                subtitle: 'Direct desktop/receipt printing paper',
                onTap: () async => _launchInvoiceUrl(context, await provider.getInvoiceThermalReceiptUrl(invoiceId)),
              ),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.05),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('DISMISS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFFF5722).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: const Color(0xFFFF5722), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10.5)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: Colors.white.withOpacity(0.2)),
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
