import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/user.dart';

class AuthService {
  static const String _baseUrl = 'http://192.168.1.21:3000/api';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  User? _currentUser;

  // Kullanıcı giriş yap
  Future<User> login(String email, String password) async {
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

        // Sadece çocuk rolündeki kullanıcılar giriş yapabilir
        if (data['user']['role'] != 'child') {
          throw Exception(
              'Bu uygulama sadece çocuk hesapları için tasarlanmıştır');
        }

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

  // Kullanıcı kayıt ol
  Future<User> register(String name, String email, String password) async {
    debugPrint('Registering user: $email');

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'role': 'child', // Çocuk rolü olarak kaydet
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
      throw Exception('Kayıt olurken bir hata oluştu');
    }
  }

  // Çıkış yap
  Future<void> logout() async {
    debugPrint('Logging out...');
    _currentUser = null;
    await _storage.delete(key: 'user_id');
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'user_data');
    debugPrint('Logged out');
  }

  // Mevcut kullanıcıyı getir
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

  // Token'ı al
  Future<String?> getToken() async {
    return await _storage.read(key: 'token');
  }

  // Authorization header'ını al
  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Kullanıcı profilini güncelle
  Future<User> updateProfile({
    String? name,
    String? avatar,
    UserSettings? settings,
  }) async {
    debugPrint('Updating profile...');

    try {
      final headers = await getAuthHeaders();
      final Map<String, dynamic> updates = {};

      if (name != null) updates['name'] = name;
      if (avatar != null) updates['avatar'] = avatar;
      if (settings != null) updates['settings'] = settings.toMap();

      final response = await http.patch(
        Uri.parse('$_baseUrl/auth/profile'),
        headers: headers,
        body: jsonEncode(updates),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = User.fromMap(data);
        _currentUser = user;

        // Güncellenmiş veriyi sakla
        await _storage.write(key: 'user_data', value: jsonEncode(data));

        debugPrint('Profile updated: ${user.toMap()}');
        return user;
      } else {
        final error = jsonDecode(response.body)['error'];
        debugPrint('Profile update failed: $error');
        throw Exception(error ?? 'Profil güncellenemedi');
      }
    } catch (e) {
      debugPrint('Profile update error: $e');
      throw Exception('Profil güncellenirken bir hata oluştu');
    }
  }
}
