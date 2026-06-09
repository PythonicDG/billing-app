import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'constants.dart';

class DashboardProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  // Dashboard summary state
  Map<String, dynamic>? _dashboardData;
  bool _isDashboardLoading = false;
  String? _dashboardError;
  String _dashboardRange = 'today';

  // Daily sales state
  Map<String, dynamic>? _dailySalesData;
  bool _isDailySalesLoading = false;
  String? _dailySalesError;

  // Outstanding customers state
  Map<String, dynamic>? _outstandingData;
  bool _isOutstandingLoading = false;
  String? _outstandingError;

  // Stock summary state
  Map<String, dynamic>? _stockData;
  bool _isStockLoading = false;
  String? _stockError;

  // Customer sales state
  Map<String, dynamic>? _customerSalesData;
  bool _isCustomerSalesLoading = false;
  String? _customerSalesError;

  // Getters
  Map<String, dynamic>? get dashboardData => _dashboardData;
  bool get isDashboardLoading => _isDashboardLoading;
  String? get dashboardError => _dashboardError;
  String get dashboardRange => _dashboardRange;

  Map<String, dynamic>? get dailySalesData => _dailySalesData;
  bool get isDailySalesLoading => _isDailySalesLoading;
  String? get dailySalesError => _dailySalesError;

  Map<String, dynamic>? get outstandingData => _outstandingData;
  bool get isOutstandingLoading => _isOutstandingLoading;
  String? get outstandingError => _outstandingError;

  Map<String, dynamic>? get stockData => _stockData;
  bool get isStockLoading => _isStockLoading;
  String? get stockError => _stockError;

  Map<String, dynamic>? get customerSalesData => _customerSalesData;
  bool get isCustomerSalesLoading => _isCustomerSalesLoading;
  String? get customerSalesError => _customerSalesError;

  void refreshAll() {
    fetchDashboardSummary(range: _dashboardRange);
    fetchOutstandingCustomers();
    fetchStockSummary();
    if (_dailySalesData != null && _dailySalesData!['date'] != null) {
      fetchDailySales(_dailySalesData!['date'].toString());
    }
  }

  void setDashboardRange(String range) {
    _dashboardRange = range;
    fetchDashboardSummary(range: range);
  }

  Future<void> fetchDashboardSummary({String? range}) async {
    _isDashboardLoading = true;
    _dashboardError = null;
    notifyListeners();

    try {
      final response = await _apiService.get(
        ApiConstants.dashboardSummaryUrl,
        queryParams: {'range': range ?? _dashboardRange},
      );
      if (response.statusCode == 200) {
        _dashboardData = jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        _dashboardError = 'Failed to load dashboard (${response.statusCode})';
      }
    } catch (e) {
      _dashboardError = 'Connection error: $e';
    }

    _isDashboardLoading = false;
    notifyListeners();
  }

  Future<void> fetchDailySales(String date) async {
    _isDailySalesLoading = true;
    _dailySalesError = null;
    notifyListeners();

    try {
      final response = await _apiService.get(
        ApiConstants.dailySalesUrl,
        queryParams: {'date': date},
      );
      if (response.statusCode == 200) {
        _dailySalesData = jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        _dailySalesError = 'Failed to load daily sales (${response.statusCode})';
      }
    } catch (e) {
      _dailySalesError = 'Connection error: $e';
    }

    _isDailySalesLoading = false;
    notifyListeners();
  }

  Future<void> fetchOutstandingCustomers() async {
    _isOutstandingLoading = true;
    _outstandingError = null;
    notifyListeners();

    try {
      final response = await _apiService.get(ApiConstants.outstandingReportUrl);
      if (response.statusCode == 200) {
        _outstandingData = jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        _outstandingError = 'Failed to load outstanding report (${response.statusCode})';
      }
    } catch (e) {
      _outstandingError = 'Connection error: $e';
    }

    _isOutstandingLoading = false;
    notifyListeners();
  }

  Future<void> fetchStockSummary() async {
    _isStockLoading = true;
    _stockError = null;
    notifyListeners();

    try {
      final response = await _apiService.get(ApiConstants.stockSummaryUrl);
      if (response.statusCode == 200) {
        _stockData = jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        _stockError = 'Failed to load stock summary (${response.statusCode})';
      }
    } catch (e) {
      _stockError = 'Connection error: $e';
    }

    _isStockLoading = false;
    notifyListeners();
  }

  Future<void> fetchCustomerSales(String customerId, String from, String to) async {
    _isCustomerSalesLoading = true;
    _customerSalesError = null;
    notifyListeners();

    try {
      final response = await _apiService.get(
        ApiConstants.customerSalesUrl,
        queryParams: {
          'customer_id': customerId,
          'from': from,
          'to': to,
        },
      );
      if (response.statusCode == 200) {
        _customerSalesData = jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        _customerSalesError = 'Failed to load customer sales (${response.statusCode})';
      }
    } catch (e) {
      _customerSalesError = 'Connection error: $e';
    }

    _isCustomerSalesLoading = false;
    notifyListeners();
  }
}
