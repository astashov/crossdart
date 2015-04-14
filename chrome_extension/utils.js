function groupBy(coll, context) {
  return coll.reduce(function (memo, item) {
    var value = context(item);
    if (memo[value] === undefined) {
      memo[value] = [];
    }
    memo[value].push(item);
    return memo;
  }, {});
}
