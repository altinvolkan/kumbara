import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AccountService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final String _baseUrl = 'http://192.168.1.21:3000/api';

  Future<List<Map<String, dynamic>>> getAccounts() async {
    debugPrint('Getting accounts...');
    final token = await _storage.read(key: 'token');

    if (token == null) {
      throw Exception('Token bulunamadı');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/accounts'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      debugPrint('Accounts: $data');
      return List<Map<String, dynamic>>.from(data);
    } else {
      final error = jsonDecode(response.body)['error'];
      debugPrint('Failed to get accounts: $error');
      throw Exception(error ?? 'Hesaplar getirilemedi');
    }
  }

  Future<Map<String, dynamic>> getAccountSummary() async {
    debugPrint('Getting account summary...');
    final token = await _storage.read(key: 'token');

    if (token == null) {
      throw Exception('Token bulunamadı');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/accounts/summary'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      debugPrint('Account summary: $data');
      return data;
    } else {
      final error = jsonDecode(response.body)['error'];
      debugPrint('Failed to get account summary: $error');
      throw Exception(error ?? 'Hesap özeti getirilemedi');
    }
  }

  Future<void> deposit({
    required String accountId,
    required double amount,
  }) async {
    debugPrint('Depositing $amount to account: $accountId');
    final token = await _storage.read(key: 'token');

    if (token == null) {
      throw Exception('Token bulunamadı');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/accounts/$accountId/deposit'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'amount': amount}),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['error'];
      debugPrint('Failed to deposit: $error');
      throw Exception(error ?? 'Para yatırma işlemi başarısız');
    }
  }

  Future<void> withdraw({
    required String accountId,
    required double amount,
  }) async {
    debugPrint('Withdrawing $amount from account: $accountId');
    final token = await _storage.read(key: 'token');

    if (token == null) {
      throw Exception('Token bulunamadı');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/accounts/$accountId/withdraw'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'amount': amount}),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['error'];
      debugPrint('Failed to withdraw: $error');
      throw Exception(error ?? 'Para çekme işlemi başarısız');
    }
  }

  Future<void> transfer({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
  }) async {
    debugPrint(
      'Transferring $amount from account $fromAccountId to account $toAccountId',
    );
    final token = await _storage.read(key: 'token');

    if (token == null) {
      throw Exception('Token bulunamadı');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/accounts/transfer'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'fromAccountId': fromAccountId,
        'toAccountId': toAccountId,
        'amount': amount,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['error'];
      debugPrint('Failed to transfer: $error');
      throw Exception(error ?? 'Transfer işlemi başarısız');
    }
  }

  Future<void> createAccount({
    required String name,
    required String type,
    required double targetAmount,
    required String description,
  }) async {
    debugPrint('Creating account: $name');
    final token = await _storage.read(key: 'token');

    if (token == null) {
      throw Exception('Token bulunamadı');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/accounts'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'type': type,
        'targetAmount': targetAmount,
        'description': description,
        'icon': type == 'savings' ? 'savings' : 'piggy',
        'color': type == 'savings' ? '#4CAF50' : '#FF9800',
      }),
    );

    if (response.statusCode != 201) {
      final error = jsonDecode(response.body)['error'];
      debugPrint('Failed to create account: $error');
      throw Exception(error ?? 'Hesap oluşturma başarısız');
    }
  }
}
