import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../product_provider.dart';
import '../auth_provider.dart';
import '../widgets/product_card.dart';
import '../widgets/product_form.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  _ProductsScreenState createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();
  String _activeOrdering = 'created_at';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductProvider>(context, listen: false).fetchProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isOwner = authProvider.role?.toUpperCase() == 'OWNER';

    double screenWidth = MediaQuery.of(context).size.width;
    // Calculate columns: 1 for mobile, 2 for tablet, 3 for desktop
    int crossAxisCount = screenWidth < 720 ? 1 : (screenWidth < 1200 ? 2 : 3);
    double childAspectRatio = screenWidth < 480 ? 1.7 : 1.9;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: Color(0xFFFF5722)),
            SizedBox(width: 8),
            Text(
              'Inventory Dashboard',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
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
            onPressed: () => productProvider.fetchProducts(),
          ),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Color(0xFFFF5722)),
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
                backgroundColor: const Color(0xFFFF5722),
                onPressed: () => _showProductForm(context),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('ADD PRODUCT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                elevation: 6,
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
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: 'Search by firecracker name, brand, or SKU...',
                  prefixIcon: const Icon(Icons.search_outlined, color: Color(0xFFFF5722)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_outlined, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            productProvider.setSearch('');
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFFF5722), width: 1.5),
                  ),
                ),
                onChanged: (value) {
                  setState(() {}); // Repaint to show/hide clear button
                },
                onSubmitted: (value) => productProvider.setSearch(value),
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
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  Text(
                    'Search filters active',
                    style: TextStyle(
                      color: const Color(0xFFFFC107).withOpacity(0.8),
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
                    child: CircularProgressIndicator(color: Color(0xFFFF5722)),
                  )
                : productProvider.products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.hourglass_empty_outlined,
                              size: 64,
                              color: Colors.white.withOpacity(0.2),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No products found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try modifying your search query or seeding new data.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.35),
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: childAspectRatio,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                        itemCount: productProvider.products.length,
                        itemBuilder: (context, index) {
                          final product = productProvider.products[index];
                          return ProductCard(
                            product: product,
                            isOwner: isOwner,
                            onEdit: () => _showProductForm(context, product: product),
                            onDelete: () => _confirmDelete(context, product),
                          );
                        },
                      ),
          ),
          
          // Pagination Controls
          if (productProvider.products.isNotEmpty)
            _buildPagination(productProvider),
        ],
      ),
    );
  }

  Widget _buildPagination(ProductProvider productProvider) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.04))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.05),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: productProvider.previousUrl != null
                ? () => productProvider.fetchProducts(url: productProvider.previousUrl)
                : null,
            icon: const Icon(Icons.chevron_left_outlined, size: 20),
            label: const Text('PREVIOUS'),
          ),
          Text(
            'Page Navigation',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.4),
              fontWeight: FontWeight.bold,
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.05),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: productProvider.nextUrl != null
                ? () => productProvider.fetchProducts(url: productProvider.nextUrl)
                : null,
            icon: const Text('NEXT'),
            label: const Icon(Icons.chevron_right_outlined, size: 20),
          ),
        ],
      ),
    );
  }

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
                    'Sort Inventory By',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const Divider(color: Colors.white10),
              _sortTile(
                title: 'Newest Added First',
                icon: Icons.calendar_month_outlined,
                active: _activeOrdering == 'created_at',
                onTap: () {
                  _activeOrdering = 'created_at';
                  provider.setOrdering('created_at');
                  Navigator.pop(context);
                },
              ),
              _sortTile(
                title: 'Price: Low to High',
                icon: Icons.trending_up_outlined,
                active: _activeOrdering == 'selling_price',
                onTap: () {
                  _activeOrdering = 'selling_price';
                  provider.setOrdering('selling_price');
                  Navigator.pop(context);
                },
              ),
              _sortTile(
                title: 'Price: High to Low',
                icon: Icons.trending_down_outlined,
                active: _activeOrdering == '-selling_price',
                onTap: () {
                  _activeOrdering = '-selling_price';
                  provider.setOrdering('-selling_price');
                  Navigator.pop(context);
                },
              ),
              _sortTile(
                title: 'Available Stock: Low to High',
                icon: Icons.warehouse_outlined,
                active: _activeOrdering == 'stock_quantity',
                onTap: () {
                  _activeOrdering = 'stock_quantity';
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

  void _showProductForm(BuildContext context, {Product? product}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
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
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_outlined, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Delete Product'),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.white70, fontSize: 14.5),
            children: [
              const TextSpan(text: 'Are you sure you want to permanently delete '),
              TextSpan(
                text: product.name,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const TextSpan(text: '? This action cannot be undone.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
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
      child: ListView(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFFFF5722)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.local_fire_department, size: 48, color: Colors.white),
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
