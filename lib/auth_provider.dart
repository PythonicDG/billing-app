import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'constants.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  String? _token;
  String? _role;
  int? _userId;
  bool _isLoading = false;
  String? _errorMessage;

  String? get token => _token;
  String? get role => _role;
  int? get userId => _userId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _token != null;

  AuthProvider() {
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _role = prefs.getString('role');
    _userId = prefs.getInt('userId');
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.post(ApiConstants.loginUrl, {
        'username': username,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        _role = data['role'];
        _userId = data['user_id'];
        await _apiService.saveToken(_token!, _role!, _userId!);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final data = jsonDecode(response.body);
        _errorMessage = data['non_field_errors']?[0] ?? 'Login failed';
      }
    } catch (e) {
      debugPrint('Login error: $e');
      _errorMessage = 'Connection error';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.post(ApiConstants.changePasswordUrl, {
        'old_password': oldPassword,
        'new_password': newPassword,
      });

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        // Handle DRF validation errors
        if (data is Map) {
           if (data.containsKey('old_password')) {
             _errorMessage = data['old_password'][0];
           } else if (data.containsKey('new_password')) {
             _errorMessage = data['new_password'][0];
           } else if (data.containsKey('non_field_errors')) {
             _errorMessage = data['non_field_errors'][0];
           } else if (data.containsKey('error')) {
             _errorMessage = data['error'];
           } else {
             _errorMessage = 'Failed to change password';
           }
        }
      }
    } catch (e) {
      debugPrint('Change password error: $e');
      _errorMessage = 'Connection error';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    await _apiService.logout();  // This already clears dashboard token via ApiService.logout()
    _token = null;
    _role = null;
    _userId = null;
    notifyListeners();
  }
}
