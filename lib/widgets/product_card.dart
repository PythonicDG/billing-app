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

    // Calculate discount percentage if MRP is available and higher than selling price
    double discountPercent = 0.0;
    if (product.mrp > 0 && product.mrp > product.sellingPrice) {
      discountPercent = ((product.mrp - product.sellingPrice) / product.mrp) * 100;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Premium dark card surface
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOutOfStock
              ? Colors.redAccent.withOpacity(0.3)
              : isLowStock
                  ? Colors.orangeAccent.withOpacity(0.3)
                  : Colors.white.withOpacity(0.05),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
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
                      // Fixed sized beautiful image box
                      Stack(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.05),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: product.image != null && product.image!.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.network(
                                      product.image!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => const Icon(
                                        Icons.broken_image_outlined,
                                        size: 28,
                                        color: Colors.white24,
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
                                      Icons.local_fire_department,
                                      color: Color(0xFFFF5722),
                                      size: 32,
                                    ),
                                  ),
                          ),
                          if (discountPercent > 0)
                            Positioned(
                              top: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF5722), // Primary firecracker orange
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${discountPercent.toStringAsFixed(0)}% OFF',
                                  style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
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
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    product.brand.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFFFC107), // Gold accent
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (product.sku != null && product.sku!.isNotEmpty)
                                  Flexible(
                                    child: Text(
                                      'SKU: ${product.sku}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white.withOpacity(0.4),
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
                              icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 22),
                              onPressed: onEdit,
                              tooltip: 'Edit Product',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                            ),
                            const SizedBox(height: 12),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_outlined, color: Colors.redAccent, size: 22),
                              onPressed: onDelete,
                              tooltip: 'Delete Product',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 24, thickness: 1),
                  // Price breakdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _priceColumn(
                        'SELLING PRICE',
                        currencyFormat.format(product.sellingPrice),
                        color: const Color(0xFFFF5722),
                        isBold: true,
                      ),
                      if (product.mrp > 0)
                        _priceColumn(
                          'MRP',
                          currencyFormat.format(product.mrp),
                          strikeThrough: true,
                          color: Colors.white38,
                        ),
                      if (isOwner)
                        _priceColumn(
                          'PURCHASE COST',
                          currencyFormat.format(product.purchasePrice),
                          color: const Color(0xFF4CAF50), // Emerald green
                        ),
                      _priceColumn(
                        'MARGIN',
                        isOwner
                            ? currencyFormat.format(product.sellingPrice - product.purchasePrice)
                            : '${discountPercent.toStringAsFixed(0)}% OFF',
                        color: const Color(0xFFFFC107),
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
      tagColor = Colors.redAccent.withOpacity(0.1);
      textColor = Colors.redAccent;
      text = 'OUT OF STOCK';
      icon = Icons.cancel_outlined;
    } else if (isLowStock) {
      tagColor = Colors.orangeAccent.withOpacity(0.1);
      textColor = Colors.orangeAccent;
      text = 'LOW STOCK ($quantity left)';
      icon = Icons.warning_amber_outlined;
    } else {
      tagColor = Colors.green.withOpacity(0.1);
      textColor = const Color(0xFF4CAF50);
      text = 'IN STOCK ($quantity available)';
      icon = Icons.check_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tagColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 10.5,
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
    bool strikeThrough = false,
    bool isBold = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: Colors.white.withOpacity(0.3),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold || strikeThrough ? FontWeight.bold : FontWeight.w600,
            color: color,
            decoration: strikeThrough ? TextDecoration.lineThrough : null,
          ),
        ),
      ],
    );
  }
}
