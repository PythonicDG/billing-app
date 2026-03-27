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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () {
              _showSortOptions(context, productProvider);
            },
          ),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                _showProductForm(context);
              },
            ),
        ],
      ),
      drawer: AppDrawer(currentRole: authProvider.role ?? 'VIEWER'),
      floatingActionButton: isOwner 
          ? FloatingActionButton(
              backgroundColor: const Color(0xFFFF5722),
              onPressed: () => _showProductForm(context),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, brand or SKU...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    productProvider.setSearch('');
                  },
                ),
              ),
              onSubmitted: (value) => productProvider.setSearch(value),
            ),
          ),
          Expanded(
            child: productProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
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
          if (productProvider.products.isNotEmpty)
            _buildPagination(productProvider),
        ],
      ),
    );
  }

  Widget _buildPagination(ProductProvider productProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: productProvider.previousUrl != null
                ? () => productProvider.fetchProducts(url: productProvider.previousUrl)
                : null,
            icon: const Icon(Icons.chevron_left),
            label: const Text('Previous'),
          ),
          TextButton.icon(
            onPressed: productProvider.nextUrl != null
                ? () => productProvider.fetchProducts(url: productProvider.nextUrl)
                : null,
            icon: const Text('Next'),
            label: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  void _showSortOptions(BuildContext context, ProductProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              title: const Text('Newest First'),
              onTap: () {
                provider.setOrdering('created_at');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Price (Low to High)'),
              onTap: () {
                provider.setOrdering('selling_price');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Stock (Low to High)'),
              onTap: () {
                provider.setOrdering('stock_quantity');
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _showProductForm(BuildContext context, {Product? product}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ProductForm(product: product),
    );
  }

  void _confirmDelete(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete ${product.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Provider.of<ProductProvider>(context, listen: false).deleteProduct(product.uuid);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
