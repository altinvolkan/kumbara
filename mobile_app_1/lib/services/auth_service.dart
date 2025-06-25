import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final String _baseUrl = 'http://192.168.1.21:3000/api';
  User? _currentUser;

  Future<User?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    debugPrint('Registering user: $name, $email');

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
      );

      debugPrint('Register response: ${response.body}');
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final user = User.fromMap(data['user']);
        _currentUser = user;

        // Token'ı güvenli depolama alanına kaydet
        await _storage.write(key: 'token', value: data['token']);
        await _storage.write(key: 'user_id', value: user.id);
        await _storage.write(key: 'user_data', value: jsonEncode(data['user']));

        debugPrint('Registration successful: ${user.toMap()}');
        return user;
      } else {
        final error = jsonDecode(response.body)['error'];
        debugPrint('Registration failed: $error');
        throw Exception(error ?? 'Kayıt başarısız');
      }
    } catch (e) {
      debugPrint('Registration error: $e');
      throw Exception('Kayıt yapılırken bir hata oluştu');
    }
  }

  Future<User?> login({
    required String email,
    required String password,
  }) async {
    debugPrint('Logging in user: $email');

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      debugPrint('Login response: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = User.fromMap(data['user']);
        _currentUser = user;

        // Token'ı güvenli depolama alanına kaydet
        await _storage.write(key: 'token', value: data['token']);
        await _storage.write(key: 'user_id', value: user.id);
        await _storage.write(key: 'user_data', value: jsonEncode(data['user']));

        debugPrint('Login successful: ${user.toMap()}');
        return user;
      } else {
        final error = jsonDecode(response.body)['error'];
        debugPrint('Login failed: $error');
        throw Exception(error ?? 'Giriş başarısız');
      }
    } catch (e) {
      debugPrint('Login error: $e');
      throw Exception('Giriş yapılırken bir hata oluştu');
    }
  }

  Future<void> logout() async {
    debugPrint('Logging out...');
    _currentUser = null;
    await _storage.delete(key: 'user_id');
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'user_data');
    debugPrint('Logged out');
  }

  Future<User?> getCurrentUser() async {
    debugPrint('Getting current user...');

    if (_currentUser != null) {
      debugPrint('Returning cached user: ${_currentUser!.toMap()}');
      return _currentUser;
    }

    final userId = await _storage.read(key: 'user_id');
    final token = await _storage.read(key: 'token');
    final userData = await _storage.read(key: 'user_data');

    debugPrint('Stored user ID: $userId');
    debugPrint('Stored token: $token');
    debugPrint('Stored user data: $userData');

    if (userId == null || token == null || userData == null) {
      debugPrint('No stored user data found');
      return null;
    }

    try {
      final data = jsonDecode(userData);
      _currentUser = User.fromMap(data);
      debugPrint('Current user from storage: ${_currentUser!.toMap()}');
      return _currentUser;
    } catch (e) {
      debugPrint('Error parsing stored user data: $e');
      await logout();
      return null;
    }
  }

  Future<Map<String, dynamic>> createChildAccount({
    required String name,
    required String email,
    required String password,
    required String linkedAccountId,
  }) async {
    debugPrint('Creating child account...');
    final token = await _storage.read(key: 'token');

    if (token == null) {
      throw Exception('Token bulunamadı');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/auth/create-child'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'linkedAccountId': linkedAccountId,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      debugPrint('Child account created: $data');
      return data;
    } else {
      final error = jsonDecode(response.body)['error'];
      debugPrint('Failed to create child account: $error');
      throw Exception(error ?? 'Çocuk hesabı oluşturulamadı');
    }
  }

  Future<List<Map<String, dynamic>>> getChildAccounts() async {
    debugPrint('Getting child accounts...');
    final token = await _storage.read(key: 'token');

    if (token == null) {
      throw Exception('Token bulunamadı');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/auth/children'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      debugPrint('Child accounts: $data');
      return List<Map<String, dynamic>>.from(data);
    } else {
      final error = jsonDecode(response.body)['error'];
      debugPrint('Failed to get child accounts: $error');
      throw Exception(error ?? 'Çocuk hesapları getirilemedi');
    }
  }

  Future<void> updateChildAccount({
    required String childId,
    String? name,
    String? email,
    String? linkedAccountId,
  }) async {
    debugPrint('Updating child account...');
    final token = await _storage.read(key: 'token');

    if (token == null) {
      throw Exception('Token bulunamadı');
    }

    final Map<String, dynamic> updates = {};
    if (name != null) updates['name'] = name;
    if (email != null) updates['email'] = email;
    if (linkedAccountId != null) updates['linkedAccountId'] = linkedAccountId;

    if (updates.isEmpty) {
      debugPrint('No updates provided');
      return;
    }

    final response = await http.put(
      Uri.parse('$_baseUrl/auth/children/$childId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(updates),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['error'];
      debugPrint('Failed to update child account: $error');
      throw Exception(error ?? 'Çocuk hesabı güncellenemedi');
    }
  }

  Future<void> deleteChildAccount(String childId) async {
    debugPrint('Deleting child account...');
    final token = await _storage.read(key: 'token');

    if (token == null) {
      throw Exception('Token bulunamadı');
    }

    final response = await http.delete(
      Uri.parse('$_baseUrl/auth/children/$childId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['error'];
      debugPrint('Failed to delete child account: $error');
      throw Exception(error ?? 'Çocuk hesabı silinemedi');
    }
  }
}
