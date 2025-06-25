class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? avatar;
  final int level;
  final int xp;
  final int nextLevelXp;
  final UserSettings settings;
  final DateTime createdAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatar,
    required this.level,
    required this.xp,
    required this.nextLevelXp,
    required this.settings,
    required this.createdAt,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['_id']?.toString() ?? map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'child',
      avatar: map['avatar'],
      level: map['level'] ?? 1,
      xp: map['xp'] ?? 0,
      nextLevelXp: map['nextLevelXp'] ?? 1000,
      settings: UserSettings.fromMap(map['settings'] ?? {}),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'avatar': avatar,
      'level': level,
      'xp': xp,
      'nextLevelXp': nextLevelXp,
      'settings': settings.toMap(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  double get levelProgress => xp / nextLevelXp;

  @override
  String toString() {
    return 'User(id: $id, name: $name, email: $email, createdAt: $createdAt)';
  }
}

class UserSettings {
  final bool notifications;
  final bool soundEffects;
  final bool vibration;
  final bool darkMode;

  UserSettings({
    required this.notifications,
    required this.soundEffects,
    required this.vibration,
    required this.darkMode,
  });

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      notifications: map['notifications'] ?? true,
      soundEffects: map['soundEffects'] ?? true,
      vibration: map['vibration'] ?? true,
      darkMode: map['darkMode'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notifications': notifications,
      'soundEffects': soundEffects,
      'vibration': vibration,
      'darkMode': darkMode,
    };
  }

  UserSettings copyWith({
    bool? notifications,
    bool? soundEffects,
    bool? vibration,
    bool? darkMode,
  }) {
    return UserSettings(
      notifications: notifications ?? this.notifications,
      soundEffects: soundEffects ?? this.soundEffects,
      vibration: vibration ?? this.vibration,
      darkMode: darkMode ?? this.darkMode,
    );
  }
}
