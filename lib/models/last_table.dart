// lib/models/last_table.dart
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/player_config.dart';

/// Snapshot of the last table configured on the setup screen, saved so it
/// can be replayed in one tap the next time the app starts.
class LastTable {
  final GameFormat format;
  final List<PlayerConfig> playerConfigs;
  final bool timerEnabled;

  const LastTable({
    required this.format,
    required this.playerConfigs,
    required this.timerEnabled,
  });

  Map<String, dynamic> toJson() => {
        'format': format.toJson(),
        'playerConfigs': playerConfigs.map((p) => p.toJson()).toList(),
        'timerEnabled': timerEnabled,
      };

  factory LastTable.fromJson(Map<String, dynamic> json) => LastTable(
        format: GameFormat.fromJson(json['format'] as Map<String, dynamic>),
        playerConfigs: (json['playerConfigs'] as List)
            .map((p) => PlayerConfig.fromJson(p as Map<String, dynamic>))
            .toList(),
        timerEnabled: json['timerEnabled'] as bool,
      );
}
