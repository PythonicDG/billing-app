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
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs.');
    final isOutOfStock = product.totalStockInCent <= 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOutOfStock
              ? const Color(0xFFFCA5A5) // Soft red border
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
                      // Simple premium firecracker icon / status indicator instead of full image
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isOutOfStock ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isOutOfStock ? const Color(0xFFFCA5A5) : const Color(0xFFBFDBFE),
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            isOutOfStock ? Icons.block_flipped : Icons.inventory_2_outlined,
                            color: isOutOfStock ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                                color: Color(0xFF0F172A), // Slate 900
                                letterSpacing: 0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
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
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isOwner)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB), size: 20),
                              onPressed: onEdit,
                              tooltip: 'Edit Product',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(6),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_outlined, color: Color(0xFFEF4444), size: 20),
                              onPressed: onDelete,
                              tooltip: 'Delete Product',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(6),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Divider(color: Color(0xFFE2E8F0), height: 1, thickness: 1),
                  ),
                  // Attributes row (No. of case, Cent in per cs, Total Stock)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _infoColumn('NO. OF CASE', '${product.noOfCase} cs'),
                      _infoColumn('CENT IN PER CS', '${product.centInPerCs} cent'),
                      _infoColumn(
                        'TOTAL STOCK',
                        '${product.totalStockInCent.toStringAsFixed(1)} cent',
                        valueColor: isOutOfStock ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                        isBold: true,
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
                      _infoColumn(
                        'SELLING PRICE',
                        currencyFormat.format(product.sellingPrice),
                        valueColor: const Color(0xFF2563EB),
                        isBold: true,
                      ),
                      if (isOwner)
                        _infoColumn(
                          'PURCHASE PRICE',
                          currencyFormat.format(product.purchasePrice),
                          valueColor: const Color(0xFF475569),
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

  Widget _infoColumn(
    String label,
    String value, {
    Color? valueColor,
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
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 13.5 : 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? const Color(0xFF334155),
          ),
        ),
      ],
    );
  }
}
