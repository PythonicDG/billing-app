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
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final isLowStock = product.stockQuantity <= product.minStockLevel;
    final isOutOfStock = product.stockQuantity <= 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white, // Crisp White card
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOutOfStock
              ? const Color(0xFFFCA5A5) // Soft red border
              : isLowStock
                  ? const Color(0xFFFDBA74) // Soft orange border
                  : const Color(0xFFE2E8F0), // Cool grey slate border
          width: 1.2,
        ),
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
        child: Material(
          color: Colors.transparent,
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
                      // Image Container
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: product.image != null && product.image!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  product.image!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(
                                    Icons.broken_image_outlined,
                                    size: 28,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    );
                                  },
                                ),
                              )
                            : const Center(
                                child: Icon(
                                  Icons.local_fire_department_outlined,
                                  color: Color(0xFF2563EB), // Premium blue theme
                                  size: 32,
                                ),
                              ),
                      ),
                      const SizedBox(width: 16),
                      // Details section
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A), // Slate 900
                                letterSpacing: 0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF), // Soft blue tint
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    product.brand.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2563EB), // Indigo blue
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (product.sku != null && product.sku!.isNotEmpty)
                                  Flexible(
                                    child: Text(
                                      'SKU: ${product.sku}',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: Color(0xFF64748B),
                                        fontFamily: 'monospace',
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Stock Status Tag
                            _buildStockTag(isOutOfStock, isLowStock, product.stockQuantity),
                          ],
                        ),
                      ),
                      if (isOwner)
                        Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB), size: 22),
                              onPressed: onEdit,
                              tooltip: 'Edit Product',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                            ),
                            const SizedBox(height: 12),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_outlined, color: Color(0xFFEF4444), size: 22),
                              onPressed: onDelete,
                              tooltip: 'Delete Product',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Divider(color: Color(0xFFE2E8F0), height: 1, thickness: 1),
                  ),
                  // Price breakdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _priceColumn(
                        'PRICING',
                        currencyFormat.format(product.sellingPrice),
                        color: const Color(0xFF2563EB), // Theme Blue
                        isBold: true,
                      ),
                      if (product.mrp > 0)
                        _priceColumn(
                          'MRP',
                          currencyFormat.format(product.mrp),
                          color: const Color(0xFF64748B),
                        ),
                      if (isOwner)
                        _priceColumn(
                          'PURCHASE',
                          currencyFormat.format(product.purchasePrice),
                          color: const Color(0xFF16A34A), // Emerald green
                        ),
                      if (isOwner)
                        _priceColumn(
                          'MARGIN',
                          currencyFormat.format(product.sellingPrice - product.purchasePrice),
                          color: const Color(0xFFD97706), // Amber
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStockTag(bool isOutOfStock, bool isLowStock, int quantity) {
    Color tagColor;
    Color textColor;
    String text;
    IconData icon;

    if (isOutOfStock) {
      tagColor = const Color(0xFFFEF2F2); // Soft red
      textColor = const Color(0xFFEF4444);
      text = 'OUT OF STOCK';
      icon = Icons.cancel_outlined;
    } else if (isLowStock) {
      tagColor = const Color(0xFFFFF7ED); // Soft orange
      textColor = const Color(0xFFF97316);
      text = 'LOW STOCK ($quantity left)';
      icon = Icons.warning_amber_outlined;
    } else {
      tagColor = const Color(0xFFF0FDF4); // Soft green
      textColor = const Color(0xFF16A34A);
      text = 'IN STOCK ($quantity available)';
      icon = Icons.check_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tagColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 13),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceColumn(
    String label,
    String value, {
    Color? color,
    bool isBold = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: Color(0xFF94A3B8), // Slate 400
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 14 : 12.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? const Color(0xFF334155),
          ),
        ),
      ],
    );
  }
}
