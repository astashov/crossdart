library crossdart.utils;

/**
 * Combines the hash codes for a list of objects.
 *
 * Useful when computing the hash codes based on the properties of a custom class.
 *
 * For example:
 *
 *     class Person {
 *       String firstName;
 *       String lastName;
 *
 *       int get hashCode => hash([firstName, lastName]);
 *     }
 */
int hash(Iterable<Object> objects) {
  // 31 seems to be the defacto number when generating hash codes. It's also used in WebUI.
  //
  // See:
  // - http://stackoverflow.com/questions/299304/why-does-javas-hashcode-in-string-use-31-as-a-multiplier
  // - http://stackoverflow.com/questions/1835976/what-is-a-sensible-prime-for-hashcode-calculation
  // - https://github.com/dart-lang/web-ui/blob/022d3312c4f84c57732bd3fbff1627cae4014b60/lib/src/utils_observe.dart#L11
  return objects.fold(0, (prev, curr) => (prev * 31) + curr.hashCode);
}