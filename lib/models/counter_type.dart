class CounterType {
  final String id;
  final String name;
  final String emoji;
  final int color; // ARGB int
  final bool isBuiltIn;
  final int? maxValue; // null = unlimited

  const CounterType({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    this.isBuiltIn = false,
    this.maxValue,
  });

  CounterType copyWith({
    String? id,
    String? name,
    String? emoji,
    int? color,
    bool? isBuiltIn,
    int? maxValue,
  }) {
    return CounterType(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      maxValue: maxValue ?? this.maxValue,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'color': color,
        'isBuiltIn': isBuiltIn,
        'maxValue': maxValue,
      };

  factory CounterType.fromJson(Map<String, dynamic> json) => CounterType(
        id: json['id'] as String,
        name: json['name'] as String,
        emoji: json['emoji'] as String,
        color: json['color'] as int,
        isBuiltIn: json['isBuiltIn'] as bool? ?? false,
        maxValue: json['maxValue'] as int?,
      );

  static const List<CounterType> builtInCounters = [
    CounterType(
      id: 'poison',
      name: 'Poison',
      emoji: '☠️',
      color: 0xFF4CAF50,
      isBuiltIn: true,
      maxValue: 10,
    ),
    CounterType(
      id: 'energy',
      name: 'Energy',
      emoji: '⚡',
      color: 0xFFFF9800,
      isBuiltIn: true,
    ),
    CounterType(
      id: 'commander_tax',
      name: 'Commander Tax',
      emoji: '💰',
      color: 0xFFFFEB3B,
      isBuiltIn: true,
    ),
    CounterType(
      id: 'commander_damage',
      name: 'Commander Damage',
      emoji: '⚔️',
      color: 0xFFF44336,
      isBuiltIn: true,
    ),
  ];
}
