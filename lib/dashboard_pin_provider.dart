import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'constants.dart';

class DashboardPinProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  // PIN status (from server)
  bool _hasPinSet = false;
  bool _statusLoaded = false;
  bool _isLocked = false;
  int _lockoutRemainingSeconds = 0;

  // Verification state
  bool _isVerified = false;
  String? _dashboardToken;
  DateTime? _tokenExpiresAt;
  int _attemptsRemaining = 5;
  String? _errorMessage;
  bool _isLoading = false;

  // Auto-expiry timer
  Timer? _expiryTimer;

  // Getters
  bool get hasPinSet => _hasPinSet;
  bool get isStatusLoaded => _statusLoaded;
  bool get isLocked => _isLocked;
  int get lockoutRemainingSeconds => _lockoutRemainingSeconds;
  bool get isVerified => _isVerified;
  String? get dashboardToken => _dashboardToken;
  int get attemptsRemaining => _attemptsRemaining;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  DashboardPinProvider() {
    _restoreTokenFromStorage();
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  /// Restore dashboard token from secure storage on startup.
  Future<void> _restoreTokenFromStorage() async {
    try {
      final token = await _apiService.getDashboardToken();
      final expiryStr = await _apiService.getDashboardTokenExpiry();

      if (token != null && expiryStr != null) {
        final expiry = DateTime.tryParse(expiryStr);
        if (expiry != null && DateTime.now().isBefore(expiry)) {
          _dashboardToken = token;
          _tokenExpiresAt = expiry;
          _isVerified = true;
          _startExpiryTimer();
        } else {
          // Token expired — clean up
          await _apiService.clearDashboardToken();
        }
      }
    } catch (e) {
      debugPrint('Error restoring dashboard token: $e');
    }
    // Don't notifyListeners here — checkPinStatus will do it
  }

  /// Check if a PIN is set on the server.
  Future<void> checkPinStatus() async {
    try {
      final response = await _apiService.get(ApiConstants.dashboardPinStatusUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _hasPinSet = data['has_pin'] == true;
        _isLocked = data['is_locked'] == true;
        _lockoutRemainingSeconds = data['lockout_remaining_seconds'] ?? 0;
        _statusLoaded = true;
        
        // If no PIN is set, user is effectively "verified"
        if (!_hasPinSet) {
          _isVerified = true;
        }
      }
    } catch (e) {
      debugPrint('Error checking PIN status: $e');
      // On error, mark as loaded so the UI doesn't hang
      _statusLoaded = true;
    }
    notifyListeners();
  }

  /// Verify the entered PIN against the server.
  Future<bool> verifyPin(String pin) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        ApiConstants.dashboardPinVerifyUrl,
        {'pin': pin},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['has_pin'] == false) {
          // No PIN set — just grant access
          _isVerified = true;
          _isLoading = false;
          notifyListeners();
          return true;
        }

        _dashboardToken = data['dashboard_token'];
        final expiresAtStr = data['expires_at'];
        _tokenExpiresAt = DateTime.tryParse(expiresAtStr ?? '');
        _isVerified = true;
        _attemptsRemaining = 5;
        _errorMessage = null;

        // Persist token securely
        await _apiService.saveDashboardToken(_dashboardToken!, expiresAtStr);

        // Start expiry timer
        _startExpiryTimer();

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final data = jsonDecode(response.body);
        _errorMessage = data['error'] ?? 'Incorrect PIN.';
        _attemptsRemaining = data['attempts_remaining'] ?? 0;
        _isLocked = data['is_locked'] == true;
        _lockoutRemainingSeconds = data['lockout_remaining_seconds'] ?? 0;

        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Connection error. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Set a new PIN (OWNER only).
  Future<bool> setPin(String pin) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.post(
        ApiConstants.dashboardPinSetUrl,
        {'pin': pin},
      );

      _isLoading = false;
      if (response.statusCode == 200) {
        _hasPinSet = true;
        // After setting PIN, the current user is NOT auto-verified
        // They'll need to enter it to access the dashboard
        _isVerified = false;
        _dashboardToken = null;
        _tokenExpiresAt = null;
        await _apiService.clearDashboardToken();
        notifyListeners();
        return true;
      } else {
        final data = jsonDecode(response.body);
        _errorMessage = data['detail'] ?? data['pin']?.toString() ?? 'Failed to set PIN.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Connection error.';
      notifyListeners();
      return false;
    }
  }

  /// Remove PIN protection (OWNER only).
  Future<bool> removePin() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.post(
        ApiConstants.dashboardPinRemoveUrl,
        {},
      );

      _isLoading = false;
      if (response.statusCode == 200) {
        _hasPinSet = false;
        _isVerified = true; // No PIN = always verified
        _dashboardToken = null;
        _tokenExpiresAt = null;
        _expiryTimer?.cancel();
        await _apiService.clearDashboardToken();
        notifyListeners();
        return true;
      } else {
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Connection error.';
      notifyListeners();
      return false;
    }
  }

  /// Revoke dashboard access (logout from dashboard).
  Future<void> revokeAccess() async {
    // If no PIN is set, we are always effectively verified.
    if (!_hasPinSet && _statusLoaded) return;
    
    // If already revoked, don't do it again.
    if (!_isVerified && _dashboardToken == null) return;

    // Set local state immediately for responsiveness
    _isVerified = false;
    _dashboardToken = null;
    _tokenExpiresAt = null;
    _errorMessage = null;
    _attemptsRemaining = 5;
    _expiryTimer?.cancel();
    await _apiService.clearDashboardToken();
    notifyListeners();

    // Notify server in background
    try {
      await _apiService.post(ApiConstants.dashboardPinRevokeUrl, {});
    } catch (_) {}
  }

  /// Called on app logout — clears everything.
  Future<void> clearAll() async {
    _hasPinSet = false;
    _statusLoaded = false;
    _isVerified = false;
    _dashboardToken = null;
    _tokenExpiresAt = null;
    _errorMessage = null;
    _isLocked = false;
    _lockoutRemainingSeconds = 0;
    _attemptsRemaining = 5;
    _expiryTimer?.cancel();
    await _apiService.clearDashboardToken();
    notifyListeners();
  }

  /// Start a timer that auto-revokes access when the token expires.
  void _startExpiryTimer() {
    _expiryTimer?.cancel();
    if (_tokenExpiresAt == null) return;

    final remaining = _tokenExpiresAt!.difference(DateTime.now());
    if (remaining.isNegative) {
      // Already expired
      _isVerified = false;
      _dashboardToken = null;
      notifyListeners();
      return;
    }

    _expiryTimer = Timer(remaining, () {
      _isVerified = false;
      _dashboardToken = null;
      _tokenExpiresAt = null;
      _apiService.clearDashboardToken();
      notifyListeners();
    });
  }

  /// Clear error message (e.g., when user starts typing).
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }
}
