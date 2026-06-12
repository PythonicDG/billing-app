import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  // Business Profile
  String _shopName = 'Vighnaharta Fataka';
  String _shopAddress = 'Shop No. 1, Main Road';
  String _shopPhone = '9876543210';
  String _gstNumber = '';
  String _receiptMessage = 'Thank you for your business!';

  // Print & Hardware
  String _printerType = 'A4'; // 'A4' or 'Thermal'
  bool _autoPrint = false;

  // Inventory
  int _lowStockThreshold = 10;
  bool _hideOutOfStock = true;

  // Getters
  String get shopName => _shopName;
  String get shopAddress => _shopAddress;
  String get shopPhone => _shopPhone;
  String get gstNumber => _gstNumber;
  String get receiptMessage => _receiptMessage;
  String get printerType => _printerType;
  bool get autoPrint => _autoPrint;
  int get lowStockThreshold => _lowStockThreshold;
  bool get hideOutOfStock => _hideOutOfStock;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _shopName = prefs.getString('shopName') ?? 'Vighnaharta Fataka';
    _shopAddress = prefs.getString('shopAddress') ?? 'Shop No. 1, Main Road';
    _shopPhone = prefs.getString('shopPhone') ?? '9876543210';
    _gstNumber = prefs.getString('gstNumber') ?? '';
    _receiptMessage = prefs.getString('receiptMessage') ?? 'Thank you for your business!';
    _printerType = prefs.getString('printerType') ?? 'A4';
    _autoPrint = prefs.getBool('autoPrint') ?? false;
    _lowStockThreshold = prefs.getInt('lowStockThreshold') ?? 10;
    _hideOutOfStock = prefs.getBool('hideOutOfStock') ?? true;
    notifyListeners();
  }

  Future<void> updateBusinessProfile({
    String? shopName,
    String? shopAddress,
    String? shopPhone,
    String? gstNumber,
    String? receiptMessage,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (shopName != null) {
      _shopName = shopName;
      await prefs.setString('shopName', shopName);
    }
    if (shopAddress != null) {
      _shopAddress = shopAddress;
      await prefs.setString('shopAddress', shopAddress);
    }
    if (shopPhone != null) {
      _shopPhone = shopPhone;
      await prefs.setString('shopPhone', shopPhone);
    }
    if (gstNumber != null) {
      _gstNumber = gstNumber;
      await prefs.setString('gstNumber', gstNumber);
    }
    if (receiptMessage != null) {
      _receiptMessage = receiptMessage;
      await prefs.setString('receiptMessage', receiptMessage);
    }
    notifyListeners();
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
