import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      productProvider.fetchProducts(pageSize: 12);
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
    final isOwner = true;



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
              Provider.of<ProductProvider>(context, listen: false).fetchProducts(pageSize: 12);
            },
          ),
          if (isOwner) ...[
            IconButton(
              icon: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF2563EB)),
              tooltip: 'Bulk Upload',
              onPressed: () {
                _showBulkUploadDialog(context, productProvider);
              },
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2563EB)),
              tooltip: 'Add Firecracker',
              onPressed: () {
                _showProductForm(context);
              },
            ),
          ],
          const SizedBox(width: 8),
        ],
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // Elegant Search Bar with Inline Add Action
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Expanded(
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
                        if (_debounce?.isActive ?? false) _debounce!.cancel();
                        _debounce = Timer(const Duration(milliseconds: 250), () {
                          productProvider.setSearch(value);
                        });
                      },
                      onSubmitted: (value) {
                        if (_debounce?.isActive ?? false) _debounce!.cancel();
                        productProvider.setSearch(value);
                      },
                    ),
                  ),
                ),
                if (isOwner) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => _showProductForm(context),
                      icon: const Icon(Icons.add, color: Colors.white, size: 20),
                      label: const Text(
                        'ADD PRODUCT',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ],
              ],
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
                        final provider = productProvider;
                        final paginatedProducts = provider.products;

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final double minWidth = isOwner ? 1000.0 : 800.0;
                            final double tableWidth = constraints.maxWidth > minWidth ? constraints.maxWidth : minWidth;

                            final double prodWidth = isOwner ? tableWidth * 0.19 : tableWidth * 0.25;
                            final double brandWidth = isOwner ? tableWidth * 0.10 : tableWidth * 0.11;
                            final double purchaseWidth = isOwner ? tableWidth * 0.11 : 0.0;
                            final double sellingWidth = isOwner ? tableWidth * 0.11 : tableWidth * 0.14;
                            final double casesWidth = isOwner ? tableWidth * 0.09 : tableWidth * 0.11;
                            final double centCsWidth = isOwner ? tableWidth * 0.10 : tableWidth * 0.12;
                            final double stockWidth = isOwner ? tableWidth * 0.10 : tableWidth * 0.12;
                            final double statusWidth = isOwner ? tableWidth * 0.12 : tableWidth * 0.15;
                            final double actionsWidth = isOwner ? tableWidth * 0.08 : 0.0;

                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: tableWidth,
                                child: Column(
                                  children: [
                                    // Sticky Header Row
                                    DataTable(
                                      columnSpacing: 0,
                                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                                      headingRowHeight: 48,
                                      horizontalMargin: 12,
                                      columns: [
                                        DataColumn(label: SizedBox(width: prodWidth, child: const Text('PRODUCT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569))))),
                                        DataColumn(label: SizedBox(width: brandWidth, child: const Text('BRAND', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569))))),
                                        if (isOwner)
                                          DataColumn(label: SizedBox(width: purchaseWidth, child: const Text('PURCHASE PRICE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569))))),
                                        DataColumn(label: SizedBox(width: sellingWidth, child: const Text('SELLING PRICE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569))))),
                                        DataColumn(label: SizedBox(width: casesWidth, child: const Text('NO. OF CASE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569))))),
                                        DataColumn(label: SizedBox(width: centCsWidth, child: const Text('CENT IN PER CS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569))))),
                                        DataColumn(label: SizedBox(width: stockWidth, child: const Text('TOTAL STOCK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569))))),
                                        DataColumn(label: SizedBox(width: statusWidth, child: const Text('STOCK STATUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569))))),
                                        if (isOwner)
                                          DataColumn(label: SizedBox(width: actionsWidth, child: const Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569))))),
                                      ],
                                      rows: const [],
                                    ),
                                    
                                    // Scrollable Data Rows
                                    Expanded(
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.vertical,
                                        child: DataTable(
                                          columnSpacing: 0,
                                          headingRowHeight: 0,
                                          dataRowMinHeight: 52,
                                          dataRowMaxHeight: 52,
                                          horizontalMargin: 12,
                                          columns: [
                                            DataColumn(label: SizedBox(width: prodWidth)),
                                            DataColumn(label: SizedBox(width: brandWidth)),
                                            if (isOwner)
                                              DataColumn(label: SizedBox(width: purchaseWidth)),
                                            DataColumn(label: SizedBox(width: sellingWidth)),
                                            DataColumn(label: SizedBox(width: casesWidth)),
                                            DataColumn(label: SizedBox(width: centCsWidth)),
                                            DataColumn(label: SizedBox(width: stockWidth)),
                                            DataColumn(label: SizedBox(width: statusWidth)),
                                            if (isOwner)
                                              DataColumn(label: SizedBox(width: actionsWidth)),
                                          ],
                                          rows: paginatedProducts.map((product) {
                                            final isOutOfStock = product.totalStockInCent <= 0;
                                            final isLowStock = product.totalStockInCent > 0 && product.totalStockInCent <= product.minStockLevel;
                                            return DataRow(
                                              cells: [
                                                DataCell(SizedBox(width: prodWidth, child: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5), overflow: TextOverflow.ellipsis))),
                                                DataCell(
                                                  SizedBox(
                                                    width: brandWidth,
                                                    child: Align(
                                                      alignment: Alignment.centerLeft,
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFEFF6FF),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Text(
                                                          product.brand.toUpperCase(),
                                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                if (isOwner)
                                                  DataCell(SizedBox(width: purchaseWidth, child: Text('₹${product.purchasePrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)))),
                                                DataCell(SizedBox(width: sellingWidth, child: Text('₹${product.sellingPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF2563EB))))),
                                                DataCell(SizedBox(width: casesWidth, child: Text('${product.noOfCase} cs', style: const TextStyle(fontSize: 12)))),
                                                DataCell(SizedBox(width: centCsWidth, child: Text('${product.centInPerCs} cent', style: const TextStyle(fontSize: 12)))),
                                                DataCell(
                                                  SizedBox(
                                                    width: stockWidth,
                                                    child: Text(
                                                      '${product.totalStockInCent.toStringAsFixed(1)} cent',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                        color: isOutOfStock
                                                            ? const Color(0xFFEF4444)
                                                            : isLowStock
                                                                ? const Color(0xFFF97316)
                                                                : const Color(0xFF16A34A),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  SizedBox(
                                                    width: statusWidth,
                                                    child: Align(
                                                      alignment: Alignment.centerLeft,
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: isOutOfStock
                                                              ? const Color(0xFFFEF2F2)
                                                              : isLowStock
                                                                  ? const Color(0xFFFFF7ED)
                                                                  : const Color(0xFFF0FDF4),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Text(
                                                          isOutOfStock ? 'OUT OF STOCK' : isLowStock ? 'LOW STOCK' : 'IN STOCK',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                            color: isOutOfStock
                                                                ? const Color(0xFFEF4444)
                                                                : isLowStock
                                                                    ? const Color(0xFFF97316)
                                                                    : const Color(0xFF16A34A),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                if (isOwner)
                                                  DataCell(
                                                    SizedBox(
                                                      width: actionsWidth,
                                                      child: Row(
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
                                                  ),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      })(),
          ),
          if (!productProvider.isLoading && productProvider.totalPages > 1)
            _buildPagination(productProvider.totalPages, productProvider),
        ],
      ),
    );
  }

  Widget _buildPagination(int totalPages, ProductProvider provider) {
    final currentPage = provider.currentPage;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;

        if (isMobile) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Page $currentPage of $totalPages',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.first_page_outlined, size: 20),
                      onPressed: currentPage > 1 ? () => provider.fetchPage(1) : null,
                      color: const Color(0xFF2563EB),
                      disabledColor: const Color(0xFF94A3B8),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left_outlined, size: 20),
                      onPressed: currentPage > 1 ? () => provider.fetchPage(currentPage - 1) : null,
                      color: const Color(0xFF2563EB),
                      disabledColor: const Color(0xFF94A3B8),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_outlined, size: 20),
                      onPressed: currentPage < totalPages ? () => provider.fetchPage(currentPage + 1) : null,
                      color: const Color(0xFF2563EB),
                      disabledColor: const Color(0xFF94A3B8),
                    ),
                    IconButton(
                      icon: const Icon(Icons.last_page_outlined, size: 20),
                      onPressed: currentPage < totalPages ? () => provider.fetchPage(totalPages) : null,
                      color: const Color(0xFF2563EB),
                      disabledColor: const Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildNavButton(
                    onTap: currentPage > 1 ? () => provider.fetchPage(1) : null,
                    icon: Icons.first_page_outlined,
                    label: 'FIRST',
                    enabled: currentPage > 1,
                  ),
                  const SizedBox(width: 8),
                  _buildNavButton(
                    onTap: currentPage > 1 ? () => provider.fetchPage(currentPage - 1) : null,
                    icon: Icons.chevron_left_outlined,
                    label: 'PREV',
                    enabled: currentPage > 1,
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Page $currentPage of $totalPages',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 12),
                  ..._buildPageNumbers(currentPage, totalPages, provider),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildNavButton(
                    onTap: currentPage < totalPages ? () => provider.fetchPage(currentPage + 1) : null,
                    icon: Icons.chevron_right_outlined,
                    label: 'NEXT',
                    enabled: currentPage < totalPages,
                    iconOnRight: true,
                  ),
                  const SizedBox(width: 8),
                  _buildNavButton(
                    onTap: currentPage < totalPages ? () => provider.fetchPage(totalPages) : null,
                    icon: Icons.last_page_outlined,
                    label: 'LAST',
                    enabled: currentPage < totalPages,
                    iconOnRight: true,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavButton({
    required VoidCallback? onTap,
    required IconData icon,
    required String label,
    required bool enabled,
    bool iconOnRight = false,
  }) {
    final color = enabled ? const Color(0xFF2563EB) : const Color(0xFF94A3B8);
    final children = <Widget>[
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 4),
      Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    ];

    if (iconOnRight) {
      final temp = children[0];
      children[0] = children[2];
      children[2] = temp;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFEFF6FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }

  List<Widget> _buildPageNumbers(int currentPage, int totalPages, ProductProvider provider) {
    final List<dynamic> items = [];
    if (totalPages <= 1) return <Widget>[];

    items.add(1);

    int start = currentPage - 2;
    int end = currentPage + 2;

    if (start < 2) {
      end += (2 - start);
      start = 2;
    }
    if (end > totalPages - 1) {
      start -= (end - (totalPages - 1));
      end = totalPages - 1;
    }

    if (start < 2) {
      start = 2;
    }

    if (start > 2) {
      if (start == 3) {
        items.add(2);
      } else {
        items.add('...');
      }
    }

    for (int i = start; i <= end; i++) {
      if (i > 1 && i < totalPages) {
        items.add(i);
      }
    }

    if (end < totalPages - 1) {
      if (end == totalPages - 2) {
        items.add(totalPages - 1);
      } else {
        items.add('...');
      }
    }

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
        final isCurrent = pageNum == currentPage;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: InkWell(
            onTap: isCurrent ? null : () => provider.fetchPage(pageNum),
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
                  setState(() => _activeOrdering = 'created_at');
                  provider.setOrdering('created_at');
                  Navigator.pop(context);
                },
              ),
              _sortTile(
                title: 'Price: Low to High',
                icon: Icons.trending_up_outlined,
                active: _activeOrdering == 'selling_price',
                onTap: () {
                  setState(() => _activeOrdering = 'selling_price');
                  provider.setOrdering('selling_price');
                  Navigator.pop(context);
                },
              ),
              _sortTile(
                title: 'Price: High to Low',
                icon: Icons.trending_down_outlined,
                active: _activeOrdering == '-selling_price',
                onTap: () {
                  setState(() => _activeOrdering = '-selling_price');
                  provider.setOrdering('-selling_price');
                  Navigator.pop(context);
                },
              ),
              _sortTile(
                title: 'Available Stock: Low to High',
                icon: Icons.warehouse_outlined,
                active: _activeOrdering == 'stock_quantity',
                onTap: () {
                  setState(() => _activeOrdering = 'stock_quantity');
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

  void _showBulkUploadDialog(BuildContext context, ProductProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        bool isUploading = false;
        String? uploadError;
        Map<String, dynamic>? uploadResult;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.cloud_upload_outlined, color: Color(0xFF2563EB)),
                  SizedBox(width: 8),
                  Text('Bulk Add Products', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Container(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Download our template file, fill in your product details, and upload the CSV file here to add or update products in bulk.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    
                    // Download Section
                    Row(
                      children: [
                        const Icon(Icons.description_outlined, color: Color(0xFF64748B), size: 20),
                        const SizedBox(width: 8),
                        const Text('1. Get Excel/CSV Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        const Spacer(),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEFF6FF),
                            foregroundColor: const Color(0xFF2563EB),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () async {
                            final templateText = await provider.downloadTemplate();
                            if (templateText != null) {
                              String? savePath = await FilePicker.saveFile(
                                dialogTitle: 'Save CSV Template',
                                fileName: 'products_template.csv',
                                type: FileType.custom,
                                allowedExtensions: ['csv'],
                              );
                              if (savePath != null) {
                                final file = File(savePath);
                                await file.writeAsString(templateText);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Template saved successfully!')),
                                );
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Failed to download template.')),
                              );
                            }
                          },
                          icon: const Icon(Icons.download_outlined, size: 14),
                          label: const Text('Download', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 16),
                    
                    // Upload Section
                    Row(
                      children: [
                        const Icon(Icons.upload_file_outlined, color: Color(0xFF64748B), size: 20),
                        const SizedBox(width: 8),
                        const Text('2. Upload Completed CSV', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        const Spacer(),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: isUploading
                              ? null
                              : () async {
                                  FilePickerResult? result = await FilePicker.pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: ['csv'],
                                    withData: true,
                                  );

                                  if (result != null && result.files.isNotEmpty) {
                                    setDialogState(() {
                                      isUploading = true;
                                      uploadError = null;
                                      uploadResult = null;
                                    });

                                    final file = result.files.first;
                                    final fileBytes = file.bytes;
                                    final fileName = file.name;

                                    if (fileBytes != null) {
                                      final res = await provider.bulkUploadProducts(fileBytes, fileName);
                                      setDialogState(() {
                                        isUploading = false;
                                        if (res != null && res['success'] == true) {
                                          uploadResult = res;
                                        } else {
                                          uploadError = res?['error'] ?? 'Upload failed';
                                        }
                                      });
                                    } else if (file.path != null) {
                                      final localBytes = File(file.path!).readAsBytesSync();
                                      final res = await provider.bulkUploadProducts(localBytes, fileName);
                                      setDialogState(() {
                                        isUploading = false;
                                        if (res != null && res['success'] == true) {
                                          uploadResult = res;
                                        } else {
                                          uploadError = res?['error'] ?? 'Upload failed';
                                        }
                                      });
                                    } else {
                                      setDialogState(() {
                                        isUploading = false;
                                        uploadError = 'Could not read file data.';
                                      });
                                    }
                                  }
                                },
                          icon: isUploading
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.file_upload_outlined, size: 14),
                          label: Text(
                            isUploading ? 'Uploading...' : 'Select File',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        )
                      ],
                    ),
                    
                    if (isUploading) ...[
                      const SizedBox(height: 20),
                      const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))),
                    ],

                    if (uploadError != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Text(
                          uploadError!,
                          style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12.5),
                        ),
                      )
                    ],

                    if (uploadResult != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 18),
                                SizedBox(width: 6),
                                Text('Upload Completed Successfully', style: TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Created: ${uploadResult!['created_count']} products', style: const TextStyle(fontSize: 12)),
                            Text('Updated: ${uploadResult!['updated_count']} products', style: const TextStyle(fontSize: 12)),
                            if (uploadResult!['errors'] != null && (uploadResult!['errors'] as List).isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text('Errors / Warnings:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFD97706))),
                              const SizedBox(height: 4),
                              Container(
                                constraints: const BoxConstraints(maxHeight: 100),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: (uploadResult!['errors'] as List).length,
                                  itemBuilder: (context, index) {
                                    return Text(
                                      '- ${(uploadResult!['errors'] as List)[index]}',
                                      style: const TextStyle(color: Color(0xFFB45309), fontSize: 11),
                                    );
                                  },
                                ),
                              )
                            ]
                          ],
                        ),
                      )
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
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
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF2563EB)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.local_fire_department_outlined, size: 48, color: Colors.white),
                SizedBox(height: 16),
                Text('Vighnaharta Fataka', style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                Text('Manager Dashboard', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_outlined),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/dashboard');
            },
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
          ListTile(
            leading: const Icon(Icons.account_balance_outlined),
            title: const Text('Ledgers'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/ledger');
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart_outlined),
            title: const Text('Reports'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/reports');
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
