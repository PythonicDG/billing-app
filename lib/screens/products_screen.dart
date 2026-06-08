import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../product_provider.dart';
import '../auth_provider.dart';
import '../widgets/product_form.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  _ProductsScreenState createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();
  String _activeOrdering = 'created_at';
  Timer? _debounce;

  // Pagination State
  int _currentPage = 1;
  static const int _itemsPerPage = 12;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      productProvider.fetchProducts(pageSize: 100);
      productProvider.fetchCategories();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isOwner = authProvider.role?.toUpperCase() == 'OWNER';



    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text(
              'Inventory Dashboard',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort_outlined),
            tooltip: 'Sort Inventory',
            onPressed: () {
              _showSortOptions(context, productProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh',
            onPressed: () {
              productProvider.fetchProducts(pageSize: 100);
              setState(() {
                _currentPage = 1;
              });
            },
          ),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2563EB)),
              tooltip: 'Add Firecracker',
              onPressed: () {
                _showProductForm(context);
              },
            ),
          const SizedBox(width: 8),
        ],
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      drawer: AppDrawer(currentRole: authProvider.role ?? 'VIEWER'),
      floatingActionButton: isOwner
          ? Padding(
              padding: const EdgeInsets.only(bottom: 60.0),
              child: FloatingActionButton.extended(
                backgroundColor: const Color(0xFF2563EB),
                onPressed: () => _showProductForm(context),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('ADD PRODUCT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                elevation: 4,
              ),
            )
          : null,
      body: Column(
        children: [
          // Elegant Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 14.5, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Search by product name or brand...',
                  prefixIcon: const Icon(Icons.search_outlined, color: Color(0xFF2563EB)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_outlined, size: 20, color: Color(0xFF64748B)),
                          onPressed: () {
                            _searchController.clear();
                            productProvider.setSearch('');
                            setState(() {
                              _currentPage = 1;
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _currentPage = 1;
                  });
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce = Timer(const Duration(milliseconds: 250), () {
                    productProvider.setSearch(value);
                  });
                },
                onSubmitted: (value) {
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  productProvider.setSearch(value);
                  setState(() {
                    _currentPage = 1;
                  });
                },
              ),
            ),
          ),
          
          // Inventory Header Summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Products listed: ${productProvider.products.length}',
                  style: const TextStyle(
                    color: Color(0xFF64748B), // Slate 500
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  const Text(
                    'Search filters active',
                    style: TextStyle(
                      color: Color(0xFFD97706), // Amber margin/filter
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Main Inventory Grid
          Expanded(
            child: productProvider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                  )
                : productProvider.products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.hourglass_empty_outlined,
                              size: 64,
                              color: Color(0xFF94A3B8), // Muted slate 400
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No products found',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF475569).withOpacity(0.8),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Try modifying your search query or seeding new data.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      )
                    : (() {
                        final displayedProducts = productProvider.products;
                        final totalItems = displayedProducts.length;
                        final totalPages = (totalItems / _itemsPerPage).ceil();

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

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final double estimatedContentWidth = isOwner ? 760 : 560;
                            final double availableSpacingWidth = constraints.maxWidth - estimatedContentWidth;
                            final double columnSpacing = availableSpacingWidth > 0 
                                ? (availableSpacingWidth / (isOwner ? 8 : 6)).clamp(16.0, 120.0) 
                                : 16.0;

                            return Column(
                              children: [
                                 Expanded(
                                   child: SingleChildScrollView(
                                     scrollDirection: Axis.vertical,
                                     child: SingleChildScrollView(
                                       scrollDirection: Axis.horizontal,
                                       child: ConstrainedBox(
                                         constraints: BoxConstraints(
                                           minWidth: constraints.maxWidth,
                                         ),
                                         child: DataTable(
                                           columnSpacing: columnSpacing,
                                           headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                                           dataRowMinHeight: 52,
                                           dataRowMaxHeight: 52,
                                           horizontalMargin: 20,
                                           columns: [
                                             const DataColumn(label: Text('PRODUCT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                                             const DataColumn(label: Text('BRAND', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                                             if (isOwner)
                                               const DataColumn(label: Text('PURCHASE PRICE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                                             const DataColumn(label: Text('SELLING PRICE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                                             const DataColumn(label: Text('NO. OF CASE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                                             const DataColumn(label: Text('CENT IN PER CS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                                             const DataColumn(label: Text('TOTAL STOCK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                                             if (isOwner)
                                               const DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                                           ],
                                           rows: paginatedProducts.map((product) {
                                             final isOutOfStock = product.totalStockInCent <= 0;
                                             return DataRow(
                                               cells: [
                                                 DataCell(Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5))),
                                                 DataCell(
                                                   Container(
                                                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                     decoration: BoxDecoration(
                                                       color: const Color(0xFFEFF6FF),
                                                       borderRadius: BorderRadius.circular(6),
                                                     ),
                                                     child: Text(
                                                       product.brand.toUpperCase(),
                                                       style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                                     ),
                                                   ),
                                                 ),
                                                 if (isOwner)
                                                   DataCell(Text('₹${product.purchasePrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12))),
                                                 DataCell(Text('₹${product.sellingPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF2563EB)))),
                                                 DataCell(Text('${product.noOfCase} cs', style: const TextStyle(fontSize: 12))),
                                                 DataCell(Text('${product.centInPerCs} cent', style: const TextStyle(fontSize: 12))),
                                                 DataCell(
                                                   Text(
                                                     '${product.totalStockInCent.toStringAsFixed(1)} cent',
                                                     style: TextStyle(
                                                       fontWeight: FontWeight.bold,
                                                       fontSize: 12,
                                                       color: isOutOfStock ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                                                     ),
                                                   ),
                                                 ),
                                                 if (isOwner)
                                                   DataCell(
                                                     Row(
                                                       mainAxisSize: MainAxisSize.min,
                                                       children: [
                                                         IconButton(
                                                           icon: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB), size: 18),
                                                           onPressed: () => _showProductForm(context, product: product),
                                                           constraints: const BoxConstraints(),
                                                           padding: const EdgeInsets.all(4),
                                                         ),
                                                         IconButton(
                                                           icon: const Icon(Icons.delete_outline_outlined, color: Color(0xFFEF4444), size: 18),
                                                           onPressed: () => _confirmDelete(context, product),
                                                           constraints: const BoxConstraints(),
                                                           padding: const EdgeInsets.all(4),
                                                         ),
                                                       ],
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
                            );
                          },
                        );
                      })(),
          ),
          if (_currentPage > 0 && (_currentPage <= ((productProvider.products.length / _itemsPerPage).ceil() == 0 ? 1 : (productProvider.products.length / _itemsPerPage).ceil())))
             _buildPagination((productProvider.products.length / _itemsPerPage).ceil()),
        ],
      ),
    );
  }

  Widget _buildPagination(int totalPages) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
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

          // Numbered page selectors
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(totalPages, (index) {
              final pageNum = index + 1;
              final isCurrent = pageNum == _currentPage;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () {
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
            }),
          ),

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
        ],
      ),
    );
  }

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
                    'Sort Inventory By',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const Divider(color: Color(0xFFE2E8F0)),
              _sortTile(
                title: 'Newest Added First',
                icon: Icons.calendar_month_outlined,
                active: _activeOrdering == 'created_at',
                onTap: () {
                  setState(() {
                    _activeOrdering = 'created_at';
                    _currentPage = 1;
                  });
                  provider.setOrdering('created_at');
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
                title: 'Available Stock: Low to High',
                icon: Icons.warehouse_outlined,
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

  void _showProductForm(BuildContext context, {Product? product}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ProductForm(product: product),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_outlined, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Delete Product', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: Color(0xFF475569), fontSize: 14.5),
            children: [
              const TextSpan(text: 'Are you sure you want to permanently delete '),
              TextSpan(
                text: product.name,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const TextSpan(text: '? This action cannot be undone.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () {
              Provider.of<ProductProvider>(context, listen: false).deleteProduct(product.uuid);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class AppDrawer extends StatelessWidget {
  final String currentRole;
  const AppDrawer({super.key, required this.currentRole});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF2563EB)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.local_fire_department_outlined, size: 48, color: Colors.white),
                const SizedBox(height: 16),
                const Text('Vighnaharta Fataka', style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                Text(currentRole, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Billing'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/billing');
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory),
            title: const Text('Inventory'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/inventory');
            },
          ),
          if (currentRole == 'OWNER')
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Staff Management'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/staff');
              },
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
    );
  }
}
