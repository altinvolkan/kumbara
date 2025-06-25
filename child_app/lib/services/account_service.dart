import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class AccountService {
  static const String _baseUrl = 'http://192.168.1.21:3000/api';
  final AuthService _authService = AuthService();

  // Çocuk kullanıcısının bağlı hesap bilgisini getir
  Future<Map<String, dynamic>?> getLinkedAccount() async {
    debugPrint('Getting linked account...');

    try {
      final headers = await _authService.getAuthHeaders();
      debugPrint('Auth headers: $headers');
      debugPrint('API URL: $_baseUrl/accounts/linked');

      final response = await http.get(
        Uri.parse('$_baseUrl/accounts/linked'),
        headers: headers,
      );

      debugPrint(
          'Linked account response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Linked account retrieved: $data');
        return data;
      } else {
        final error = jsonDecode(response.body)['error'];
        debugPrint('Failed to get linked account: $error');
        return null;
      }
    } catch (e) {
      debugPrint('Get linked account error: $e');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  // Hesaptan hedefe manuel para aktarımı
  Future<Map<String, dynamic>> transferToGoal(
      String goalId, double amount) async {
    debugPrint('Transferring $amount to goal $goalId');

    try {
      final headers = await _authService.getAuthHeaders();

      final response = await http.post(
        Uri.parse('$_baseUrl/accounts/transfer-to-goal'),
        headers: headers,
        body: jsonEncode({
          'goalId': goalId,
          'amount': amount,
        }),
      );

      debugPrint(
          'Transfer response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Transfer successful: $data');
        return data;
      } else {
        final error = jsonDecode(response.body)['error'];
        debugPrint('Transfer failed: $error');
        throw Exception(error ?? 'Para aktarımı başarısız');
      }
    } catch (e) {
      debugPrint('Transfer error: $e');
      throw Exception('Para aktarımında bir hata oluştu');
    }
  }

  // Bakiye formatlama
  String formatBalance(double balance) {
    return '${balance.toStringAsFixed(0)}₺';
  }
}
