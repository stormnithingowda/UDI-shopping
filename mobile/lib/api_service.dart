import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  String? _accessToken;
  bool get isSignedIn => _accessToken != null;

  Future<void> restoreSession() async {
    _accessToken = await _storage.read(key: 'access_token');
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    _accessToken = data['access'] as String?;
    if (_accessToken != null) {
      await _storage.write(key: 'access_token', value: _accessToken);
    }
    final refresh = data['refresh'] as String?;
    if (refresh != null) {
      await _storage.write(key: 'refresh_token', value: refresh);
    }
  }

  Future<void> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/token/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    final data = _decode(response);
    await _saveTokens(data);
  }

  Future<void> register(String username, String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/commerce/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'email': email, 'password': password}),
    );
    final data = _decode(response);
    await _saveTokens(data);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final dynamic value = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = value is Map ? (value['detail'] ?? value.values.first) : 'Request failed';
      throw Exception(message.toString());
    }
    return Map<String, dynamic>.from(value as Map);
  }

  Future<List<Map<String, dynamic>>> products() async {
    final response = await http.get(Uri.parse('$baseUrl/catalog/products/'));
    final data = _decode(response);
    final rows = data['results'] ?? data;
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>> cart() async {
    final response = await http.get(Uri.parse('$baseUrl/commerce/cart/'), headers: _headers);
    return _decode(response);
  }

  Future<void> addToCart(int productId, String quantity) async {
    final response = await http.post(
      Uri.parse('$baseUrl/commerce/cart/'),
      headers: _headers,
      body: jsonEncode({'product_id': productId, 'quantity': quantity}),
    );
    _decode(response);
  }

  Future<void> updateCartItem(int itemId, String quantity) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/commerce/cart/items/$itemId/'),
      headers: _headers,
      body: jsonEncode({'quantity': quantity}),
    );
    _decode(response);
  }

  Future<void> removeCartItem(int itemId) async {
    final request = http.Request('DELETE', Uri.parse('$baseUrl/commerce/cart/'))
      ..headers.addAll(_headers)
      ..body = jsonEncode({'item_id': itemId});
    final streamed = await request.send();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('Could not remove cart item');
    }
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  Future<void> logout() async {
    _accessToken = null;
    await _storage.deleteAll();
  }
}
