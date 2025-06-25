import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/goal.dart';
import 'auth_service.dart';

class GoalService {
  static const String _baseUrl = 'http://192.168.1.21:3000/api';
  final AuthService _authService = AuthService();

  // Tüm hedefleri getir
  Future<List<Goal>> getGoals() async {
    debugPrint('Getting goals...');

    try {
      final headers = await _authService.getAuthHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/goals'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final goals = data.map((json) => Goal.fromMap(json)).toList();
        debugPrint('Goals retrieved: ${goals.length}');
        return goals;
      } else {
        final error = jsonDecode(response.body)['error'];
        debugPrint('Failed to get goals: $error');
        throw Exception(error ?? 'Hedefler alınamadı');
      }
    } catch (e) {
      debugPrint('Get goals error: $e');
      throw Exception('Hedefler alınırken bir hata oluştu');
    }
  }

  // Sadece görünür hedefleri getir
  Future<List<Goal>> getVisibleGoals() async {
    debugPrint('Getting visible goals...');

    try {
      final headers = await _authService.getAuthHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/goals/visible'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final goals = data.map((json) => Goal.fromMap(json)).toList();
        debugPrint('Visible goals retrieved: ${goals.length}');
        return goals;
      } else {
        final error = jsonDecode(response.body)['error'];
        debugPrint('Failed to get visible goals: $error');
        throw Exception(error ?? 'Görünür hedefler alınamadı');
      }
    } catch (e) {
      debugPrint('Get visible goals error: $e');
      throw Exception('Görünür hedefler alınırken bir hata oluştu');
    }
  }

  // Paralel hedefleri getir
  Future<List<Goal>> getParallelGoals() async {
    debugPrint('Getting parallel goals...');

    try {
      final headers = await _authService.getAuthHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/goals/parallel'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final goals = data.map((json) => Goal.fromMap(json)).toList();
        debugPrint('Parallel goals retrieved: ${goals.length}');
        return goals;
      } else {
        final error = jsonDecode(response.body)['error'];
        debugPrint('Failed to get parallel goals: $error');
        throw Exception(error ?? 'Paralel hedefler alınamadı');
      }
    } catch (e) {
      debugPrint('Get parallel goals error: $e');
      throw Exception('Paralel hedefler alınırken bir hata oluştu');
    }
  }

  // Yeni hedef oluştur
  Future<Goal> createGoal({
    required String name,
    required String description,
    required double targetAmount,
    required String icon,
    required String color,
    required String category,
    DateTime? targetDate,
    int priority = 1,
    bool isVisible = true,
    bool isParallel = false,
  }) async {
    debugPrint('Creating goal: $name');

    try {
      final headers = await _authService.getAuthHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/goals'),
        headers: headers,
        body: jsonEncode({
          'name': name,
          'description': description,
          'targetAmount': targetAmount,
          'icon': icon,
          'color': color,
          'category': category,
          'targetDate': targetDate?.toIso8601String(),
          'priority': priority,
          'isVisible': isVisible,
          'isParallel': isParallel,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final goal = Goal.fromMap(data);
        debugPrint('Goal created: ${goal.name}');
        return goal;
      } else {
        final error = jsonDecode(response.body)['error'];
        debugPrint('Failed to create goal: $error');
        throw Exception(error ?? 'Hedef oluşturulamadı');
      }
    } catch (e) {
      debugPrint('Create goal error: $e');
      throw Exception('Hedef oluşturulurken bir hata oluştu');
    }
  }

  // Hedef önceliklerini güncelle (sürükle-bırak için)
  Future<List<Goal>> reorderGoals(List<Goal> goals) async {
    debugPrint('Reordering goals...');

    try {
      final headers = await _authService.getAuthHeaders();
      final goalOrders = goals
          .asMap()
          .entries
          .map((entry) => {
                'id': entry.value.id,
                'priority': entry.key + 1,
              })
          .toList();

      final response = await http.put(
        Uri.parse('$_baseUrl/goals/reorder'),
        headers: headers,
        body: jsonEncode({'goalOrders': goalOrders}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final updatedGoals = data.map((json) => Goal.fromMap(json)).toList();
        debugPrint('Goals reordered successfully');
        return updatedGoals;
      } else {
        final error = jsonDecode(response.body)['error'];
        debugPrint('Failed to reorder goals: $error');
        throw Exception(error ?? 'Hedef sıralaması güncellenemedi');
      }
    } catch (e) {
      debugPrint('Reorder goals error: $e');
      throw Exception('Hedef sıralaması güncellenirken bir hata oluştu');
    }
  }

  // Hedefe katkı ekle
  Future<Goal> contributeToGoal(String goalId, double amount) async {
    debugPrint('Contributing $amount to goal $goalId');

    try {
      final headers = await _authService.getAuthHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/goals/$goalId/contribute'),
        headers: headers,
        body: jsonEncode({'amount': amount}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final goal = Goal.fromMap(data);
        debugPrint('Contribution successful');
        return goal;
      } else {
        final error = jsonDecode(response.body)['error'];
        debugPrint('Failed to contribute: $error');
        throw Exception(error ?? 'Katkı eklenemedi');
      }
    } catch (e) {
      debugPrint('Contribute error: $e');
      throw Exception('Katkı eklenirken bir hata oluştu');
    }
  }

  // Paralel hedef dağıtımı
  Future<Map<String, dynamic>> distributeToParallelGoals(double amount) async {
    debugPrint('Distributing $amount to parallel goals');

    try {
      final headers = await _authService.getAuthHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/goals/distribute'),
        headers: headers,
        body: jsonEncode({'amount': amount}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint(
            'Distribution successful: ${data['totalDistributed']} distributed');
        return data;
      } else {
        final error = jsonDecode(response.body)['error'];
        debugPrint('Failed to distribute: $error');
        throw Exception(error ?? 'Dağıtım yapılamadı');
      }
    } catch (e) {
      debugPrint('Distribution error: $e');
      throw Exception('Dağıtım yapılırken bir hata oluştu');
    }
  }

  // Hedef durumunu güncelle
  Future<Goal> updateGoalStatus(String goalId, String status) async {
    debugPrint('Updating goal $goalId status to $status');

    try {
      final headers = await _authService.getAuthHeaders();
      final response = await http.patch(
        Uri.parse('$_baseUrl/goals/$goalId/status'),
        headers: headers,
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final goal = Goal.fromMap(data);
        debugPrint('Goal status updated');
        return goal;
      } else {
        final error = jsonDecode(response.body)['error'];
        debugPrint('Failed to update status: $error');
        throw Exception(error ?? 'Durum güncellenemedi');
      }
    } catch (e) {
      debugPrint('Update status error: $e');
      throw Exception('Durum güncellenirken bir hata oluştu');
    }
  }

  // Hedef detaylarını getir
  Future<Goal> getGoalDetails(String goalId) async {
    debugPrint('Getting goal details: $goalId');

    try {
      final headers = await _authService.getAuthHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/goals/$goalId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final goal = Goal.fromMap(data);
        debugPrint('Goal details retrieved');
        return goal;
      } else {
        final error = jsonDecode(response.body)['error'];
        debugPrint('Failed to get goal details: $error');
        throw Exception(error ?? 'Hedef detayları alınamadı');
      }
    } catch (e) {
      debugPrint('Get goal details error: $e');
      throw Exception('Hedef detayları alınırken bir hata oluştu');
    }
  }
}
