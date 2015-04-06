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