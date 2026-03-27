import 'package:flutter/material.dart';
import '../product_provider.dart';
import 'package:intl/intl.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final bool isOwner;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ProductCard({
    super.key,
    required this.product,
    required this.isOwner,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    var currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final isLowStock = product.stockQuantity < product.minStockLevel;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: isOwner ? onEdit : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: product.image != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              product.image!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 24, color: Colors.white24),
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                              },
                            ),
                          )
                        : const Icon(Icons.image_not_supported, color: Colors.white24),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          product.brand,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        if (product.sku != null && product.sku!.isNotEmpty)
                          Text('SKU: ${product.sku}', style: const TextStyle(fontSize: 12, color: Colors.white60)),
                      ],
                    ),
                  ),
                  if (isOwner)
                    _buildOwnerActions(),
                ],
              ),
              const Divider(color: Colors.white24, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _priceColumn('Selling Price', currencyFormat.format(product.sellingPrice), color: Colors.orangeAccent),
                  _priceColumn('MRP', currencyFormat.format(product.mrp)),
                  if (isOwner)
                    _priceColumn('Purchase', currencyFormat.format(product.purchasePrice), color: Colors.greenAccent),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    isLowStock ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                    size: 16,
                    color: isLowStock ? Colors.redAccent : Colors.greenAccent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Stock: ${product.stockQuantity}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isLowStock ? Colors.redAccent : Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Min Stock: ${product.minStockLevel}',
                    style: const TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _priceColumn(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildOwnerActions() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.edit, size: 20, color: Colors.blueAccent),
          onPressed: onEdit,
        ),
        IconButton(
          icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
          onPressed: onDelete,
        ),
      ],
    );
  }
}
