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
  late TextEditingController _minStockLevelController;
  double _totalStockInCent = 0.0;
  bool _isCentMode = true; // Default to Cent mode

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _brandController = TextEditingController(text: widget.product?.brand ?? '');
    
    // Show empty string if value is 0 or null for better UX (as requested by user)
    _sellingPriceController = TextEditingController(
      text: (widget.product == null || widget.product!.sellingPrice == 0) ? '' : widget.product!.sellingPrice.toString()
    );
    _purchasePriceController = TextEditingController(
      text: (widget.product == null || widget.product!.purchasePrice == 0) ? '' : widget.product!.purchasePrice.toString()
    );
    _noOfCaseController = TextEditingController(
      text: (widget.product == null || widget.product!.noOfCase == 0) ? '' : widget.product!.noOfCase.toString()
    );
    _centInPerCsController = TextEditingController(
      text: (widget.product == null || widget.product!.centInPerCs == 0) ? '' : widget.product!.centInPerCs.toString()
    );
    _minStockLevelController = TextEditingController(
      text: widget.product?.minStockLevel.toString() ?? '5'
    );

    _noOfCaseController.addListener(_updateTotalStock);
    _centInPerCsController.addListener(_updateTotalStock);
    _updateTotalStock();
  }

  void _updateTotalStock() {
    final cases = double.tryParse(_noOfCaseController.text) ?? 0.0;
    final valPerCs = double.tryParse(_centInPerCsController.text) ?? 0.0;
    setState(() {
      if (_isCentMode) {
        // Cent mode: valPerCs is already in cents
        _totalStockInCent = cases * valPerCs;
      } else {
        // Piece mode: valPerCs is in pieces, convert pieces to cents (1 cent = 10 pieces)
        _totalStockInCent = (cases * valPerCs) / 10.0;
      }
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
    _minStockLevelController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      final centOrPiecesPerCs = double.tryParse(_centInPerCsController.text) ?? 0.0;
      final centValue = _isCentMode ? centOrPiecesPerCs : (centOrPiecesPerCs / 10.0);
      
      final Map<String, dynamic> data = {
        'name': _nameController.text.trim(),
        'brand': _brandController.text.trim(),
        'purchase_price': double.tryParse(_purchasePriceController.text) ?? 0.0,
        'selling_price': double.tryParse(_sellingPriceController.text) ?? 0.0,
        'no_of_case': int.tryParse(_noOfCaseController.text) ?? 0,
        'cent_in_per_cs': centValue,
        'min_stock_level': int.tryParse(_minStockLevelController.text) ?? 5,
        'entry_mode': _isCentMode ? 'cent' : 'piece',
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

              // Unit toggle — pill style, same as billing screen
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    const Text(
                      'Unit',
                      style: TextStyle(fontSize: 13.5, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 32,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildUnitOption('Unit', !_isCentMode, () {
                            setState(() {
                              _isCentMode = false;
                              _updateTotalStock();
                            });
                          }),
                          _buildUnitOption('Cent (10x)', _isCentMode, () {
                            setState(() {
                              _isCentMode = true;
                              _updateTotalStock();
                            });
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(child: _buildTextField(_noOfCaseController, 'No. Of Case', isNum: true)),
                  const SizedBox(width: 8),
                  // Always show the field, change label
                  Expanded(
                    child: _buildTextField(
                      _centInPerCsController,
                      _isCentMode ? 'Cent in per cs' : 'Pieces in per cs',
                      isNum: true,
                    ),
                  ),
                ],
              ),
              _buildTextField(_minStockLevelController, 'Min Stock Level (in cent) — Alert threshold', isNum: true, isRequired: false),
              
              // Dynamic Display of calculated Total stock
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
                        'Total Stock (in cent):',
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


  Widget _buildUnitOption(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isNum = false, bool isRequired = true}) {
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
        validator: isRequired ? (v) => v == null || v.isEmpty ? 'Required' : null : null,
      ),
    );
  }
}
