import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class ApiService {
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
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Token $token',
    };
  }

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
    String queryString = '';
    if (queryParams != null && queryParams.isNotEmpty) {
      queryString = '?' + queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
    }
    
    // If endpoint is a full URL (from pagination next/previous), use it
    Uri uri = endpoint.startsWith('http') 
        ? Uri.parse(endpoint) 
        : Uri.parse('${ApiConstants.baseUrl}$endpoint$queryString');
        
    return await http.get(uri, headers: headers);
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
