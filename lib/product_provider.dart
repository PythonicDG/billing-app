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
  final double centInPerCs;
  final double totalStockInCent;
  final String entryMode;

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
    required this.entryMode,
  });

  String formattedPrice(double price) {
    final unit = entryMode == 'cent' ? 'cent' : 'piece';
    return 'Rs. ${price.toStringAsFixed(2)} / $unit';
  }

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
      centInPerCs: double.tryParse(json['cent_in_per_cs']?.toString() ?? '0') ?? 0.0,
      totalStockInCent: double.tryParse(json['total_stock_in_cent']?.toString() ?? '0.0') ?? 0.0,
      entryMode: json['entry_mode']?.toString() ?? 'cent',
    );
  }
}

class ProductProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Product> _products = [];
  List<Product> _billingProducts = [];
  List<Product> _frequentProducts = [];
  List<Category> _categoriesList = [];
  String? _nextUrl;
  String? _previousUrl;
  bool _isLoading = false;
  String _searchQuery = '';
  String _billingSearchQuery = '';
  String _ordering = '-created_at';
  String _stockFilter = 'all'; // 'all', 'low_stock', 'out_of_stock', 'top_sellers'
  int _pageSize = 12;

  int _currentPage = 1;
  int _totalCount = 0;

  Map<String, dynamic>? _inventoryAnalytics;

  List<Product> get products => _products;
  List<Product> get billingProducts => _billingProducts;
  List<Product> get frequentProducts => _frequentProducts;
  List<Category> get categoriesList => _categoriesList;
  bool get isLoading => _isLoading;
  bool get hasNext => _nextUrl != null;
  bool get hasPrevious => _previousUrl != null;
  int get currentPage => _currentPage;
  int get totalCount => _totalCount;
  String get stockFilter => _stockFilter;
  int get totalPages => (_totalCount / _pageSize).ceil().clamp(1, 99999);
  Map<String, dynamic>? get inventoryAnalytics => _inventoryAnalytics;

  Future<void> fetchInventoryAnalytics() async {
    try {
      final response = await _apiService.get('/api/products/health_analytics/');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _inventoryAnalytics = data['data'];
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error fetching inventory analytics: $e');
    }
  }

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

  Future<void> fetchFrequentProducts() async {
    _isLoading = true;
    _stockFilter = 'top_sellers';
    notifyListeners();
    try {
      final response = await _apiService.get(ApiConstants.frequentProductsUrl);
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        // Strictly take top 10
        final products = data.map((p) => Product.fromJson(p)).take(10).toList();
        _frequentProducts = products;
        
        // If we are currently in top_sellers filter, update the main products list too
        if (_stockFilter == 'top_sellers') {
          _products = products;
          _totalCount = products.length;
          _currentPage = 1;
          _nextUrl = null;
          _previousUrl = null;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching frequent products: $e');
    }
    _isLoading = false;
    notifyListeners();
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

  /// Fetch a specific page from the server (server-side pagination).
  Future<void> fetchPage(int page) async {
    _isLoading = true;
    notifyListeners();

    try {
      final Map<String, String> params = {
        'search': _searchQuery,
        'ordering': _ordering,
        'page': page.toString(),
        'page_size': _pageSize.toString(),
      };
      
      if (_stockFilter != 'all') {
        params['stock_filter'] = _stockFilter;
      }

      final response = await _apiService.get(
        ApiConstants.productsUrl,
        queryParams: params,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('results')) {
          final results = data['results'] as List;
          _products = results.map((p) => Product.fromJson(p)).toList();
          _nextUrl = data['next']?.toString();
          _previousUrl = data['previous']?.toString();
          _totalCount = (data['count'] as num?)?.toInt() ?? 0;
          _currentPage = page;
        } else if (data is List) {
          _products = data.map((p) => Product.fromJson(p)).toList();
          _nextUrl = null;
          _previousUrl = null;
          _totalCount = _products.length;
          _currentPage = 1;
        }
      }
    } catch (e) {
      debugPrint('Error fetching products page $page: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchProducts({bool initial = true, String? url, int? pageSize}) async {
    _isLoading = true;
    if (initial) {
      _currentPage = 1;
      _products = [];
    }
    if (pageSize != null) {
      _pageSize = pageSize;
    }
    notifyListeners();

    try {
      Map<String, String>? params;
      if (url == null) {
        params = {
          'search': _searchQuery,
          'ordering': _ordering,
          'page': _currentPage.toString(),
          'page_size': _pageSize.toString(),
        };
        if (_stockFilter != 'all') {
          params['stock_filter'] = _stockFilter;
        }
      }

      final response = await _apiService.get(
        url ?? ApiConstants.productsUrl,
        queryParams: params,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('results')) {
          final results = data['results'] as List;
          _products = results.map((p) => Product.fromJson(p)).toList();
          _nextUrl = data['next']?.toString();
          _previousUrl = data['previous']?.toString();
          _totalCount = (data['count'] as num?)?.toInt() ?? 0;
        } else if (data is List) {
          _products = data.map((p) => Product.fromJson(p)).toList();
          _nextUrl = null;
          _previousUrl = null;
          _totalCount = _products.length;
        }
      }
    } catch (e) {
      debugPrint('Error fetching products: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchProductsForBilling({String? search, int pageSize = 100}) async {
    _isLoading = true;
    if (search != null) _billingSearchQuery = search;
    notifyListeners();

    try {
      final Map<String, String> params = {
        'search': _billingSearchQuery,
        'page_size': pageSize.toString(),
        'stock_filter': 'available', // Billing should hide out-of-stock products
      };

      final response = await _apiService.get(
        ApiConstants.productsUrl,
        queryParams: params,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('results')) {
          final results = data['results'] as List;
          _billingProducts = results.map((p) => Product.fromJson(p)).toList();
        } else if (data is List) {
          _billingProducts = data.map((p) => Product.fromJson(p)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching products for billing: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  String? get nextUrl => _nextUrl;
  String? get previousUrl => _previousUrl;

  void setStockFilter(String filter) {
    _stockFilter = filter;
    _currentPage = 1;
    if (filter == 'top_sellers') {
      fetchFrequentProducts();
    } else {
      fetchProducts();
    }
  }

  void setSearch(String query) {
    _searchQuery = query;
    _currentPage = 1;
    fetchProducts();
  }

  void setBillingSearch(String query) {
    _billingSearchQuery = query;
    fetchProductsForBilling();
  }

  void setOrdering(String ordering) {
    _ordering = ordering;
    _currentPage = 1;
    fetchProducts();
  }

  Future<List<Product>> searchProducts(String query) async {
    try {
      final response = await _apiService.get(
        ApiConstants.productsUrl,
        queryParams: {
          'search': query,
          'page_size': '20',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('results')) {
          final results = data['results'] as List;
          return results.map((p) => Product.fromJson(p)).toList();
        } else if (data is List) {
          return data.map((p) => Product.fromJson(p)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error searching products: $e');
    }
    return [];
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
      fetchInventoryAnalytics();
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
      fetchPage(_currentPage);
      fetchInventoryAnalytics();
      return true;
    }
    return false;
  }

  Future<bool> deleteProduct(String uuid) async {
    final response = await _apiService.delete(ApiConstants.productDetailUrl(uuid));
    if (response.statusCode == 204) {
      if (_products.length == 1 && _currentPage > 1) {
        _currentPage--;
      }
      fetchPage(_currentPage);
      fetchInventoryAnalytics();
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

  Future<String?> exportProducts() async {
    try {
      final Map<String, String> params = {
        'search': _searchQuery,
        'ordering': _ordering,
      };
      if (_stockFilter != 'all') {
        params['stock_filter'] = _stockFilter;
      }

      final response = await _apiService.get(
        '/api/products/export_csv/',
        queryParams: params,
      );
      if (response.statusCode == 200) {
        return response.body;
      }
    } catch (e) {
      debugPrint('Error exporting products: $e');
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
