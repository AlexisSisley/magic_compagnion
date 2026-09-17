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

  /// Lot 5, tâche 4 (AJOUT 2) : égalité de valeur fondée sur `id` seul.
  /// `CounterCatalogNotifier.load()` (counter_catalog_provider.dart)
  /// reconstruit des instances fraîches (`CounterType.fromJson`) à chaque
  /// appel -- sans cette égalité, deux `CounterType` désignant le même
  /// compteur étaient des objets distincts (identité par défaut), un piège
  /// pour tout code les comparant par `==` ou les rangeant dans un
  /// `Set`/comme clé de `Map`. Fondée sur `id` seul (pas les autres champs) :
  /// c'est `id` qui identifie un compteur dans tout le reste du modèle
  /// (`GameSession.activeCounterIds`, `PlayerState.counters`,
  /// `CounterTypeService`, ...), jamais la combinaison de ses champs.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is CounterType && other.id == id);

  @override
  int get hashCode => id.hashCode;

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
      // Nom affiché seulement -- l'id ne bouge pas : il est écrit tel quel
      // dans les snapshots de partie (GameSession.activeCounterIds,
      // PlayerState.counters) et dans enabledCounterIds des presets de
      // format (game_format.dart). Le renommer casserait la relecture des
      // parties déjà sauvegardées.
      name: 'Énergie',
      emoji: '⚡',
      color: 0xFFFF9800,
      isBuiltIn: true,
    ),
    CounterType(
      id: 'commander_tax',
      name: 'Taxe de commandant',
      emoji: '💰',
      color: 0xFFFFEB3B,
      isBuiltIn: true,
    ),
    CounterType(
      id: 'commander_damage',
      name: 'Dégâts de commandant',
      emoji: '⚔️',
      color: 0xFFF44336,
      isBuiltIn: true,
    ),
  ];
}
