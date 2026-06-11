import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../billing_provider.dart';
import '../product_provider.dart';
import '../auth_provider.dart';
import '../dashboard_provider.dart';
import '../widgets/app_drawer.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  _BillingScreenState createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _paidAmountController = TextEditingController();
  final _searchController = TextEditingController();
  
  // Focus Nodes for Keyboard Navigation
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _customerNameFocusNode = FocusNode();
  final FocusNode _customerPhoneFocusNode = FocusNode();

  Timer? _debounce;

  // Map to hold controllers for each in-cart product quantity textfield to avoid focus/cursor jump
  final Map<String, TextEditingController> _qtyControllers = {};
  // Map to hold focus nodes for quantity fields to allow auto-focusing on add
  final Map<String, FocusNode> _qtyFocusNodes = {};

  // Map to hold controllers for each in-cart product price textfield to avoid focus/cursor jump
  final Map<String, TextEditingController> _priceControllers = {};

  String _paymentMethod = 'CASH';
  String _selectedCategory = 'ALL';
  String _activeOrdering = '-created_at';
  final Map<String, String> _tempUnits = {};
  
  // Pagination State
  int _currentPage = 1;
  static const int _itemsPerPage = 12;

  // For POS calculations
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      productProvider.fetchProductsForBilling(pageSize: 100);
      productProvider.fetchCategories();
      // Auto-focus search on start
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    // Correctly dispose of all dynamically created quantity controllers and focus nodes
    for (var controller in _qtyControllers.values) {
      controller.dispose();
    }
    _qtyControllers.clear();
    
    for (var node in _qtyFocusNodes.values) {
      node.dispose();
    }
    _qtyFocusNodes.clear();

    // Correctly dispose of all dynamically created price controllers
    for (var controller in _priceControllers.values) {
      controller.dispose();
    }
    _priceControllers.clear();

    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _paidAmountController.dispose();
    _searchController.dispose();
    
    _searchFocusNode.dispose();
    _customerNameFocusNode.dispose();
    _customerPhoneFocusNode.dispose();
    super.dispose();
  }

  // Helper to get or create focus node for quantity
  FocusNode _getQtyFocusNode(String uuid) {
    return _qtyFocusNodes.putIfAbsent(uuid, () => FocusNode());
  }

  // Keyboard Shortcut Actions
  void _onF1Pressed() {
    _searchFocusNode.requestFocus();
    _searchController.selection = TextSelection(baseOffset: 0, extentOffset: _searchController.text.length);
  }

  void _onF2Pressed(BillingProvider provider) {
    _showCheckoutWizard(context, provider);
  }

  void _onEscPressed() {
    if (_searchFocusNode.hasFocus) {
      _searchController.clear();
      Provider.of<ProductProvider>(context, listen: false).setBillingSearch('');
    } else {
      _searchFocusNode.requestFocus();
    }
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

  TextEditingController _getQuantityController(String productUuid, int quantity) {
    final controller = _qtyControllers.putIfAbsent(productUuid, () {
      return TextEditingController(text: '$quantity');
    });
    if (controller.text != '$quantity') {
      controller.text = '$quantity';
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
    }
    return controller;
  }

  TextEditingController _getPriceController(String productUuid, double price) {
    final controller = _priceControllers.putIfAbsent(productUuid, () {
      return TextEditingController(text: '$price');
    });
    final parsedVal = double.tryParse(controller.text) ?? -1.0;
    if (parsedVal != price) {
      controller.text = '$price';
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
    }
    return controller;
  }

  @override
  Widget build(BuildContext context) {
    final billingProvider = Provider.of<BillingProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    // Apply dynamic filtering locally over loaded products
    final String searchQuery = _searchController.text.toLowerCase();
    List<Product> displayedProducts = productProvider.billingProducts.where((p) {
      return p.name.toLowerCase().contains(searchQuery);
    }).toList();

    double screenWidth = MediaQuery.of(context).size.width;
    bool isWidePOSLayout = screenWidth >= 1024;

    return CallbackShortcuts(
      bindings: {
        SingleActivator(LogicalKeyboardKey.keyF, control: true): () => _onF1Pressed(), // Ctrl+F Search
        SingleActivator(LogicalKeyboardKey.keyB, control: true): () => _onF2Pressed(billingProvider), // Ctrl+B Checkout
        SingleActivator(LogicalKeyboardKey.keyR, control: true): () => productProvider.fetchProductsForBilling(pageSize: 100), // Ctrl+R Refresh
        SingleActivator(LogicalKeyboardKey.escape): () => _onEscPressed(),
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.bolt, color: Color(0xFFD97706)), // Elegant Amber gold bolt
              SizedBox(width: 8),
              Text(
                'Vighnaharta POS Billing',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_outlined),
              tooltip: 'Refresh Inventory (Ctrl+R)',
              onPressed: () => productProvider.fetchProductsForBilling(pageSize: 100),
            ),
            if (!isWidePOSLayout)
              _buildCartBadgeButton(billingProvider),
            const SizedBox(width: 8),
          ],
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        drawer: const AppDrawer(),
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
                  VerticalDivider(color: const Color(0xFFE2E8F0), width: 1, thickness: 1),
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
      ),
    );
  }

  // Cart badge icon on Top App Bar
  Widget _buildCartBadgeButton(BillingProvider billingProvider) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.shopping_bag_outlined),
          tooltip: 'Active Cart (Ctrl+B)',
          onPressed: () => _showMobileCartBottomSheet(context, billingProvider),
        ),
        if (billingProvider.cart.isNotEmpty)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB), // Premium Theme Blue
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
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
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
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  currencyFormat.format(billingProvider.grandTotal),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                ),
              ],
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _showMobileCartBottomSheet(context, billingProvider),
              icon: const Icon(Icons.shopping_cart_checkout_outlined, size: 18),
              label: const Text(
                'CHECKOUT (Ctrl+B)',
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
    double childAspectRatio = width < 500 ? 1.7 : 1.35;

    // Local pagination calculations
    final totalItems = displayedProducts.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();
    
    // Safety check for current page bounds
    if (_currentPage > totalPages && totalPages > 0) {
      _currentPage = totalPages;
    } else if (_currentPage < 1) {
      _currentPage = 1;
    }
    
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    final paginatedProducts = totalItems == 0 
        ? <Product>[] 
        : displayedProducts.sublist(
            startIndex, 
            endIndex > totalItems ? totalItems : endIndex,
          );

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
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 3))
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Quick find firecrackers... (Ctrl+F)',
                      prefixIcon: const Icon(Icons.search_outlined, color: Color(0xFF2563EB), size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_outlined, size: 18, color: Color(0xFF64748B)),
                              onPressed: () {
                                _searchController.clear();
                                productProvider.setBillingSearch('');
                                setState(() {
                                  _currentPage = 1;
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
                      ),
                    ),
                    onChanged: (v) {
                       setState(() {
                         _currentPage = 1;
                       });
                       if (_debounce?.isActive ?? false) _debounce!.cancel();
                       _debounce = Timer(const Duration(milliseconds: 250), () {
                         productProvider.setBillingSearch(v);
                       });
                     },
                     onSubmitted: (v) {
                       if (_debounce?.isActive ?? false) _debounce!.cancel();
                       productProvider.setBillingSearch(v);
                       setState(() {
                         _currentPage = 1;
                       });
                       
                       // KEYBOARD OPTIMIZATION: If results found, add the first one and focus its Qty
                       if (paginatedProducts.isNotEmpty) {
                         final product = paginatedProducts.first;
                         final unit = _tempUnits[product.uuid] ?? 'CENT';
                         billingProvider.addToCart(product, unit: unit);
                         
                         // Auto focus the quantity field of the added item
                         WidgetsBinding.instance.addPostFrameCallback((_) {
                           _getQtyFocusNode(product.uuid).requestFocus();
                         });
                       }
                     },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: IconButton(
                  icon: const Icon(Icons.swap_vert_outlined, color: Color(0xFF475569)),
                  tooltip: 'Sort Options',
                  onPressed: () => _showSortOptions(context, productProvider),
                ),
              ),
            ],
          ),
        ),

        // Products Grid
        Expanded(
          child: productProvider.isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
              : paginatedProducts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off_outlined, size: 48, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 12),
                          const Text('No firecrackers found', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold)),
                          const Text('Try a different search category or search text.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: paginatedProducts.length,
                      separatorBuilder: (context, index) => const Divider(color: Color(0xFFE2E8F0), height: 1),
                      itemBuilder: (context, index) {
                        final product = paginatedProducts[index];
                        return _buildECommerceProductCard(product, billingProvider);
                      },
                    ),
        ),

        // Numbered Pagination Controls
        if (totalPages > 1)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left buttons: FIRST & PREV
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // FIRST button
                    InkWell(
                      onTap: _currentPage > 1
                          ? () {
                              setState(() {
                                _currentPage = 1;
                              });
                            }
                          : null,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _currentPage > 1 ? const Color(0xFFEFF6FF) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.first_page_outlined,
                              size: 18,
                              color: _currentPage > 1 ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'FIRST',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _currentPage > 1 ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // PREVIOUS button
                    InkWell(
                      onTap: _currentPage > 1
                          ? () {
                              setState(() {
                                _currentPage--;
                              });
                            }
                          : null,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _currentPage > 1 ? const Color(0xFFEFF6FF) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chevron_left_outlined,
                              size: 18,
                              color: _currentPage > 1 ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'PREV',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _currentPage > 1 ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Center page count label + numbered page selectors
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Page $_currentPage of $totalPages',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 12),
                    ...(() {
                      final List<dynamic> items = [];
                      if (totalPages <= 1) return <Widget>[];

                      // Page 1 always
                      items.add(1);

                      int start = _currentPage - 2;
                      int end = _currentPage + 2;

                      if (start <= 2) {
                        start = 2;
                      }
                      if (end >= totalPages - 1) {
                        end = totalPages - 1;
                      }

                      if (start > 2) {
                        items.add('...');
                      }

                      for (int i = start; i <= end; i++) {
                        if (i > 1 && i < totalPages) {
                          items.add(i);
                        }
                      }

                      if (end < totalPages - 1) {
                        items.add('...');
                      }

                      // Last page always
                      items.add(totalPages);

                      return items.map((item) {
                        if (item is String) {
                          return Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            child: const Text(
                              '...',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          );
                        } else {
                          final pageNum = item as int;
                          final isCurrent = pageNum == _currentPage;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: InkWell(
                              onTap: isCurrent
                                  ? null
                                  : () {
                                      setState(() {
                                        _currentPage = pageNum;
                                      });
                                    },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isCurrent ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isCurrent ? Colors.transparent : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Text(
                                  '$pageNum',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: isCurrent ? Colors.white : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                      }).toList();
                    })(),
                  ],
                ),

                // Right buttons: NEXT & LAST
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // NEXT button
                    InkWell(
                      onTap: _currentPage < totalPages
                          ? () {
                              setState(() {
                                _currentPage++;
                              });
                            }
                          : null,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _currentPage < totalPages ? const Color(0xFFEFF6FF) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'NEXT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _currentPage < totalPages ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right_outlined,
                              size: 18,
                              color: _currentPage < totalPages ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // LAST button
                    InkWell(
                      onTap: _currentPage < totalPages
                          ? () {
                              setState(() {
                                _currentPage = totalPages;
                              });
                            }
                          : null,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _currentPage < totalPages ? const Color(0xFFEFF6FF) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'LAST',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _currentPage < totalPages ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.last_page_outlined,
                              size: 18,
                              color: _currentPage < totalPages ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Beautiful Amazon/Flipkart style Product Grid Card
  Widget _buildECommerceProductCard(Product product, BillingProvider billingProvider) {
    final isInCart = billingProvider.cart.any((item) => item.product.uuid == product.uuid);
    final cartItem = isInCart ? billingProvider.cart.firstWhere((item) => item.product.uuid == product.uuid) : null;
    
    final selectedUnit = isInCart ? cartItem!.unit : (_tempUnits[product.uuid] ?? 'CENT');
    final currentPrice = selectedUnit == 'CENT' ? product.sellingPrice * 10 : product.sellingPrice;
    
    final isOutOfStock = product.totalStockInCent <= 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isInCart ? const Color(0xFFEFF6FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Icon and Details
          Expanded(
            flex: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        product.brand.toUpperCase(),
                        style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isOutOfStock ? 'Sold Out' : '${product.totalStockInCent.toStringAsFixed(1)} cent left',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isOutOfStock ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Pricing
          Expanded(
            flex: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RATE',
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                ),
                Text(
                  currencyFormat.format(currentPrice),
                  style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
          
          // Unit Selection
          Expanded(
            flex: 20,
            child: Center(
              child: _buildUnitToggle(
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
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Action Button / Qty Control
          Expanded(
            flex: 20,
            child: SizedBox(
              height: 32,
              child: cartItem != null
                  ? Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildQtyBtn(
                            Icons.remove,
                            () => billingProvider.updateQuantity(
                              product.uuid,
                              cartItem.quantity - 1,
                              product.stockQuantity,
                            ),
                          ),
                          SizedBox(
                            width: 32,
                            child: TextField(
                              controller: _getQuantityController(product.uuid, cartItem.quantity),
                              focusNode: _getQtyFocusNode(product.uuid),
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF2563EB)),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (value) {
                                if (value.isNotEmpty) {
                                  final newQty = int.tryParse(value);
                                  if (newQty != null) {
                                    billingProvider.updateQuantity(
                                      product.uuid,
                                      newQty,
                                      product.stockQuantity,
                                    );
                                  }
                                }
                              },
                              onSubmitted: (_) {
                                // KEYBOARD OPTIMIZATION: On enter from quantity, jump back to search
                                _searchFocusNode.requestFocus();
                                _searchController.selection = TextSelection(baseOffset: 0, extentOffset: _searchController.text.length);
                              },
                            ),
                          ),
                          _buildQtyBtn(
                            Icons.add,
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
                        backgroundColor: const Color(0xFF0F2C59),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: !isOutOfStock
                          ? () => billingProvider.addToCart(product, unit: selectedUnit)
                          : null,
                      child: const Text(
                        'ADD',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // Active Checkout right side POS panel / sheet
  Widget _buildCheckoutSection(BillingProvider billingProvider) {
    return Container(
      color: const Color(0xFFF8FAFC), // Cool slate-50 background
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shopping_basket_outlined, color: Color(0xFF2563EB), size: 20),
                    SizedBox(width: 8),
                    Text('Active Billing Cart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
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
                      color: billingProvider.cart.isNotEmpty ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
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
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 40, color: Color(0xFF94A3B8)),
                        SizedBox(height: 12),
                        Text('Your cart is empty', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold)),
                        Text('Click ADD TO CART on any firecracker.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      // INLINE EDITABLE PRICE TEXTFIELD inside the Checkout list
                                      SizedBox(
                                        width: 58,
                                        height: 24,
                                        child: Container(
                                          alignment: Alignment.centerLeft,
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                                          ),
                                          child: Row(
                                            children: [
                                              const Text(
                                                '₹',
                                                style: TextStyle(
                                                  color: Color(0xFF475569),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Expanded(
                                                child: TextField(
                                                  controller: _getPriceController(item.product.uuid, item.unitPrice),
                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                  style: const TextStyle(
                                                    color: Color(0xFF0F172A),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10.5,
                                                  ),
                                                  decoration: const InputDecoration(
                                                    border: InputBorder.none,
                                                    isDense: true,
                                                    contentPadding: EdgeInsets.only(left: 2),
                                                  ),
                                                  onChanged: (value) {
                                                    if (value.isNotEmpty) {
                                                      final newPrice = double.tryParse(value);
                                                      if (newPrice != null && newPrice >= 0) {
                                                        billingProvider.updateUnitPrice(item.product.uuid, newPrice);
                                                      }
                                                    }
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const Text(
                                        ' x ',
                                        style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                      ),
                                      // INLINE EDITABLE QUANTITY TEXTFIELD inside the Checkout list
                                      SizedBox(
                                        width: 42,
                                        height: 24,
                                        child: Container(
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.3), width: 1),
                                          ),
                                          child: TextField(
                                            controller: _getQuantityController(item.product.uuid, item.quantity),
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Color(0xFF2563EB),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              isDense: true,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                            onChanged: (value) {
                                              if (value.isNotEmpty) {
                                                final newQty = int.tryParse(value);
                                                if (newQty != null && newQty > 0) {
                                                  billingProvider.updateQuantity(
                                                    item.product.uuid,
                                                    newQty,
                                                    item.product.stockQuantity,
                                                  );
                                                }
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                      Text(
                                        ' ${item.unit == 'CENT' ? 'Cent' : 'Unit'}',
                                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.product.brand,
                                          style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
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
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2563EB)),
                                ),
                                GestureDetector(
                                  onTap: () => billingProvider.removeFromCart(item.product.uuid),
                                  child: const Padding(
                                    padding: EdgeInsets.only(top: 4.0),
                                    child: Icon(Icons.delete_forever_outlined, color: Color(0xFFEF4444), size: 16),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('BILLING PAYMENT BREAKDOWN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Color(0xFF94A3B8))),
          const SizedBox(height: 10),
          _summaryRow('Subtotal', currencyFormat.format(billingProvider.subTotal)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(color: Color(0xFFE2E8F0), thickness: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Grand Net Total', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              Text(
                currencyFormat.format(billingProvider.grandTotal),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
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
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 1,
              ),
              onPressed: () => _showCheckoutWizard(context, billingProvider),
              icon: const Icon(Icons.security_outlined, size: 20, color: Colors.white),
              label: const Text(
                'CHECKOUT & GENERATE BILL',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, fontSize: 13.5, color: Colors.white),
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
          Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
          Text(
            value,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: textColor ?? const Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }
   // Interactive Payment & Checkout Wizard
  void _showCheckoutWizard(BuildContext context, BillingProvider provider) {
    _paidAmountController.text = provider.grandTotal.toString();
    _customerNameController.clear();
    _customerPhoneController.clear();
    _paymentMethod = 'CASH';
    double changeAmount = 0.0;
    
    // Auto focus customer name when wizard opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _customerNameFocusNode.requestFocus();
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Live calculation of cash change
          double paidVal = double.tryParse(_paidAmountController.text) ?? 0.0;
          changeAmount = paidVal - provider.grandTotal;
          if (changeAmount < 0) changeAmount = 0.0;

          return RawKeyboardListener(
            focusNode: FocusNode(), // Temporary node for local listening
            onKey: (event) {
              if (event is RawKeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.digit1 || event.logicalKey == LogicalKeyboardKey.numpad1) {
                  setModalState(() { _paymentMethod = 'CASH'; });
                } else if (event.logicalKey == LogicalKeyboardKey.digit2 || event.logicalKey == LogicalKeyboardKey.numpad2) {
                  setModalState(() { _paymentMethod = 'UPI'; });
                }
              }
            },
            child: CallbackShortcuts(
              bindings: {
                SingleActivator(LogicalKeyboardKey.escape): () => Navigator.pop(context),
                SingleActivator(LogicalKeyboardKey.enter, control: true): () => _onConfirmPressed(provider), // Ctrl+Enter Confirm
              },
              child: Padding(
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
                          decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Icon(Icons.payment_outlined, color: Color(0xFF2563EB)),
                          SizedBox(width: 8),
                          Text('Billing Checkout Portal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          Spacer(),
                          Text('ESC to close', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                        ],
                      ),
                      const Divider(color: Color(0xFFE2E8F0), height: 24),
  
                      // Customer Profile
                      const Text('CUSTOMER PROFILE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Color(0xFF94A3B8))),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 60,
                              child: Autocomplete<Customer>(
                                textEditingController: _customerNameController,
                                focusNode: _customerNameFocusNode,
                                optionsBuilder: (TextEditingValue textEditingValue) async {
                                  if (textEditingValue.text.isEmpty) {
                                    return const Iterable<Customer>.empty();
                                  }
                                  return await provider.searchCustomers(textEditingValue.text);
                                },
                                displayStringForOption: (Customer option) => option.name,
                                onSelected: (Customer selection) {
                                  setModalState(() {
                                    _customerPhoneController.text = selection.phone;
                                  });
                                  _customerPhoneFocusNode.requestFocus();
                                },
                                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                  return TextFormField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) => _customerPhoneFocusNode.requestFocus(),
                                    decoration: const InputDecoration(
                                      labelText: 'Customer Name',
                                      prefixIcon: Icon(Icons.person_outline),
                                      filled: true,
                                      fillColor: Color(0xFFF8FAFC),
                                    ),
                                    validator: (v) => v!.isEmpty ? 'Enter customer name' : null,
                                  );
                                },
                                optionsViewBuilder: (context, onSelected, options) {
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 4,
                                      child: Container(
                                        width: 300,
                                        constraints: const BoxConstraints(maxHeight: 200),
                                        child: ListView.builder(
                                          padding: EdgeInsets.zero,
                                          shrinkWrap: true,
                                          itemCount: options.length,
                                          itemBuilder: (context, index) {
                                            final option = options.elementAt(index);
                                            return ListTile(
                                              title: Text(option.name),
                                              subtitle: Text(option.phone),
                                              onTap: () => onSelected(option),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Quick autocomplete walk-in client
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF2563EB)),
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              setModalState(() {
                                _customerNameController.text = 'Walk-In Customer';
                                _customerPhoneController.text = '9999999999';
                              });
                            },
                            child: const Text('WALK-IN', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _customerPhoneController,
                        focusNode: _customerPhoneFocusNode,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) {
                          if (_paymentMethod == 'CASH') {
                            _paidAmountController.selection = TextSelection(baseOffset: 0, extentOffset: _paidAmountController.text.length);
                            // Set focus to paid amount would happen here if we had a node, but let's let standard Next handle it
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number',
                          prefixIcon: Icon(Icons.phone_outlined),
                          filled: true,
                          fillColor: Color(0xFFF8FAFC),
                        ),
                        onChanged: (phone) async {
                          if (phone.length == 10) {
                            final results = await provider.searchCustomers(phone);
                            final exactMatch = results.firstWhere(
                              (c) => c.phone.trim() == phone.trim(),
                              orElse: () => Customer(id: '', name: '', phone: ''),
                            );
                            if (exactMatch.id.isNotEmpty) {
                              setModalState(() {
                                _customerNameController.text = exactMatch.name;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Loaded existing customer: ${exactMatch.name}'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 20),
  
                      // Payment details
                      const Text('PAYMENT DETAILS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Color(0xFF94A3B8))),
                      const SizedBox(height: 10),
                      
                      // Segmented Payment Method Selector
                      Container(
                        height: 46,
                        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.all(3),
                        child: Row(
                          children: [
                            Expanded(child: _paymentSegment('CASH (1)', Icons.money_outlined, _paymentMethod == 'CASH', () {
                              setModalState(() { _paymentMethod = 'CASH'; });
                            })),
                            Expanded(child: _paymentSegment('UPI (2)', Icons.qr_code_outlined, _paymentMethod == 'UPI', () {
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
                                style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                                decoration: const InputDecoration(
                                  labelText: 'Received Cash (₹)',
                                  prefixIcon: Icon(Icons.payments_outlined),
                                  filled: true,
                                  fillColor: Color(0xFFF8FAFC),
                                ),
                                onFieldSubmitted: (_) {
                                  // Trigger confirm on Enter in cash field
                                  _onConfirmPressed(provider);
                                },
                                onChanged: (v) {
                                  setModalState(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A).withOpacity(0.08), // Soft emerald tint
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('RETURN CHANGE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                                  Text(
                                    currencyFormat.format(changeAmount),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ] else if (_paymentMethod == 'UPI') ...[
                        // Simulated UPI Scan code
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: const Icon(Icons.qr_code_2_outlined, color: Color(0xFF0F172A), size: 50),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('UPI INSTANT QR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                                    SizedBox(height: 4),
                                    Text(
                                      'Instruct client to scan the active POS scanner screen or billing desk card.',
                                      style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      ],
  
                      const SizedBox(height: 24),
                      const Divider(color: Color(0xFFE2E8F0)),
  
                      // Net Pay and Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('NET TO COLLECT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                              Text(currencyFormat.format(provider.grandTotal), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                            ],
                          ),
                          if (provider.isLoading)
                            const CircularProgressIndicator(color: Color(0xFF2563EB))
                          else
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  ),
                                  onPressed: () async {
                                    if (_formKey.currentState!.validate()) {
                                      final preview = await provider.previewInvoice(
                                        customerName: _customerNameController.text,
                                        customerPhone: _customerPhoneController.text,
                                        paidAmount: _paymentMethod == 'CASH' ? (double.tryParse(_paidAmountController.text) ?? 0.0) : provider.grandTotal,
                                        paymentMethod: _paymentMethod,
                                      );
                                      if (preview != null) {
                                        _showThermalReceiptPreview(context, preview);
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Preview Failed: ${provider.errorMessage ?? "Unknown error"}'),
                                            backgroundColor: const Color(0xFFEF4444),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.preview_outlined, size: 16, color: Color(0xFF475569)),
                                  label: const Text('PREVIEW', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  ),
                                  onPressed: () => _onConfirmPressed(provider),
                                  icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
                                  label: const Text('CONFIRM (Ctrl+Ent)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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
            ),
          ),
        );
      },
      ),
    );
  }

  void _onConfirmPressed(BillingProvider provider) async {
    if (_formKey.currentState!.validate()) {
      final invoiceId = await provider.createInvoice(
        customerName: _customerNameController.text,
        customerPhone: _customerPhoneController.text,
        paidAmount: _paymentMethod == 'CASH' ? (double.tryParse(_paidAmountController.text) ?? 0.0) : provider.grandTotal,
        paymentMethod: _paymentMethod,
      );
      if (invoiceId != null) {
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).clearSnackBars();
        final productProvider = Provider.of<ProductProvider>(context, listen: false);
        productProvider.fetchProducts(pageSize: 100);
        _showSuccessWithDownload(context, provider, invoiceId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Creation Failed: ${provider.errorMessage ?? "Unknown error"}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Widget _paymentSegment(String label, IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
              ? [BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: active ? Colors.white : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: active ? Colors.white : const Color(0xFF64748B),
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
                  Text('Ph  : +91 ${data['customer_phone']}', style: const TextStyle(color: Colors.black, fontSize: 11, fontFamily: 'monospace')),
                Text('Mode: ${data['payment_method']?.toString().toUpperCase() ?? "CASH"}', style: const TextStyle(color: Colors.black, fontSize: 11, fontFamily: 'monospace')),
                
                const Text('--------------------------------', style: TextStyle(color: Colors.black45, fontSize: 12, fontFamily: 'monospace')),
                
                // Item Header
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('ITEM DESCRIPTION', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
                    Text('QTY', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                    SizedBox(width: 16),
                    Text('AMOUNT', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  ],
                ),
                const Text('--------------------------------', style: TextStyle(color: Colors.black45, fontSize: 12, fontFamily: 'monospace')),
                
                // Items Loop
                ...itemsList.map((item) {
                  // Resolve product name from model locally if possible
                  final pProvider = Provider.of<ProductProvider>(context, listen: false);
                  final matchingProduct = pProvider.billingProducts.firstWhere(
                    (p) => p.uuid == item['product'],
                    orElse: () => Product(uuid: '', name: 'Firecracker Item', brand: '', sellingPrice: 0, mrp: 0, purchasePrice: 0, stockQuantity: 0, minStockLevel: 0, noOfCase: 0, centInPerCs: 0, totalStockInCent: 0.0),
                  );

                  double totPrice = (double.tryParse(item['quantity']?.toString() ?? '0') ?? 0.0) * (double.tryParse(item['unit_price']?.toString() ?? '0') ?? 0.0);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          matchingProduct.name.toUpperCase(),
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'monospace'),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "  ${item['quantity']} ${item['unit']?.toString().toLowerCase() == 'piece' ? 'unit' : (item['unit']?.toString().toLowerCase() ?? 'unit')} @ ₹${double.parse(item['unit_price']?.toString() ?? '0').toStringAsFixed(2)}",
                              style: const TextStyle(color: Colors.black87, fontSize: 10, fontFamily: 'monospace'),
                            ),
                            Text(
                              "₹${totPrice.toStringAsFixed(2)}",
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
                
                const Text('--------------------------------', style: TextStyle(color: Colors.black45, fontSize: 12, fontFamily: 'monospace')),
                
                // Calculations
                _receiptRow('SUB-TOTAL', '₹${double.parse(data['sub_total']?.toString() ?? '0').toStringAsFixed(2)}'),
                if (double.parse(data['tax_amount']?.toString() ?? '0') > 0)
                  _receiptRow('TAX / GST', '₹${double.parse(data['tax_amount']?.toString() ?? '0').toStringAsFixed(2)}'),
                if (double.parse(data['discount_amount']?.toString() ?? '0') > 0)
                  _receiptRow('DISCOUNT', '-₹${double.parse(data['discount_amount']?.toString() ?? '0').toStringAsFixed(2)}'),
                
                const Text('--------------------------------', style: TextStyle(color: Colors.black45, fontSize: 12, fontFamily: 'monospace')),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('GRAND TOTAL', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace')),
                    Text(
                      '₹${double.parse(data['grand_total']?.toString() ?? '0').toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'monospace'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _receiptRow('AMOUNT PAID', '₹${double.parse(data['paid_amount']?.toString() ?? '0').toStringAsFixed(2)}'),
                
                // Due / Outstanding
                (() {
                  double total = double.parse(data['grand_total']?.toString() ?? '0');
                  double paid = double.parse(data['paid_amount']?.toString() ?? '0');
                  double due = (total - paid).clamp(0, double.infinity);
                  return _receiptRow(
                    'OUTSTANDING DUE', 
                    '₹${due.toStringAsFixed(2)}',
                  );
                })(),
                
                const Text('--------------------------------', style: TextStyle(color: Colors.black45, fontSize: 12, fontFamily: 'monospace')),
                
                const SizedBox(height: 12),
                const Center(
                  child: Column(
                    children: [
                      Text('THANK YOU! VISIT AGAIN', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'monospace')),
                      SizedBox(height: 2),
                      Text('Wishing you a Safe & Happy Celebration!', style: TextStyle(color: Colors.black54, fontSize: 9, fontFamily: 'monospace')),
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
      backgroundColor: Colors.white,
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
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(10)),
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
      backgroundColor: Colors.white,
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
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const Divider(color: Color(0xFFE2E8F0)),
              _sortTile(
                title: 'Featured / Newest first',
                icon: Icons.star_border_outlined,
                active: _activeOrdering == '-created_at',
                onTap: () {
                  setState(() {
                    _activeOrdering = '-created_at';
                    _currentPage = 1;
                  });
                  provider.setOrdering('-created_at');
                  Navigator.pop(context);
                },
              ),
              _sortTile(
                title: 'Price: Low to High',
                icon: Icons.trending_up_outlined,
                active: _activeOrdering == 'selling_price',
                onTap: () {
                  setState(() {
                    _activeOrdering = 'selling_price';
                    _currentPage = 1;
                  });
                  provider.setOrdering('selling_price');
                  Navigator.pop(context);
                },
              ),
              _sortTile(
                title: 'Price: High to Low',
                icon: Icons.trending_down_outlined,
                active: _activeOrdering == '-selling_price',
                onTap: () {
                  setState(() {
                    _activeOrdering = '-selling_price';
                    _currentPage = 1;
                  });
                  provider.setOrdering('-selling_price');
                  Navigator.pop(context);
                },
              ),
              _sortTile(
                title: 'Stock Availability: Low to High',
                icon: Icons.production_quantity_limits_outlined,
                active: _activeOrdering == 'stock_quantity',
                onTap: () {
                  setState(() {
                    _activeOrdering = 'stock_quantity';
                    _currentPage = 1;
                  });
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
      leading: Icon(icon, color: active ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          color: active ? const Color(0xFF2563EB) : const Color(0xFF334155),
        ),
      ),
      trailing: active ? const Icon(Icons.check, color: Color(0xFF2563EB)) : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        child: Icon(icon, size: 16, color: const Color(0xFF2563EB)),
      ),
    );
  }

  Widget _buildUnitToggle({required String currentUnit, required Function(String) onToggle}) {
    return Container(
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Expanded(child: _buildUnitOption('Unit', currentUnit == 'PIECE', () => onToggle('PIECE'))),
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
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
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
      builder: (context) => CallbackShortcuts(
        bindings: {
          SingleActivator(LogicalKeyboardKey.escape): () {
            Navigator.pop(context);
          },
        },
        child: Dialog(
          backgroundColor: Colors.white,
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
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 54),
                ),
                const SizedBox(height: 16),
                const Text('TRANSACTION COMPLETE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Color(0xFF0F172A))),
                const SizedBox(height: 4),
                const Text(
                  'Invoice created successfully.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
                const SizedBox(height: 24),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 12),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const Icon(Icons.print_outlined, color: Color(0xFF94A3B8), size: 16),
                    const SizedBox(width: 6),
                    const Text('PRINT & EXPORT OPTIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Color(0xFF64748B))),
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
                      backgroundColor: const Color(0xFFF1F5F9),
                      foregroundColor: const Color(0xFF0F172A),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('DISMISS', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
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
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: const Color(0xFF2563EB), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFF94A3B8)),
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
