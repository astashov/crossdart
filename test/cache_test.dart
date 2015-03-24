library crossdart.test.cache;

import 'package:unittest/unittest.dart';
import 'package:crossdart/src/cache.dart';

void main() => group("Cache", () {
  setUp(() {

  });

  test("lineNumber()", () {
    print(cache.lineNumber("test/cache_test.dart", 31));
  });
});