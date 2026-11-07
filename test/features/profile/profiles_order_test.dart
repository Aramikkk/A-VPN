import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/profile/overview/profiles_notifier.dart';

void main() {
  group('movedOrder (ReorderableListView indexes: the target counts the item still in its old place)', () {
    test('a card dragged down', () {
      expect(ProfilesNotifier.movedOrder(['a', 'b', 'c', 'd'], 0, 3), equals(['b', 'c', 'a', 'd']));
      expect(ProfilesNotifier.movedOrder(['a', 'b', 'c', 'd'], 0, 4), equals(['b', 'c', 'd', 'a']));
    });

    test('a card dragged up', () {
      expect(ProfilesNotifier.movedOrder(['a', 'b', 'c', 'd'], 3, 0), equals(['d', 'a', 'b', 'c']));
      expect(ProfilesNotifier.movedOrder(['a', 'b', 'c', 'd'], 2, 1), equals(['a', 'c', 'b', 'd']));
    });
  });

  group('orderByIds', () {
    String id(String s) => s;

    test('an empty order leaves the list as it is', () {
      expect(orderByIds(['x', 'y'], id, const []), equals(['x', 'y']));
    });

    test('the named ones come first in the named order, the others after them as they came', () {
      expect(orderByIds(['a', 'b', 'c', 'd'], id, ['c', 'a']), equals(['c', 'a', 'b', 'd']));
    });

    test('ids of removed profiles in the order are ignored', () {
      expect(orderByIds(['a', 'b'], id, ['gone', 'b', 'a']), equals(['b', 'a']));
    });
  });
}
