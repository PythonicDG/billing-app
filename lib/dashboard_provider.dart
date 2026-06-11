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

  // Getters
  Map<String, dynamic>? get dashboardData => _dashboardData;
  bool get isDashboardLoading => _isDashboardLoading;
  String? get dashboardError => _dashboardError;
  String get dashboardRange => _dashboardRange;

  void refreshAll() {
    fetchDashboardSummary(range: _dashboardRange);
  }

  Future<void> setDashboardRange(String range) async {
    _dashboardRange = range;
    await fetchDashboardSummary(range: range);
  }

  Future<void> fetchDashboardSummary({String? range}) async {
    _isDashboardLoading = true;
    _dashboardError = null;
    // We don't necessarily want to clear dashboard data as it's the main screen
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
}
