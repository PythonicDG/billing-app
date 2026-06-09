import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../api_service.dart';
import '../constants.dart';

class Category {
  final String uuid;
  final String name;
  final String? description;

  Category({required this.uuid, required this.name, this.description});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      uuid: (json['id'] ?? json['uuid'] ?? '').toString(),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
    );
  }
}

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
  final String? category;
  final String? categoryName;
  final int noOfCase;
  final int centInPerCs;
  final double totalStockInCent;

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
    this.category,
    this.categoryName,
    required this.noOfCase,
    required this.centInPerCs,
    required this.totalStockInCent,
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
      category: json['category']?.toString(),
      categoryName: json['category_name']?.toString(),
      noOfCase: int.tryParse(json['no_of_case']?.toString() ?? '0') ?? 0,
      centInPerCs: int.tryParse(json['cent_in_per_cs']?.toString() ?? '0') ?? 0,
      totalStockInCent: double.tryParse(json['total_stock_in_cent']?.toString() ?? '0.0') ?? 0.0,
    );
  }
}

class ProductProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Product> _products = [];
  List<Category> _categoriesList = [];
  String? _nextUrl;
  String? _previousUrl;
  bool _isLoading = false;
  String _searchQuery = '';
  String _ordering = 'created_at';
  int? _pageSize;

  List<Product> get products => _products;
  List<Category> get categoriesList => _categoriesList;
  bool get isLoading => _isLoading;
  bool get hasNext => _nextUrl != null;
  bool get hasPrevious => _previousUrl != null;

  Future<void> fetchCategories() async {
    try {
      final response = await _apiService.get('/api/products/categories/');
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        _categoriesList = data.map((c) => Category.fromJson(c)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
  }

  Future<bool> addCategory(String name, String? description) async {
    try {
      final response = await _apiService.post('/api/products/categories/', {
        'name': name,
        'description': description ?? '',
      });
      if (response.statusCode == 201) {
        await fetchCategories();
        return true;
      }
    } catch (e) {
      debugPrint('Error adding category: $e');
    }
    return false;
  }

  Future<void> fetchProducts({bool initial = true, String? url, int? pageSize}) async {
    _isLoading = true;
    if (pageSize != null) {
      _pageSize = pageSize;
    }
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
          if (_pageSize != null) 'page_size': _pageSize.toString(),
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

  Future<bool> addProduct(Map<String, dynamic> data, {Uint8List? fileBytes, String? fileName}) async {
    final fields = data.map((key, value) => MapEntry(key, value.toString()));
    final response = await _apiService.multipartRequest(
      method: 'POST',
      endpoint: ApiConstants.productsUrl,
      fields: fields,
      fileBytes: fileBytes,
      fileName: fileName,
    );
    if (response.statusCode == 201) {
      fetchProducts();
      return true;
    }
    return false;
  }

  Future<bool> updateProduct(String uuid, Map<String, dynamic> data, {Uint8List? fileBytes, String? fileName}) async {
    final fields = data.map((key, value) => MapEntry(key, value.toString()));
    final response = await _apiService.multipartRequest(
      method: 'PATCH',
      endpoint: ApiConstants.productDetailUrl(uuid),
      fields: fields,
      fileBytes: fileBytes,
      fileName: fileName,
    );
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

  Future<String?> downloadTemplate() async {
    try {
      final response = await _apiService.get('/api/products/download_template/');
      if (response.statusCode == 200) {
        return response.body;
      }
    } catch (e) {
      debugPrint('Error downloading template: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> bulkUploadProducts(Uint8List fileBytes, String fileName) async {
    try {
      final response = await _apiService.multipartRequest(
        method: 'POST',
        endpoint: '/api/products/bulk_upload/',
        fields: {},
        fileBytes: fileBytes,
        fileName: fileName,
        fileField: 'file',
      );
      if (response.statusCode == 200 || response.statusCode == 207) {
        fetchProducts();
        return jsonDecode(response.body);
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'error': data['error'] ?? 'Upload failed'};
      }
    } catch (e) {
      debugPrint('Error in bulk upload: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
