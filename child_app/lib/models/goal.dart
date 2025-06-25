class Goal {
  final String id;
  final String name;
  final String description;
  final double targetAmount;
  final double currentAmount;
  final String icon;
  final String color;
  final String category;
  final int priority;
  final bool isVisible;
  final bool isParallel;
  final String status;
  final DateTime? targetDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Goal({
    required this.id,
    required this.name,
    required this.description,
    required this.targetAmount,
    required this.currentAmount,
    required this.icon,
    required this.color,
    required this.category,
    required this.priority,
    required this.isVisible,
    required this.isParallel,
    required this.status,
    this.targetDate,
    required this.createdAt,
    required this.updatedAt,
  });

  // Goal sınıfında name yerine title kullanmak için getter ekleyelim
  String get title => name;

  double get progress => currentAmount / targetAmount;
  double get progressPercentage => (currentAmount / targetAmount) * 100;
  double get remainingAmount => targetAmount - currentAmount;
  bool get isCompleted => status == 'completed';
  bool get isActive => status == 'active';

  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map['_id']?.toString() ?? map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      targetAmount: (map['targetAmount'] ?? 0).toDouble(),
      currentAmount: (map['currentAmount'] ?? 0).toDouble(),
      icon: map['icon'] ?? 'savings',
      color: map['color'] ?? '#2196F3',
      category: map['category'] ?? 'other',
      priority: map['priority'] ?? 1,
      isVisible: map['isVisible'] ?? true,
      isParallel: map['isParallel'] ?? false,
      status: map['status'] ?? 'active',
      targetDate:
          map['targetDate'] != null ? DateTime.parse(map['targetDate']) : null,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'icon': icon,
      'color': color,
      'category': category,
      'priority': priority,
      'isVisible': isVisible,
      'isParallel': isParallel,
      'status': status,
      'targetDate': targetDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Goal copyWith({
    String? name,
    String? description,
    double? targetAmount,
    double? currentAmount,
    String? icon,
    String? color,
    String? category,
    int? priority,
    bool? isVisible,
    bool? isParallel,
    String? status,
    DateTime? targetDate,
  }) {
    return Goal(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      isVisible: isVisible ?? this.isVisible,
      isParallel: isParallel ?? this.isParallel,
      status: status ?? this.status,
      targetDate: targetDate ?? this.targetDate,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class GoalCategory {
  static const String toy = 'toy';
  static const String electronics = 'electronics';
  static const String clothes = 'clothes';
  static const String sport = 'sport';
  static const String education = 'education';
  static const String travel = 'travel';
  static const String other = 'other';

  static const Map<String, String> names = {
    toy: '🧸 Oyuncak',
    electronics: '💻 Elektronik',
    clothes: '👕 Kıyafet',
    sport: '⚽ Spor',
    education: '📚 Eğitim',
    travel: '✈️ Seyahat',
    other: '🎯 Diğer',
  };

  static const Map<String, String> icons = {
    toy: 'toys',
    electronics: 'computer',
    clothes: 'checkroom',
    sport: 'sports_soccer',
    education: 'school',
    travel: 'flight',
    other: 'star',
  };
}
