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

  dynamic _decodeAny(http.Response response) {
    final dynamic value = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = value is Map ? (value['detail'] ?? value.values.first) : 'Request failed';
      throw Exception(message.toString());
    }
    return value;
  }

  Map<String, dynamic> _decode(http.Response response) => Map<String, dynamic>.from(_decodeAny(response) as Map);

  Future<List<Map<String, dynamic>>> products() async {
    final response = await http.get(Uri.parse('$baseUrl/catalog/products/'));
    final data = _decode(response);
    final rows = data['results'] ?? data;
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>> cart() async {
    final response = await _authorized((headers) => http.get(Uri.parse('$baseUrl/commerce/cart/'), headers: headers));
    return _decode(response);
  }

  Future<void> addToCart(int productId, String quantity) async {
    final response = await _authorized((headers) => http.post(
      Uri.parse('$baseUrl/commerce/cart/'),
      headers: headers,
      body: jsonEncode({'product_id': productId, 'quantity': quantity}),
    ));
    _decode(response);
  }

  Future<void> updateCartItem(int itemId, String quantity) async {
    final response = await _authorized((headers) => http.patch(
      Uri.parse('$baseUrl/commerce/cart/items/$itemId/'),
      headers: headers,
      body: jsonEncode({'quantity': quantity}),
    ));
    _decode(response);
  }

  Future<void> removeCartItem(int itemId) async {
    final response = await _authorized((headers) => http.delete(
      Uri.parse('$baseUrl/commerce/cart/'),
      headers: headers,
      body: jsonEncode({'item_id': itemId}),
    ));
    _decodeAny(response);
  }

  Future<List<Map<String, dynamic>>> wishlist() async {
    final response = await _authorized((headers) => http.get(Uri.parse('$baseUrl/commerce/wishlist/'), headers: headers));
    final data = _decodeAny(response);
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> addToWishlist(int productId) async {
    final response = await _authorized((headers) => http.post(
      Uri.parse('$baseUrl/commerce/wishlist/'),
      headers: headers,
      body: jsonEncode({'product_id': productId}),
    ));
    _decode(response);
  }

  Future<void> moveWishlistItemToCart(int itemId, String quantity) async {
    final response = await _authorized((headers) => http.post(
      Uri.parse('$baseUrl/commerce/wishlist/$itemId/move-to-cart/'),
      headers: headers,
      body: jsonEncode({'quantity': quantity}),
    ));
    _decode(response);
  }

  Future<void> removeWishlistItem(int itemId) async {
    final response = await _authorized((headers) => http.delete(
      Uri.parse('$baseUrl/commerce/wishlist/'),
      headers: headers,
      body: jsonEncode({'item_id': itemId}),
    ));
    _decodeAny(response);
  }

  Future<List<Map<String, dynamic>>> addresses() async {
    final response = await _authorized((headers) => http.get(Uri.parse('$baseUrl/commerce/addresses/'), headers: headers));
    return List<Map<String, dynamic>>.from(_decodeAny(response) as List);
  }

  Future<Map<String, dynamic>> createAddress(Map<String, dynamic> address) async {
    final response = await _authorized((headers) => http.post(Uri.parse('$baseUrl/commerce/addresses/'), headers: headers, body: jsonEncode(address)));
    return _decode(response);
  }

  Future<Map<String, dynamic>> updateAddress(int addressId, Map<String, dynamic> address) async {
    final response = await _authorized((headers) => http.patch(
      Uri.parse('$baseUrl/commerce/addresses/$addressId/'),
      headers: headers,
      body: jsonEncode(address),
    ));
    return _decode(response);
  }

  Future<void> deleteAddress(int addressId) async {
    final response = await _authorized((headers) => http.delete(
      Uri.parse('$baseUrl/commerce/addresses/$addressId/'),
      headers: headers,
    ));
    _decodeAny(response);
  }

  Future<Map<String, dynamic>> checkout(int addressId) async {
    final response = await _authorized((headers) => http.post(Uri.parse('$baseUrl/commerce/checkout/'), headers: headers, body: jsonEncode({'address_id': addressId})));
    return _decode(response);
  }

  Future<List<Map<String, dynamic>>> orders() async {
    final response = await _authorized((headers) => http.get(Uri.parse('$baseUrl/commerce/orders/'), headers: headers));
    return List<Map<String, dynamic>>.from(_decodeAny(response) as List);
  }

  Future<Map<String, dynamic>> orderDetail(int orderId) async {
    final response = await _authorized((headers) => http.get(Uri.parse('$baseUrl/commerce/orders/$orderId/'), headers: headers));
    return _decode(response);
  }

  Future<Map<String, dynamic>> createPayment(int orderId) async {
    final response = await _authorized((headers) => http.post(Uri.parse('$baseUrl/commerce/orders/$orderId/payment/create/'), headers: headers));
    return _decode(response);
  }

  Future<Map<String, dynamic>> verifyPayment(int orderId, Map<String, dynamic> payload) async {
    final response = await _authorized((headers) => http.post(Uri.parse('$baseUrl/commerce/orders/$orderId/payment/verify/'), headers: headers, body: jsonEncode(payload)));
    return _decode(response);
  }


  Future<http.Response> _authorized(
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async {
    var response = await send(_headers);
    if (response.statusCode != 401) return response;

    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null || refreshToken.isEmpty) return response;

    final refreshResponse = await http.post(
      Uri.parse('$baseUrl/auth/token/refresh/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': refreshToken}),
    );
    if (refreshResponse.statusCode < 200 || refreshResponse.statusCode >= 300) {
      await logout();
      return response;
    }

    await _saveTokens(_decode(refreshResponse));
    response = await send(_headers);
    return response;
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
