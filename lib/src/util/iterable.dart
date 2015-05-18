library crossdart.utils.iterable;

Map groupByOne(Iterable collection, bool condition(i)) {
  return collection.fold({}, (memo, item) {
    memo[condition(item)] = item;
    return memo;
  });
}

Map groupBy(Iterable collection, bool condition(i)) {
  return collection.fold({}, (memo, item) {
    var key = condition(item);
    if (memo[key] == null) {
      memo[key] = [];
    }
    memo[key].add(item);
    return memo;
  });
}

Iterable<Iterable> inGroupsOf(Iterable collection, int number) {
  if (collection.isEmpty) {
    return [];
  } else {
    var result = [[]];
    for (var item in collection) {
      List lastColl = result.last;
      if (lastColl.length >= number) {
        lastColl = [];
        result.add(lastColl);
      }
      lastColl.add(item);
    }
    return result;
  }
}

Iterable<Iterable> inGroups(Iterable collection, int number, [fillWith = null]) {
  var coll = collection.toList();
  var division = collection.length ~/ number;
  var modulo = collection.length % number;

  var groups = [];
  var start = 0;

  for (int index = 0; index < number; index += 1) {
    var length = division + (modulo > 0 && modulo > index ? 1 : 0);
    var lastGroup = coll.getRange(start, start + length);
    groups.add(lastGroup);
    if (fillWith != null && modulo > 0 && length == division) {
      lastGroup.add(fillWith);
    }
    start += length;
  }

  return groups;
}