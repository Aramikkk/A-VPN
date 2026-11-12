import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/profile/data/profile_work.dart';

void main() {
  group('workingProfiles', () {
    test('the top one that is on is the main one, the other ones that are on are added, in the shown order', () {
      final w = workingProfiles(['a', 'b', 'c', 'd'], {'d'});
      expect(w.main, 'a');
      expect(w.extras, ['b', 'c']);
    });

    test('switching the top one off makes the next one the main one', () {
      final w = workingProfiles(['a', 'b', 'c'], {'a'});
      expect(w.main, 'b');
      expect(w.extras, ['c']);
    });

    test('a profile that is off is in neither list', () {
      final w = workingProfiles(['a', 'b', 'c'], {'b'});
      expect(w.extras, ['c']);
      expect(w.extras, isNot(contains('b')));
    });

    test('nothing is on: no main one, no added ones', () {
      final w = workingProfiles(['a', 'b'], {'a', 'b'});
      expect(w.main, isNull);
      expect(w.extras, isEmpty);
    });

    test('no profiles at all', () {
      final w = workingProfiles(const [], const {});
      expect(w.main, isNull);
      expect(w.extras, isEmpty);
    });
  });

  group('canSwitchOff', () {
    test('any one may go while another stays', () {
      expect(canSwitchOff(['a', 'b'], const {}, 'a'), isTrue);
      expect(canSwitchOff(['a', 'b'], const {}, 'b'), isTrue);
    });

    test('the last one that is on may not', () {
      expect(canSwitchOff(['a', 'b'], {'a'}, 'b'), isFalse);
      expect(canSwitchOff(['a'], const {}, 'a'), isFalse);
    });

    test('one that is already off may always be asked about', () {
      expect(canSwitchOff(['a', 'b'], {'a'}, 'a'), isTrue);
    });
  });

  group('offFromOldModel', () {
    test('the active profile and the added ones stay on, every other one is switched off', () {
      final off = offFromOldModel(['wg', 'sigma', 'chill', 'phantom'], activeId: 'sigma', extras: ['chill', 'phantom']);
      expect(off, {'wg'});
    });

    test('nothing active and nothing added: everything stays on rather than leave no profile', () {
      expect(offFromOldModel(['a', 'b'], activeId: null, extras: const []), isEmpty);
    });

    test('an added profile that no longer exists is ignored', () {
      expect(offFromOldModel(['a', 'b'], activeId: 'a', extras: ['gone']), {'b'});
    });
  });

  group('workNeedsSync', () {
    test('nothing to do when the active profile is the main one and the added ones are as they should be', () {
      expect(workNeedsSync(['a', 'b', 'c'], const {}, activeId: 'a', extras: ['b', 'c']), isFalse);
    });
    test('another profile is active than the top one that is on', () {
      expect(workNeedsSync(['a', 'b'], const {}, activeId: 'b', extras: ['a']), isTrue);
    });
    test('the added ones differ', () {
      expect(workNeedsSync(['a', 'b', 'c'], const {}, activeId: 'a', extras: ['b']), isTrue);
      expect(workNeedsSync(['a', 'b'], {'b'}, activeId: 'a', extras: ['b']), isTrue);
    });
    test('the order of the added ones does not matter', () {
      expect(workNeedsSync(['a', 'b', 'c'], const {}, activeId: 'a', extras: ['c', 'b']), isFalse);
    });
    test('all of them off: nothing can be done, so nothing is asked for', () {
      expect(workNeedsSync(['a'], {'a'}, activeId: 'a', extras: const []), isFalse);
    });
  });

  group('orderToPin', () {
    test('no order kept yet: the order shown is kept, so an updated subscription can not rise to the top', () {
      expect(orderToPin(const [], ['sigma', 'chill', 'wg']), ['sigma', 'chill', 'wg']);
    });
    test('every shown profile has its place: nothing to do', () {
      expect(orderToPin(['a', 'b', 'c'], ['a', 'b', 'c']), isNull);
      expect(orderToPin(['b', 'a'], ['b', 'a']), isNull);
    });
    test('a new profile has no place yet: it gets the one it is shown at (the end)', () {
      expect(orderToPin(['a', 'b'], ['a', 'b', 'new']), ['a', 'b', 'new']);
    });
    test('a deleted profile left in the kept order is no reason to write it again', () {
      expect(orderToPin(['a', 'gone', 'b'], ['a', 'b']), isNull);
    });
    test('no profiles: nothing', () {
      expect(orderToPin(const [], const []), isNull);
    });
  });
}
