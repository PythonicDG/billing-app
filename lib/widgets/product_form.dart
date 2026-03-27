import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../product_provider.dart';

class ProductForm extends StatefulWidget {
  final Product? product;

  const ProductForm({super.key, this.product});

  @override
  _ProductFormState createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _skuController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _mrpController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _stockQuantityController;
  late TextEditingController _minStockLevelController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _brandController = TextEditingController(text: widget.product?.brand ?? '');
    _skuController = TextEditingController(text: widget.product?.sku ?? '');
    _sellingPriceController = TextEditingController(text: widget.product?.sellingPrice.toString() ?? '');
    _mrpController = TextEditingController(text: widget.product?.mrp.toString() ?? '');
    _purchasePriceController = TextEditingController(text: widget.product?.purchasePrice.toString() ?? '');
    _stockQuantityController = TextEditingController(text: widget.product?.stockQuantity.toString() ?? '');
    _minStockLevelController = TextEditingController(text: widget.product?.minStockLevel.toString() ?? '10');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _skuController.dispose();
    _sellingPriceController.dispose();
    _mrpController.dispose();
    _purchasePriceController.dispose();
    _stockQuantityController.dispose();
    _minStockLevelController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      final Map<String, dynamic> data = {
        'name': _nameController.text,
        'brand': _brandController.text,
        'sku': _skuController.text,
        'selling_price': double.parse(_sellingPriceController.text),
        'mrp': double.parse(_mrpController.text),
        'purchase_price': double.parse(_purchasePriceController.text),
        'stock_quantity': int.parse(_stockQuantityController.text),
        'min_stock_level': int.parse(_minStockLevelController.text),
      };

      final provider = Provider.of<ProductProvider>(context, listen: false);
      bool success;
      if (widget.product == null) {
        success = await provider.addProduct(data);
      } else {
        success = await provider.updateProduct(widget.product!.uuid, data);
      }

      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.product == null ? 'Product added successfully' : 'Product updated successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action failed. Check API connectivity.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.product == null ? 'Add Product' : 'Edit Product',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildTextField(_nameController, 'Product Name'),
              _buildTextField(_brandController, 'Brand'),
              _buildTextField(_skuController, 'SKU (Optional)'),
              Row(
                children: [
                  Expanded(child: _buildTextField(_purchasePriceController, 'Purchase Price', isNum: true)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTextField(_sellingPriceController, 'Selling Price', isNum: true)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _buildTextField(_mrpController, 'MRP', isNum: true)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTextField(_stockQuantityController, 'Stock Qty', isNum: true)),
                ],
              ),
              _buildTextField(_minStockLevelController, 'Min Stock Level', isNum: true),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: Text(widget.product == null ? 'Create Product' : 'Update Product'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isNum = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          hintStyle: const TextStyle(color: Colors.white24),
        ),
        validator: (v) => v!.isEmpty && label != 'SKU (Optional)' ? 'Required' : null,
      ),
    );
  }
}
