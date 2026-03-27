import 'dart:convert';
import 'package:flutter/material.dart';
import '../api_service.dart';
import '../constants.dart';

class Staff {
  final int userId;
  final String username;
  final String email;
  final String role;
  final bool isActive;

  Staff({
    required this.userId,
    required this.username,
    required this.email,
    required this.role,
    required this.isActive,
  });

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      userId: int.tryParse((json['user_id'] ?? json['id'] ?? '0').toString()) ?? 0,
      username: (json['username'] ?? json['user']?['username'] ?? 'Unknown').toString(),
      email: (json['email'] ?? json['user']?['email'] ?? '').toString(),
      role: (json['role'] ?? 'STAFF').toString(),
      isActive: json['is_active'] == true || json['is_active'] == 1,
    );
  }
}

class StaffProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Staff> _staffList = [];
  bool _isLoading = false;

  List<Staff> get staffList => _staffList;
  bool get isLoading => _isLoading;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> fetchStaffList() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.get(ApiConstants.staffListUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map) {
          final List? results = data['results'] ?? data['staff'] ?? data['data'];
          if (results != null) {
            _staffList = results.map((s) => Staff.fromJson(s as Map<String, dynamic>)).toList();
          } else {
            // If it's a map but doesn't have the above keys, maybe the map itself is the object (unlikely for list)
            _staffList = [];
          }
        } else if (data is List) {
          _staffList = data.map((s) => Staff.fromJson(s as Map<String, dynamic>)).toList();
        }
      } else {
        debugPrint('Failed to fetch staff: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching staff: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createStaff(Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.post(ApiConstants.staffCreateUrl, data);
      _isLoading = false;

      if (response.statusCode == 201) {
        fetchStaffList();
        notifyListeners();
        return true;
      } else {
        final errorData = jsonDecode(response.body);
        _errorMessage = errorData.toString(); // Catch raw error for debugging
        debugPrint('Staff creation error: ${response.statusCode} - ${response.body}');
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Connection error: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deactivateStaff(int userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiService.patch(ApiConstants.deactivateStaffUrl(userId), {});
      _isLoading = false;
      if (response.statusCode == 200) {
        fetchStaffList();
        return true;
      }
    } catch (e) {
       _isLoading = false;
       notifyListeners();
    }
    return false;
  }
}
