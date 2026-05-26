import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'constants.dart';
import 'product_provider.dart';

class Customer {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? address;

  Customer({required this.id, required this.name, required this.phone, this.email, this.address});

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      address: json['address']?.toString(),
    );
  }
}

class InvoiceItem {
  final Product product;
  int quantity;
  double unitPrice;
  String unit;

  InvoiceItem({
    required this.product,
    required this.quantity,
    required this.unitPrice,
    this.unit = 'PIECE',
  });

  double get totalPrice => quantity * unitPrice;

  Map<String, dynamic> toJson() => {
    'product': product.uuid,
    'quantity': quantity,
    'unit_price': double.parse(unitPrice.toStringAsFixed(2)),
    'unit': unit,
  };
}

class BillingProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final List<InvoiceItem> _cart = [];
  bool _isLoading = false;
  String? _errorMessage;

  double _taxRate = 0.0;
  double _discountAmount = 0.0;

  List<InvoiceItem> get cart => _cart;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void addToCart(Product product, {String unit = 'PIECE'}) {
    final existingIndex = _cart.indexWhere((item) => item.product.uuid == product.uuid);
    if (existingIndex != -1) {
      final item = _cart[existingIndex];
      // Toggling unit is handled by toggleUnit, here we just increment quantity if possible
      final requestedQuantity = item.unit == 'CENT' ? (item.quantity + 1) * 10 : item.quantity + 1;
      
      if (requestedQuantity <= product.stockQuantity) {
        item.quantity++;
      }
    } else {
      final requestedPieces = unit == 'CENT' ? 10 : 1;
      if (product.stockQuantity >= requestedPieces) {
        _cart.add(InvoiceItem(
          product: product,
          quantity: 1,
          unitPrice: unit == 'CENT' ? product.sellingPrice * 10 : product.sellingPrice,
          unit: unit,
        ));
      }
    }
    notifyListeners();
  }

  void removeFromCart(String uuid) {
    _cart.removeWhere((item) => item.product.uuid == uuid);
    notifyListeners();
  }

  void toggleUnit(String uuid) {
    final index = _cart.indexWhere((item) => item.product.uuid == uuid);
    if (index != -1) {
      final item = _cart[index];
      if (item.unit == 'PIECE') {
        // Switch to CENT
        // Check if stock is available (1 CENT = 10 PIECES)
        if (item.quantity * 10 <= item.product.stockQuantity) {
          item.unit = 'CENT';
          item.unitPrice = item.product.sellingPrice * 10;
        }
      } else {
        // Switch to PIECE
        item.unit = 'PIECE';
        item.unitPrice = item.product.sellingPrice;
      }
      notifyListeners();
    }
  }

  void updateQuantity(String uuid, int quantity, int maxStock) {
    final index = _cart.indexWhere((item) => item.product.uuid == uuid);
    if (index != -1) {
      final item = _cart[index];
      final requestedPieces = item.unit == 'CENT' ? quantity * 10 : quantity;

      if (quantity > 0 && requestedPieces <= maxStock) {
        item.quantity = quantity;
      } else if (quantity == 0) {
        _cart.removeAt(index);
      }
    }
    notifyListeners();
  }

  double get subTotal => double.parse(_cart.fold(0.0, (sum, item) => sum + item.totalPrice).toStringAsFixed(2));
  double get taxAmount => double.parse((subTotal * _taxRate).toStringAsFixed(2));
  double get totalWithTax => double.parse((subTotal + taxAmount).toStringAsFixed(2));
  double get grandTotal => double.parse((totalWithTax - _discountAmount).toStringAsFixed(2));

  set discount(double value) {
    _discountAmount = value;
    notifyListeners();
  }

  set tax(double value) {
    _taxRate = value;
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    _discountAmount = 0.0;
    _errorMessage = null;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> previewInvoice({
    required String? customerName,
    required String? customerPhone,
    required double paidAmount,
    required String paymentMethod,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final payload = {
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'sub_total': double.parse(subTotal.toStringAsFixed(2)),
        'tax_amount': double.parse(taxAmount.toStringAsFixed(2)),
        'discount_amount': double.parse(_discountAmount.toStringAsFixed(2)),
        'grand_total': double.parse(grandTotal.toStringAsFixed(2)),
        'paid_amount': double.parse(paidAmount.toStringAsFixed(2)),
        'payment_method': paymentMethod,
        'items': _cart.map((item) => item.toJson()).toList(),
      };

      final response = await _apiService.post(ApiConstants.invoicePreviewUrl, payload);
      _isLoading = false;

      if (response.statusCode == 200 || response.statusCode == 201) {
        notifyListeners();
        return jsonDecode(response.body);
      } else {
        _errorMessage = jsonDecode(response.body).toString();
        notifyListeners();
        return null;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<String?> createInvoice({
    required String? customerName,
    required String? customerPhone,
    required double paidAmount,
    required String paymentMethod,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final Map<String, dynamic> payload = {
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'sub_total': double.parse(subTotal.toStringAsFixed(2)),
        'tax_amount': double.parse(taxAmount.toStringAsFixed(2)),
        'discount_amount': double.parse(_discountAmount.toStringAsFixed(2)),
        'grand_total': double.parse(grandTotal.toStringAsFixed(2)),
        'paid_amount': double.parse(paidAmount.toStringAsFixed(2)),
        'payment_method': paymentMethod,
        'items': _cart.map((item) => item.toJson()).toList(),
      };

      final response = await _apiService.post(ApiConstants.invoicesUrl, payload);
      _isLoading = false;

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        clearCart();
        return data['id']?.toString();
      } else {
        final data = jsonDecode(response.body);
        _errorMessage = data.toString();
        notifyListeners();
        return null;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateInvoicePaidAmount(String invoiceId, double paidAmount) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _apiService.patch(ApiConstants.invoiceDetailUrl(invoiceId), {'paid_amount': paidAmount});
      _isLoading = false;
      if (response.statusCode == 200) {
        notifyListeners();
        return true;
      } else {
        _errorMessage = jsonDecode(response.body).toString();
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<String?> getInvoicePdfUrl(String invoiceId) async {
    final token = await _apiService.getToken();
    if (token == null) return null;
    return '${ApiConstants.baseUrl}${ApiConstants.invoiceDownloadPdfUrl(invoiceId)}?token=$token';
  }

  Future<String?> getInvoicePrintHtmlUrl(String invoiceId) async {
    final token = await _apiService.getToken();
    if (token == null) return null;
    return '${ApiConstants.baseUrl}${ApiConstants.invoicePrintHtmlUrl(invoiceId)}?token=$token';
  }

  Future<String?> getInvoiceThermalReceiptUrl(String invoiceId) async {
    final token = await _apiService.getToken();
    if (token == null) return null;
    return '${ApiConstants.baseUrl}${ApiConstants.invoiceThermalReceiptUrl(invoiceId)}?token=$token';
  }

  Future<List<Customer>> searchCustomers(String query) async {
    try {
      final response = await _apiService.get(ApiConstants.customersUrl, queryParams: {'search': query});
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((c) => Customer.fromJson(c)).toList();
      }
    } catch (e) {
      debugPrint('Error searching customers: $e');
    }
    return [];
  }
}
