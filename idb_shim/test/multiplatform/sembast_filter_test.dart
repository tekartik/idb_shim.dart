library;

import 'package:idb_shim/src/sembast/sembast_filter.dart' as sembast_filter;
import 'package:sembast/sembast.dart' as sdb;
import 'package:sembast/src/filter_impl.dart' as sdb;
import 'package:sembast/src/record_snapshot_impl.dart' as sdb;

import '../idb_test_common.dart';

var _record = sdb.StoreRef<int, Object>.main().record(1);

sdb.Filter keyRangeFilter(
  dynamic keyPath,
  KeyRange range, [
  bool multiEntry = false,
]) => sembast_filter.keyRangeFilter(keyPath, range, multiEntry);

/// key can be null
sdb.Filter keyFilter(dynamic keyPath, Object? key, [bool multiEntry = false]) =>
    sembast_filter.keyFilter(keyPath, key, multiEntry);

bool _fieldMatch(sdb.Filter filter, Object value) {
  return sdb.filterMatchesRecord(
    filter,
    sdb.SembastRecordSnapshot(_record, value),
  );
}

void main() {
  group('sembast_common', () {
    test('keyRangeFilter_lower', () {
      var filter = keyRangeFilter('test', KeyRange.lowerBound(1));
      expect(_fieldMatch(filter, {'test': 1}), isTrue);
      expect(_fieldMatch(filter, {'test': 2}), isTrue);
      expect(_fieldMatch(filter, {'name': 0}), isFalse);
      filter = keyRangeFilter('test', KeyRange.lowerBound(1, true));
      expect(_fieldMatch(filter, {'test': 1}), isFalse);
      expect(_fieldMatch(filter, {'test': 2}), isTrue);
    });
    test('keyRangeFilter_upper', () {
      var filter = keyRangeFilter('test', KeyRange.upperBound(2));

      expect(_fieldMatch(filter, {'test': 2}), isTrue);
      expect(_fieldMatch(filter, {'test': 3}), isFalse);

      filter = keyRangeFilter('test', KeyRange.upperBound(2, true));
      expect(_fieldMatch(filter, {'test': 1}), isTrue);
      expect(_fieldMatch(filter, {'test': 2}), isFalse);
    });
    test('keyFilterNull', () {
      var filter = keyFilter('name', null);
      expect(_fieldMatch(filter, {'dummy_empty': 1}), isFalse);
      expect(_fieldMatch(filter, {'name': null}), isFalse);
      expect(_fieldMatch(filter, {'name': 1}), isTrue);
    });
    test('keyFilterValue', () {
      var filter = keyFilter('name', 1);
      expect(_fieldMatch(filter, {'dummy_empty': 1}), isFalse);
      expect(_fieldMatch(filter, {'name': null}), isFalse);
      expect(_fieldMatch(filter, {'name': 1}), isTrue);
      expect(_fieldMatch(filter, {'name': 2}), isFalse);
    });
    test('keyFilterDotNull', () {
      var filter = keyFilter('my.name', null);
      expect(
        _fieldMatch(filter, {
          'my': {'name': null},
        }),
        isFalse,
      );
      expect(
        _fieldMatch(filter, {
          'my': {'name': 1},
        }),
        isTrue,
      );
      expect(_fieldMatch(filter, {'dummy_empty': 1}), isFalse);
      expect(_fieldMatch(filter, {'my.name': null}), isFalse);
      expect(_fieldMatch(filter, {'my.name': 1}), isFalse);
    });
    test('keyFilterDotValue', () {
      var filter = keyFilter('my.name', 1);
      expect(
        _fieldMatch(filter, {
          'my': {'name': 1},
        }),
        isTrue,
      );
      expect(
        _fieldMatch(filter, {
          'my': {'name': 2},
        }),
        isFalse,
      );
      expect(_fieldMatch(filter, {'dummy_empty': 1}), isFalse);
      expect(_fieldMatch(filter, {'my.name': null}), isFalse);
      expect(_fieldMatch(filter, {'my.name': 1}), isFalse);
    });
    test('keyArrayFilter', () {
      var filter = keyFilter(['year', 'name'], null);
      expect(_fieldMatch(filter, {'dummy_empty': 1}), isFalse);
      expect(_fieldMatch(filter, {'name': null}), isFalse);
      expect(_fieldMatch(filter, {'name': 1}), isFalse);
      expect(_fieldMatch(filter, {'name': 1, 'year': 1}), isTrue);
      expect(_fieldMatch(filter, {'name': null, 'year': 1}), isFalse);
      // keyRangeFilter(['year', 'name'], KeyRange.lowerBound([2018, 'John']));
    });
    test('keyArrayRangeDottedFilter', () {
      var filter = keyRangeFilter('my.year', KeyRange.lowerBound(2018));
      expect(
        _fieldMatch(filter, {
          'my': {'year': 2018},
        }),
        isTrue,
      );
      expect(
        _fieldMatch(filter, {
          'my': {'year': 2019},
        }),
        isTrue,
      );
      expect(
        _fieldMatch(filter, {
          'my': {'year': 2017},
        }),
        isFalse,
      );
    });

    test('keyArrayRangeFilter', () {
      var filter = keyRangeFilter([
        'year',
        'name',
      ], KeyRange.lowerBound([2018, 'John']));
      expect(_fieldMatch(filter, {'year': 2019, 'name': 'Jack'}), isTrue);
      expect(_fieldMatch(filter, {'year': 2018, 'name': 'John'}), isTrue);
      expect(_fieldMatch(filter, {'year': 2018, 'name': 'Jack'}), isFalse);
      expect(_fieldMatch(filter, {'year': 2018, 'name': 'Robert'}), isTrue);
      expect(_fieldMatch(filter, {'year': 2017, 'name': 'Robert'}), isFalse);

      expect(_fieldMatch(filter, {'name': 1}), isFalse);
      expect(_fieldMatch(filter, {'year': 2018}), isFalse);
      expect(_fieldMatch(filter, {'year': 2019}), isFalse);

      filter = keyRangeFilter([
        'year',
        'name',
      ], KeyRange.lowerBound([2018, 'John'], true));
      expect(_fieldMatch(filter, {'year': 2019, 'name': 'Jack'}), isTrue);
      expect(_fieldMatch(filter, {'year': 2018, 'name': 'JohnX'}), isTrue);
      expect(_fieldMatch(filter, {'year': 2018, 'name': 'John'}), isFalse);

      filter = keyRangeFilter([
        'year',
        'name',
      ], KeyRange.upperBound([2018, 'John'], true));
      expect(_fieldMatch(filter, {'year': 2019, 'name': 'Jack'}), isFalse);
      expect(_fieldMatch(filter, {'year': 2017, 'name': 'Jack'}), isTrue);
      expect(_fieldMatch(filter, {'year': 2018, 'name': 'Joha'}), isTrue);
      expect(_fieldMatch(filter, {'year': 2018, 'name': 'John'}), isFalse);
    });

    group('multiEntry', () {
      test('keyFilterValue', () {
        var filter = keyFilter('value', 1, true);
        expect(_fieldMatch(filter, {'value': 1}), isTrue);
        expect(
          _fieldMatch(filter, {
            'value': [1, 2],
          }),
          isTrue,
        );
        expect(_fieldMatch(filter, {'value': null}), isFalse);
        expect(_fieldMatch(filter, {'value': 3}), isFalse);
        expect(_fieldMatch(filter, 1), isFalse);
        expect(_fieldMatch(filter, {'name': 'dummy'}), isFalse);
      });

      test('keyFilterNull', () {
        var filter = keyFilter('value', null, true);
        expect(_fieldMatch(filter, {'value': 1}), isTrue);
        expect(
          _fieldMatch(filter, {
            'value': [1, 2],
          }),
          isTrue,
        );
        expect(_fieldMatch(filter, {'value': <int>[]}), isFalse);
        expect(_fieldMatch(filter, {'value': null}), isFalse);
        expect(_fieldMatch(filter, {'value': 3}), isTrue);
        expect(_fieldMatch(filter, 1), isFalse);
        expect(_fieldMatch(filter, {'name': 'dummy'}), isFalse);
      });

      test('keyFilterRange', () {
        var filter = keyRangeFilter('value', KeyRange.lowerBound(2), true);

        expect(
          _fieldMatch(filter, {
            'value': [1, 2],
          }),
          isTrue,
        );
        expect(_fieldMatch(filter, {'value': 1}), isFalse);
        expect(_fieldMatch(filter, {'value': 2}), isTrue);
        expect(
          _fieldMatch(filter, {
            'value': [0, 1],
          }),
          isFalse,
        );
        expect(_fieldMatch(filter, {'value': null}), isFalse);
        expect(_fieldMatch(filter, {'value': 3}), isTrue);
        expect(_fieldMatch(filter, 1), isFalse);
        expect(_fieldMatch(filter, {'name': 'dummy'}), isFalse);

        filter = keyRangeFilter('value', KeyRange.lowerBound(2, false), true);
        expect(
          _fieldMatch(filter, {
            'value': [1, 2],
          }),
          isTrue,
        );

        filter = keyRangeFilter('value', KeyRange.lowerBound(2, true), true);
        expect(
          _fieldMatch(filter, {
            'value': [1, 2],
          }),
          isFalse,
        );
        expect(
          _fieldMatch(filter, {
            'value': [1, 3],
          }),
          isTrue,
        );
      });

      test('keyArrayRangeFilter', () {
        var filter = keyRangeFilter(
          ['year', 'name'],
          KeyRange.lowerBound([2018, 'John']),
          true,
        );
        expect(
          _fieldMatch(filter, {
            'year': [2019],
            'name': 'Jack',
          }),
          isTrue,
        );
        expect(
          _fieldMatch(filter, {
            'year': [2018, 2016],
            'name': 'John',
          }),
          isTrue,
        );
        expect(
          _fieldMatch(filter, {
            'year': [2017, 2016],
            'name': 'Jack',
          }),
          isFalse,
        );

        filter = keyRangeFilter(
          ['year', 'name'],
          KeyRange.upperBound([2018, 'John']),
          true,
        );
        expect(
          _fieldMatch(filter, {
            'year': [2018],
            'name': 'Jack',
          }),
          isTrue,
        );
        expect(
          _fieldMatch(filter, {
            'year': [2018, 2019],
            'name': 'John',
          }),
          isFalse,
        );
        expect(
          _fieldMatch(filter, {
            'year': [2019],
            'name': 'John',
          }),
          isFalse,
        );
        expect(
          _fieldMatch(filter, {
            'year': [2018],
            'name': 'JohnX',
          }),
          isFalse,
        );
      });
    });
  });
}
