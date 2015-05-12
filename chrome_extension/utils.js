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

function getRealOffset(content, offset) {
  var regexps = [[/(<[^>]*>)/g, 0], [/(&\w+;)/g, 1]];
  var positions = regexps.reduce(function (memo, item) {
    var regexp = item[0];
    var regexpLength = item[1];
    var matches = content.match(regexp);
    var matchPos = 0;
    for (var matchIndex in (matches || [])) {
      if (matches.hasOwnProperty(matchIndex)) {
        var match = matches[matchIndex];
        var matchOffset = content.substr(matchPos).search(regexp);
        memo.push([matchPos + matchOffset, matchPos + matchOffset + match.length, regexpLength]);
        matchPos += matchOffset + match.length;
      }
    }
    return memo;
  }, []).sort(function (a, b) { return a[0] - b[0]; });
  var realOffset = offset;
  while (positions.length > 0 && realOffset > positions[0][0]) {
    var position = positions.shift();
    var length = position[1] - position[0] - position[2];
    realOffset += length;
  }
  return realOffset;
}

function applyReferences(github, ref, content, references) {
  if (content.indexOf("crossdart-link") === -1) {
    var newLineContent = "";
    var lastStop = 0;
    for (var index in references) {
      var reference = references[index];
      var realOffset = getRealOffset(content, reference.offset);
      newLineContent += content.substr(lastStop, realOffset - lastStop);
      var href = new TreePath(github, ref, reference.remotePath).absolutePath();
      newLineContent += "<a href='" + href + "' class='crossdart-link'>";
      var end = reference.offset + reference.length;
      realOffset = getRealOffset(content, reference.offset);
      var realEnd = getRealOffset(content, end);
      newLineContent += content.substr(realOffset, realEnd - realOffset);
      newLineContent += "</a>";
      lastStop = realEnd;
    }
    var lastReference = references[references.length - 1];
    var lastEnd = lastReference.offset + lastReference.length;
    var lastRealEnd = getRealOffset(content, lastEnd);
    newLineContent += content.substr(lastRealEnd);
    return newLineContent;
  } else {
    return content;
  }
}
