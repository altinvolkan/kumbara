import 'package:flutter/foundation.dart';

class User {
  final String? id;
  final String name;
  final String email;
  final String? password;
  final DateTime? createdAt;
  final String? role;
  final Map<String, dynamic>? settings;

  User({
    this.id,
    required this.name,
    required this.email,
    this.password,
    this.createdAt,
    this.role,
    this.settings,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password': password,
      'created_at': createdAt?.toIso8601String(),
      'role': role,
      'settings': settings,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    debugPrint('Creating user from map: $map');
    final id = map['_id'] ?? map['id'];
    debugPrint('User ID: $id (${id.runtimeType})');

    return User(
      id: id?.toString(),
      name: map['name'] as String,
      email: map['email'] as String,
      password: map['password'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : map['createdAt'] != null
              ? DateTime.parse(map['createdAt'] as String)
              : null,
      role: map['role'] as String?,
      settings: map['settings'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, name: $name, email: $email, role: $role)';
  }
}
