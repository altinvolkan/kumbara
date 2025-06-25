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

  // Tamamlanan hedefleri getir
  Future<List<Goal>> getCompletedGoals() async {
    debugPrint('Getting completed goals...');

    try {
      final headers = await _authService.getAuthHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/goals/completed'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final goals = data.map((json) => Goal.fromMap(json)).toList();
        debugPrint('Completed goals retrieved: ${goals.length}');
        return goals;
      } else {
        final error = jsonDecode(response.body)['error'];
        debugPrint('Failed to get completed goals: $error');
        throw Exception(error ?? 'Tamamlanan hedefler alınamadı');
      }
    } catch (e) {
      debugPrint('Get completed goals error: $e');
      throw Exception('Tamamlanan hedefler alınırken bir hata oluştu');
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
      debugPrint('Contribution error: $e');
      throw Exception('Katkı eklenirken bir hata oluştu');
    }
  }

  // Paralel hedeflere para dağıt
  Future<List<Goal>> distributeToParallelGoals(double amount) async {
    debugPrint('Distributing $amount to parallel goals...');

    try {
      final headers = await _authService.getAuthHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/goals/distribute'),
        headers: headers,
        body: jsonEncode({'amount': amount}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final goals = data.map((json) => Goal.fromMap(json)).toList();
        debugPrint('Distribution successful');
        return goals;
      } else {
        final error = jsonDecode(response.body)['error'];
        debugPrint('Failed to distribute: $error');
        throw Exception(error ?? 'Para dağıtılamadı');
      }
    } catch (e) {
      debugPrint('Distribution error: $e');
      throw Exception('Para dağıtılırken bir hata oluştu');
    }
  }

  // Hedefi güncelle
  Future<Goal> updateGoal(
    String goalId, {
    String? name,
    String? description,
    double? targetAmount,
    String? icon,
    String? color,
    String? category,
    DateTime? targetDate,
    int? priority,
    bool? isVisible,
    bool? isParallel,
    String? status,
  }) async {
    debugPrint('Updating goal: $goalId');

    try {
      final headers = await _authService.getAuthHeaders();
      final Map<String, dynamic> updates = {};

      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (targetAmount != null) updates['targetAmount'] = targetAmount;
      if (icon != null) updates['icon'] = icon;
      if (color != null) updates['color'] = color;
      if (category != null) updates['category'] = category;
      if (targetDate != null)
        updates['targetDate'] = targetDate.toIso8601String();
      if (priority != null) updates['priority'] = priority;
      if (isVisible != null) updates['isVisible'] = isVisible;
      if (isParallel != null) updates['isParallel'] = isParallel;
      if (status != null) updates['status'] = status;

      final response = await http.patch(
        Uri.parse('$_baseUrl/goals/$goalId'),
        headers: headers,
        body: jsonEncode(updates),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final goal = Goal.fromMap(data);
        debugPrint('Goal updated: ${goal.name}');
        return goal;
      } else {
        final error = jsonDecode(response.body)['error'];
        debugPrint('Failed to update goal: $error');
        throw Exception(error ?? 'Hedef güncellenemedi');
      }
    } catch (e) {
      debugPrint('Update goal error: $e');
      throw Exception('Hedef güncellenirken bir hata oluştu');
    }
  }

  // Hedefi sil
  Future<void> deleteGoal(String goalId) async {
    debugPrint('Deleting goal: $goalId');

    try {
      final headers = await _authService.getAuthHeaders();
      debugPrint('Auth headers: $headers');
      debugPrint('API URL: $_baseUrl/goals/$goalId');

      final response = await http.delete(
        Uri.parse('$_baseUrl/goals/$goalId'),
        headers: headers,
      );

      debugPrint('Delete response status: ${response.statusCode}');
      debugPrint('Delete response body: ${response.body}');

      if (response.statusCode == 200) {
        debugPrint('Goal deleted successfully');
      } else {
        debugPrint('Delete failed with status: ${response.statusCode}');
        try {
          final error = jsonDecode(response.body)['error'];
          debugPrint('Delete error: $error');
          throw Exception(error ?? 'Hedef silinemedi');
        } catch (jsonError) {
          debugPrint('JSON decode error: $jsonError');
          debugPrint('Response body was: ${response.body}');
          throw Exception('Hedef silme isteği başarısız oldu');
        }
      }
    } catch (e) {
      debugPrint('Delete goal error: $e');
      throw Exception('Hedef silinirken bir hata oluştu');
    }
  }
}
