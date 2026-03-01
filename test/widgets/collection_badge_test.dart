import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/common/collection_badge.dart';

void main() {
  group('CollectionBadge', () {
    test('isOwned returns true when normalCount > 0', () {
      const badge = CollectionBadge(normalCount: 3);
      expect(badge.isOwned, true);
      expect(badge.totalCount, 3);
    });

    test('isOwned returns true when foilCount > 0', () {
      const badge = CollectionBadge(foilCount: 2);
      expect(badge.isOwned, true);
      expect(badge.totalCount, 2);
    });

    test('isOwned returns true with both counts', () {
      const badge = CollectionBadge(normalCount: 1, foilCount: 1);
      expect(badge.isOwned, true);
      expect(badge.totalCount, 2);
    });

    test('isOwned returns false when empty', () {
      const badge = CollectionBadge();
      expect(badge.isOwned, false);
      expect(badge.totalCount, 0);
    });

    test('inWishlist defaults to false', () {
      const badge = CollectionBadge();
      expect(badge.inWishlist, false);
    });

    test('inWishlist can be true without ownership', () {
      const badge = CollectionBadge(inWishlist: true);
      expect(badge.isOwned, false);
      expect(badge.inWishlist, true);
    });

    test('combined badge has all properties', () {
      const badge = CollectionBadge(
        normalCount: 2,
        foilCount: 1,
        inWishlist: true,
      );
      expect(badge.isOwned, true);
      expect(badge.totalCount, 3);
      expect(badge.normalCount, 2);
      expect(badge.foilCount, 1);
      expect(badge.inWishlist, true);
    });
  });
}
