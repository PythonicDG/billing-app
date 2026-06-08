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
  late TextEditingController _sellingPriceController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _noOfCaseController;
  late TextEditingController _centInPerCsController;
  double _totalStockInCent = 0.0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _brandController = TextEditingController(text: widget.product?.brand ?? '');
    _sellingPriceController = TextEditingController(text: widget.product?.sellingPrice.toString() ?? '');
    _purchasePriceController = TextEditingController(text: widget.product?.purchasePrice.toString() ?? '');
    _noOfCaseController = TextEditingController(text: widget.product?.noOfCase.toString() ?? '');
    _centInPerCsController = TextEditingController(text: widget.product?.centInPerCs.toString() ?? '');

    _noOfCaseController.addListener(_updateTotalStock);
    _centInPerCsController.addListener(_updateTotalStock);
    _updateTotalStock();
  }

  void _updateTotalStock() {
    final cases = double.tryParse(_noOfCaseController.text) ?? 0.0;
    final centPerCs = double.tryParse(_centInPerCsController.text) ?? 0.0;
    setState(() {
      _totalStockInCent = cases * centPerCs;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _sellingPriceController.dispose();
    _purchasePriceController.dispose();
    _noOfCaseController.dispose();
    _centInPerCsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      final Map<String, dynamic> data = {
        'name': _nameController.text.trim(),
        'brand': _brandController.text.trim(),
        'purchase_price': double.parse(_purchasePriceController.text),
        'selling_price': double.parse(_sellingPriceController.text),
        'no_of_case': int.parse(_noOfCaseController.text),
        'cent_in_per_cs': int.parse(_centInPerCsController.text),
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
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 16),
              
              _buildTextField(_nameController, 'Product Name'),
              _buildTextField(_brandController, 'Brand'),
              
              Row(
                children: [
                  Expanded(child: _buildTextField(_purchasePriceController, 'Purchase Price', isNum: true)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTextField(_sellingPriceController, 'Selling Price', isNum: true)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _buildTextField(_noOfCaseController, 'No. Of Case', isNum: true)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTextField(_centInPerCsController, 'Cent in per cs', isNum: true)),
                ],
              ),
              
              // Dynamic Display of calculated Total stock in cent
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Stock in Cent:',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      Text(
                        _totalStockInCent.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
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
        style: const TextStyle(color: Color(0xFF0F172A)),
        decoration: InputDecoration(
          labelText: label,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
      ),
    );
  }
}
