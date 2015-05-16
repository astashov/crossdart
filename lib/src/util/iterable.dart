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