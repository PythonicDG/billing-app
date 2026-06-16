import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'constants.dart';

class ApiService {
  static const _secureStorage = FlutterSecureStorage();

  // --- Auth Token (user login) ---

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> saveToken(String token, String role, int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('role', role);
    await prefs.setInt('userId', userId);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // Also clear dashboard token from secure storage
    await clearDashboardToken();
  }

  // --- Dashboard Access Token (secure storage) ---

  Future<String?> getDashboardToken() async {
    return await _secureStorage.read(key: 'dashboard_token');
  }

  Future<String?> getDashboardTokenExpiry() async {
    return await _secureStorage.read(key: 'dashboard_token_expires_at');
  }

  Future<void> saveDashboardToken(String token, String expiresAt) async {
    await _secureStorage.write(key: 'dashboard_token', value: token);
    await _secureStorage.write(key: 'dashboard_token_expires_at', value: expiresAt);
  }

  Future<void> clearDashboardToken() async {
    await _secureStorage.delete(key: 'dashboard_token');
    await _secureStorage.delete(key: 'dashboard_token_expires_at');
  }

  // --- HTTP Headers ---

  Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Token $token',
    };
  }

  Future<Map<String, String>> _getDashboardHeaders() async {
    final headers = await _getHeaders();
    final dashToken = await getDashboardToken();
    if (dashToken != null) {
      headers['X-Dashboard-Token'] = dashToken;
    }
    return headers;
  }

  // --- Standard HTTP Methods ---

  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    return await http.post(
      Uri.parse('${ApiConstants.baseUrl}$endpoint'),
      headers: headers,
      body: jsonEncode(body),
    );
  }

  Future<http.Response> get(String endpoint, {Map<String, String>? queryParams}) async {
    final headers = await _getHeaders();
    
    // If endpoint is a full URL (from pagination next/previous), use it
    Uri uri;
    if (endpoint.startsWith('http')) {
      uri = Uri.parse(endpoint);
    } else {
      uri = Uri.parse('${ApiConstants.baseUrl}$endpoint').replace(queryParameters: queryParams);
    }
        
    return await http.get(uri, headers: headers);
  }

  Future<http.Response> put(String endpoint, Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    return await http.put(
      Uri.parse('${ApiConstants.baseUrl}$endpoint'),
      headers: headers,
      body: jsonEncode(body),
    );
  }

  Future<http.Response> patch(String endpoint, Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    return await http.patch(
      Uri.parse('${ApiConstants.baseUrl}$endpoint'),
      headers: headers,
      body: jsonEncode(body),
    );
  }

  Future<http.Response> delete(String endpoint) async {
    final headers = await _getHeaders();
    return await http.delete(
      Uri.parse('${ApiConstants.baseUrl}$endpoint'),
      headers: headers,
    );
  }

  // --- Dashboard-specific HTTP Methods (includes X-Dashboard-Token) ---

  Future<http.Response> dashboardGet(String endpoint, {Map<String, String>? queryParams}) async {
    final headers = await _getDashboardHeaders();
    
    Uri uri;
    if (endpoint.startsWith('http')) {
      uri = Uri.parse(endpoint);
    } else {
      uri = Uri.parse('${ApiConstants.baseUrl}$endpoint').replace(queryParameters: queryParams);
    }
        
    return await http.get(uri, headers: headers);
  }

  // --- Multipart ---

  Future<http.Response> multipartRequest({
    required String method,
    required String endpoint,
    required Map<String, String> fields,
    Uint8List? fileBytes,
    String? fileName,
    String fileField = 'image',
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final request = http.MultipartRequest(method, uri);
    
    final token = await getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Token $token';
    }

    request.fields.addAll(fields);

    if (fileBytes != null && fileName != null) {
      request.files.add(http.MultipartFile.fromBytes(
        fileField,
        fileBytes,
        filename: fileName,
        contentType: MediaType('image', fileName.split('.').last),
      ));
    }

    final streamedResponse = await request.send();
    return await http.Response.fromStream(streamedResponse);
  }
}
