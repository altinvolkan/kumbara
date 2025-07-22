import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ChildService {
  static const String _baseUrl = 'http://192.168.1.21:3000/api';
  final AuthService _authService = AuthService();

  // Çocukları listele
  Future<List<Map<String, dynamic>>> getChildren() async {
    debugPrint('Getting children...');

    try {
      final headers = await _authService.getAuthHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/children'),
        headers: headers,
      );

      debugPrint(
          'Children response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        debugPrint('Children retrieved: ${data.length}');
        return data.cast<Map<String, dynamic>>();
      } else {
        final error = jsonDecode(response.body)['error'];
        debugPrint('Failed to get children: $error');
        throw Exception(error ?? 'Çocuklar alınamadı');
      }
    } catch (e) {
      debugPrint('Get children error: $e');
      throw Exception('Çocukları alırken bir hata oluştu');
    }
  }

  // Yeni çocuk oluştur
  Future<bool> createChild({
    required String name,
    required String email,
    required String password,
    required String linkedAccountId,
  }) async {
    debugPrint('Creating child: $name with account: $linkedAccountId');

    try {
      final headers = await _authService.getAuthHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/create-child'),
        headers: headers,
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'linkedAccountId': linkedAccountId,
        }),
      );

      debugPrint(
          'Create child response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 201) {
        debugPrint('Child created successfully');
        return true;
      } else {
        final error = jsonDecode(response.body)['error'];
        debugPrint('Failed to create child: $error');
        throw Exception(error ?? 'Çocuk hesabı oluşturulamadı');
      }
    } catch (e) {
      debugPrint('Create child error: $e');
      throw Exception('Çocuk hesabı oluşturulurken bir hata oluştu');
    }
  }

  // Çocuğu güncelle
  Future<bool> updateChild({
    required String childId,
    String? name,
    String? email,
    String? linkedAccountId,
  }) async {
    debugPrint('Updating child: $childId');

    try {
      final headers = await _authService.getAuthHeaders();
      final Map<String, dynamic> body = {};

      if (name != null) body['name'] = name;
      if (email != null) body['email'] = email;
      if (linkedAccountId != null) body['linkedAccountId'] = linkedAccountId;

      final response = await http.patch(
        Uri.parse('$_baseUrl/auth/children/$childId'),
        headers: headers,
        body: jsonEncode(body),
      );

      debugPrint(
          'Update child response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        debugPrint('Child updated successfully');
        return true;
      } else {
        final error = jsonDecode(response.body)['error'];
        debugPrint('Failed to update child: $error');
        throw Exception(error ?? 'Çocuk hesabı güncellenemedi');
      }
    } catch (e) {
      debugPrint('Update child error: $e');
      throw Exception('Çocuk hesabı güncellenirken bir hata oluştu');
    }
  }

  // Çocuğu sil
  Future<bool> deleteChild(String childId) async {
    debugPrint('Deleting child: $childId');

    try {
      final headers = await _authService.getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/auth/children/$childId'),
        headers: headers,
      );

      debugPrint(
          'Delete child response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        debugPrint('Child deleted successfully');
        return true;
      } else {
        final error = jsonDecode(response.body)['error'];
        debugPrint('Failed to delete child: $error');
        throw Exception(error ?? 'Çocuk hesabı silinemedi');
      }
    } catch (e) {
      debugPrint('Delete child error: $e');
      throw Exception('Çocuk hesabı silinirken bir hata oluştu');
    }
  }
}
