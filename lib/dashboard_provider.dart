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
  bool _dashboardAccessDenied = false;

  // Getters
  Map<String, dynamic>? get dashboardData => _dashboardData;
  bool get isDashboardLoading => _isDashboardLoading;
  String? get dashboardError => _dashboardError;
  String get dashboardRange => _dashboardRange;
  bool get dashboardAccessDenied => _dashboardAccessDenied;

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
    _dashboardAccessDenied = false;
    notifyListeners();

    try {
      // Use dashboardGet which includes the X-Dashboard-Token header
      final response = await _apiService.dashboardGet(
        ApiConstants.dashboardSummaryUrl,
        queryParams: {'range': range ?? _dashboardRange},
      );
      if (response.statusCode == 200) {
        _dashboardData = jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 403) {
        // Dashboard access denied — token missing or expired
        _dashboardAccessDenied = true;
        _dashboardError = 'Dashboard access denied. Please re-enter your PIN.';
      } else {
        _dashboardError = 'Failed to load dashboard (${response.statusCode})';
      }
    } catch (e) {
      _dashboardError = 'Connection error: $e';
    }

    _isDashboardLoading = false;
    notifyListeners();
  }

  /// Clear all dashboard data (called on logout or access revocation).
  void clearDashboardData() {
    _dashboardData = null;
    _dashboardError = null;
    _dashboardAccessDenied = false;
    _dashboardRange = 'today';
    notifyListeners();
  }
}
