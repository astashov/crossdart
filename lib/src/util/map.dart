library crossdart.util.map;

Map map(Map map, List callback(key, value)) {
  var newMap = {};
  map.forEach((k, v) {
    var newKeyValue = callback(k, v);
    newMap[newKeyValue[0]] = newKeyValue[1];
  });
  return newMap;
}

fold(initialValue, Map map, callback(memo, key, value)) {
  var memo = initialValue;
  map.forEach((k, v) {
    memo = callback(memo, k, v);
  });
  return memo;
}

key(Map map, value) {
  var key;
  map.forEach((k, v) {
    if (v == value) {
      key = k;
    }
  });
  return key;
}

/// Merges the keys and values in [other] with [map]. If [depth] is specified, then
/// merging will happen recursively for nested maps until [depth] is reached. If
/// [deep] is `true`, then merging will recurse infinitely.
Map merge(Map map, Map other, {int depth: 0, bool deep: false}) {
  depth = deep ? double.MAX_FINITE.toInt() : depth;

  var result = new Map.from(map);
  other.forEach((key, value) {
    if (depth > 0 && map[key] is Map && value is Map) {
      value = merge(map[key], value, depth: depth - 1);
    }
    result[key] = value;
  });
  return result;
}