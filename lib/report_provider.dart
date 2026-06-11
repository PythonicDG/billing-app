import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'constants.dart';

class ReportProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  List<dynamic>? _outstandingList;
  List<dynamic>? get outstandingList => _outstandingList;

  List<dynamic>? _topCustomers;
  List<dynamic>? get topCustomers => _topCustomers;

  Map<String, dynamic>? _analyticsData;
  Map<String, dynamic>? get analyticsData => _analyticsData;

  Map<String, dynamic>? _dailySnapshot;
  Map<String, dynamic>? get dailySnapshot => _dailySnapshot;

  List<dynamic>? _lowStockAudit;
  List<dynamic>? get lowStockAudit => _lowStockAudit;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> fetchOutstandingList() async {
    _setLoading(true);
    _error = null;
    try {
      final response = await _apiService.get(ApiConstants.reportCustomersUrl, queryParams: {'type': 'outstanding'});
      if (response.statusCode == 200) {
        _outstandingList = jsonDecode(response.body);
      } else {
        _error = 'Failed to fetch outstanding list';
      }
    } catch (e) {
      _error = e.toString();
    }
    _setLoading(false);
  }

  Future<void> fetchTopCustomers() async {
    _setLoading(true);
    _error = null;
    try {
      final response = await _apiService.get(ApiConstants.reportCustomersUrl, queryParams: {'type': 'top_customers'});
      if (response.statusCode == 200) {
        _topCustomers = jsonDecode(response.body);
      } else {
        _error = 'Failed to fetch top customers';
      }
    } catch (e) {
      _error = e.toString();
    }
    _setLoading(false);
  }

  Future<void> fetchAnalytics(int days) async {
    _setLoading(true);
    _error = null;
    try {
      final response = await _apiService.get(ApiConstants.reportAnalyticsUrl, queryParams: {'days': days.toString()});
      if (response.statusCode == 200) {
        _analyticsData = jsonDecode(response.body);
      } else {
        _error = 'Failed to fetch analytics';
      }
    } catch (e) {
      _error = e.toString();
    }
    _setLoading(false);
  }

  Future<void> fetchDailySnapshot() async {
    _setLoading(true);
    _error = null;
    try {
      final response = await _apiService.get(ApiConstants.reportOperationsUrl, queryParams: {'type': 'daily_snapshot'});
      if (response.statusCode == 200) {
        _dailySnapshot = jsonDecode(response.body);
      } else {
        _error = 'Failed to fetch daily snapshot';
      }
    } catch (e) {
      _error = e.toString();
    }
    _setLoading(false);
  }

  Future<void> fetchLowStockAudit() async {
    _setLoading(true);
    _error = null;
    try {
      final response = await _apiService.get(ApiConstants.reportOperationsUrl, queryParams: {'type': 'low_stock'});
      if (response.statusCode == 200) {
        _lowStockAudit = jsonDecode(response.body);
      } else {
        _error = 'Failed to fetch low stock audit';
      }
    } catch (e) {
      _error = e.toString();
    }
    _setLoading(false);
  }

  Future<Uint8List?> downloadReport(String url, Map<String, String> params) async {
    try {
      final response = await _apiService.get(url, queryParams: {...params, 'download': 'true'});
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      print('Download error: $e');
    }
    return null;
  }
}
