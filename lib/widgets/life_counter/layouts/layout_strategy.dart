enum LayoutType { faceToFace, grid, focus }

class LayoutResolver {
  const LayoutResolver._();
  static LayoutType resolve(int playerCount, {LayoutType? preference}) {
    if (playerCount <= 2) return LayoutType.faceToFace;
    if (preference != null) return preference;
    if (playerCount <= 4) return LayoutType.grid;
    return LayoutType.focus;
  }
}

class GridLayoutConfig {
  final int columns;
  final int topRowCount;
  final int bottomRowCount;
  final bool bottomRowFullWidth;

  const GridLayoutConfig({
    required this.columns,
    required this.topRowCount,
    required this.bottomRowCount,
    required this.bottomRowFullWidth,
  });

  factory GridLayoutConfig.forPlayerCount(int count) {
    if (count == 3) {
      return const GridLayoutConfig(
        columns: 2,
        topRowCount: 2,
        bottomRowCount: 1,
        bottomRowFullWidth: true,
      );
    }
    return const GridLayoutConfig(
      columns: 2,
      topRowCount: 2,
      bottomRowCount: 2,
      bottomRowFullWidth: false,
    );
  }
}

class FocusLayoutConfig {
  final int adversaryCount;
  final double ownerHeightRatio;

  const FocusLayoutConfig({
    required this.adversaryCount,
    required this.ownerHeightRatio,
  });

  factory FocusLayoutConfig.forPlayerCount(int count) {
    return FocusLayoutConfig(
      adversaryCount: count - 1,
      ownerHeightRatio: 0.4,
    );
  }
}
