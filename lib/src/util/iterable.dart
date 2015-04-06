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