import 'dart:convert';
import 'package:flutter/material.dart';
import '../api_service.dart';
import '../constants.dart';

class Product {
  final String uuid;
  final String name;
  final String brand;
  final String? sku;
  final double sellingPrice;
  final double mrp;
  final double purchasePrice;
  final int stockQuantity;
  final int minStockLevel;
  final String? image;

  Product({
    required this.uuid,
    required this.name,
    required this.brand,
    this.sku,
    required this.sellingPrice,
    required this.mrp,
    required this.purchasePrice,
    required this.stockQuantity,
    required this.minStockLevel,
    this.image,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      uuid: (json['uuid'] ?? json['id'] ?? '').toString(),
      name: json['name']?.toString() ?? 'Unnamed',
      brand: json['brand']?.toString() ?? 'Unknown',
      sku: json['sku']?.toString(),
      sellingPrice: double.tryParse(json['selling_price']?.toString() ?? '0') ?? 0.0,
      mrp: double.tryParse(json['mrp']?.toString() ?? '0') ?? 0.0,
      purchasePrice: double.tryParse(json['purchase_price']?.toString() ?? '0') ?? 0.0,
      stockQuantity: int.tryParse(json['stock_quantity']?.toString() ?? '0') ?? 0,
      minStockLevel: int.tryParse(json['min_stock_level']?.toString() ?? '0') ?? 0,
      image: json['image']?.toString(),
    );
  }
}

class ProductProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Product> _products = [];
  String? _nextUrl;
  String? _previousUrl;
  bool _isLoading = false;
  String _searchQuery = '';
  String _ordering = 'created_at';

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  bool get hasNext => _nextUrl != null;
  bool get hasPrevious => _previousUrl != null;

  Future<void> fetchProducts({bool initial = true, String? url}) async {
    _isLoading = true;
    if (initial) {
      _products = [];
    }
    notifyListeners();

    try {
      final response = await _apiService.get(
        url ?? ApiConstants.productsUrl,
        queryParams: url == null ? {
          'search': _searchQuery,
          'ordering': _ordering,
        } : null,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('results')) {
          final results = data['results'] as List;
          _products = results.map((p) => Product.fromJson(p)).toList();
          _nextUrl = data['next'];
          _previousUrl = data['previous'];
        } else if (data is List) {
          _products = data.map((p) => Product.fromJson(p)).toList();
          _nextUrl = null;
          _previousUrl = null;
        }
      }
    } catch (e) {
      debugPrint('Error fetching products: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  String? get nextUrl => _nextUrl;
  String? get previousUrl => _previousUrl;

  void setSearch(String query) {
    _searchQuery = query;
    fetchProducts();
  }

  void setOrdering(String ordering) {
    _ordering = ordering;
    fetchProducts();
  }

  Future<bool> addProduct(Map<String, dynamic> data) async {
    final response = await _apiService.post(ApiConstants.productsUrl, data);
    if (response.statusCode == 201) {
      fetchProducts();
      return true;
    }
    return false;
  }

  Future<bool> updateProduct(String uuid, Map<String, dynamic> data) async {
    final response = await _apiService.patch(ApiConstants.productDetailUrl(uuid), data);
    if (response.statusCode == 200) {
      fetchProducts();
      return true;
    }
    return false;
  }

  Future<bool> deleteProduct(String uuid) async {
    final response = await _apiService.delete(ApiConstants.productDetailUrl(uuid));
    if (response.statusCode == 204) {
      fetchProducts();
      return true;
    }
    return false;
  }
}
