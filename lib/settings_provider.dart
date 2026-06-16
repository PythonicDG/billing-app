import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class SettingsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  // Loading state — true once local settings have been read at least once
  bool _settingsLoaded = false;

  // Business Profile
  String _shopName = 'Vighnaharta Fataka';
  String _shopAddress = 'Shop No. 1, Main Road';
  String _shopPhone = '9876543210';
  String _gstNumber = '';
  String _receiptMessage = 'Thank you for your business!';
  String? _logoUrl;

  // Print & Hardware
  String _printerType = 'A4'; // 'A4' or 'Thermal'
  bool _autoPrint = false;

  // Inventory
  int _lowStockThreshold = 10;
  bool _hideOutOfStock = true;

  // Getters
  bool get isSettingsLoaded => _settingsLoaded;
  String get shopName => _shopName;
  String get shopAddress => _shopAddress;
  String get shopPhone => _shopPhone;
  String get gstNumber => _gstNumber;
  String get receiptMessage => _receiptMessage;
  String? get logoUrl => _logoUrl;
  String get printerType => _printerType;
  bool get autoPrint => _autoPrint;
  int get lowStockThreshold => _lowStockThreshold;
  bool get hideOutOfStock => _hideOutOfStock;

  SettingsProvider() {
    _loadLocalSettings();
    fetchRemoteSettings();
  }

  Future<void> _loadLocalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _shopName = prefs.getString('shopName') ?? 'Vighnaharta Fataka';
    _shopAddress = prefs.getString('shopAddress') ?? 'Shop No. 1, Main Road';
    _shopPhone = prefs.getString('shopPhone') ?? '9876543210';
    _gstNumber = prefs.getString('gstNumber') ?? '';
    _receiptMessage = prefs.getString('receiptMessage') ?? 'Thank you for your business!';
    _logoUrl = prefs.getString('logoUrl');
    _printerType = prefs.getString('printerType') ?? 'A4';
    _autoPrint = prefs.getBool('autoPrint') ?? false;
    _lowStockThreshold = prefs.getInt('lowStockThreshold') ?? 10;
    _hideOutOfStock = prefs.getBool('hideOutOfStock') ?? true;
    _settingsLoaded = true;
    notifyListeners();
  }

  Future<void> fetchRemoteSettings() async {
    try {
      final response = await _apiService.get('core/settings/');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _shopName = data['name'] ?? _shopName;
        _shopAddress = data['address'] ?? _shopAddress;
        _shopPhone = data['phone'] ?? _shopPhone;
        _gstNumber = data['gst_number'] ?? _gstNumber;
        _receiptMessage = data['receipt_message'] ?? _receiptMessage;
        _logoUrl = data['logo'];
        
        // Save to local too for offline/fast load
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('shopName', _shopName);
        await prefs.setString('shopAddress', _shopAddress);
        await prefs.setString('shopPhone', _shopPhone);
        await prefs.setString('gstNumber', _gstNumber);
        await prefs.setString('receiptMessage', _receiptMessage);
        if (_logoUrl != null) await prefs.setString('logoUrl', _logoUrl!);
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching remote settings: $e');
    }
  }

  Future<void> uploadLogo(Uint8List bytes, String fileName) async {
    try {
      final response = await _apiService.multipartRequest(
        method: 'PATCH',
        endpoint: 'core/settings/update_settings/',
        fields: {},
        fileBytes: bytes,
        fileName: fileName,
        fileField: 'logo',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _logoUrl = data['logo'];
        
        final prefs = await SharedPreferences.getInstance();
        if (_logoUrl != null) await prefs.setString('logoUrl', _logoUrl!);
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error uploading logo: $e');
    }
  }

  Future<void> updateBusinessProfile({
    String? shopName,
    String? shopAddress,
    String? shopPhone,
    String? gstNumber,
    String? receiptMessage,
  }) async {
    final Map<String, dynamic> body = {};
    if (shopName != null) body['name'] = shopName;
    if (shopAddress != null) body['address'] = shopAddress;
    if (shopPhone != null) body['phone'] = shopPhone;
    if (gstNumber != null) body['gst_number'] = gstNumber;
    if (receiptMessage != null) body['receipt_message'] = receiptMessage;

    try {
      final response = await _apiService.patch('core/settings/update_settings/', body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _shopName = data['name'];
        _shopAddress = data['address'];
        _shopPhone = data['phone'];
        _gstNumber = data['gst_number'] ?? '';
        _receiptMessage = data['receipt_message'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('shopName', _shopName);
        await prefs.setString('shopAddress', _shopAddress);
        await prefs.setString('shopPhone', _shopPhone);
        await prefs.setString('gstNumber', _gstNumber);
        await prefs.setString('receiptMessage', _receiptMessage);
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating business profile: $e');
    }
  }

  Future<void> setPrinterType(String type) async {
    _printerType = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printerType', type);
    notifyListeners();
  }

  Future<void> setAutoPrint(bool value) async {
    _autoPrint = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoPrint', value);
    notifyListeners();
  }

  Future<void> setLowStockThreshold(int value) async {
    _lowStockThreshold = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lowStockThreshold', value);
    notifyListeners();
  }

  Future<void> setHideOutOfStock(bool value) async {
    _hideOutOfStock = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hideOutOfStock', value);
    notifyListeners();
  }


}
