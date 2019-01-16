library index_cursor_test;

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/sembast/sembast_cursor.dart';
import 'package:sembast/sembast.dart' as sdb;

import 'idb_test_common.dart';

void main() {
  group('sembast_common', () {
    test('keyRangeFilter', () {
      var filter = keyRangeFilter('test', KeyRange.lowerBound(1));
      expect(filter.match(sdb.Record(null, {'test': 1})), isTrue);
      expect(filter.match(sdb.Record(null, {'test': 2})), isTrue);
      expect(filter.match(sdb.Record(null, {'name': 0})), isFalse);
    });
    test('keyFilter', () {
      var filter = keyFilter('name', null);
      expect(filter.match(sdb.Record(null, {'dummy_empty': 1})), isFalse);
      expect(filter.match(sdb.Record(null, {'name': null})), isFalse);
      expect(filter.match(sdb.Record(null, {'name': 1})), isTrue);
      // keyRangeFilter(['year', 'name'], KeyRange.lowerBound([2018, 'John']));
    });
    test('keyArrayFilter', () {
      var filter = keyFilter(['year', 'name'], null);
      expect(filter.match(sdb.Record(null, {'dummy_empty': 1})), isFalse);
      expect(filter.match(sdb.Record(null, {'name': null})), isFalse);
      expect(filter.match(sdb.Record(null, {'name': 1})), isFalse);
      expect(filter.match(sdb.Record(null, {'name': 1, 'year': 1})), isTrue);
      expect(
          filter.match(sdb.Record(null, {'name': null, 'year': 1})), isFalse);
      // keyRangeFilter(['year', 'name'], KeyRange.lowerBound([2018, 'John']));
    });
    test('keyArrayRangeFilter', () {
      var filter =
          keyRangeFilter(['year', 'name'], KeyRange.lowerBound([2018, 'John']));
      expect(filter.match(sdb.Record(null, {'year': 2019, 'name': 'Jack'})),
          isTrue);
      expect(filter.match(sdb.Record(null, {'year': 2018, 'name': 'John'})),
          isTrue);
      expect(filter.match(sdb.Record(null, {'year': 2018, 'name': 'Jack'})),
          isFalse);
      expect(filter.match(sdb.Record(null, {'year': 2018, 'name': 'Robert'})),
          isTrue);
      expect(filter.match(sdb.Record(null, {'year': 2017, 'name': 'Robert'})),
          isFalse);

      expect(filter.match(sdb.Record(null, {'name': 1})), isFalse);
      expect(filter.match(sdb.Record(null, {'year': 2018})), isFalse);
      expect(filter.match(sdb.Record(null, {'year': 2019})), isFalse);

      filter = keyRangeFilter(
          ['year', 'name'], KeyRange.lowerBound([2018, 'John'], true));
      expect(filter.match(sdb.Record(null, {'year': 2019, 'name': 'Jack'})),
          isTrue);
      expect(filter.match(sdb.Record(null, {'year': 2018, 'name': 'JohnX'})),
          isTrue);
      expect(filter.match(sdb.Record(null, {'year': 2018, 'name': 'John'})),
          isFalse);

      filter = keyRangeFilter(
          ['year', 'name'], KeyRange.upperBound([2018, 'John'], true));
      expect(filter.match(sdb.Record(null, {'year': 2019, 'name': 'Jack'})),
          isFalse);
      expect(filter.match(sdb.Record(null, {'year': 2017, 'name': 'Jack'})),
          isTrue);
      expect(filter.match(sdb.Record(null, {'year': 2018, 'name': 'Joha'})),
          isTrue);
      expect(filter.match(sdb.Record(null, {'year': 2018, 'name': 'John'})),
          isFalse);
    });
  });
}
