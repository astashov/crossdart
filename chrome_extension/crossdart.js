(function () {
  window.CrossdartTree = function (github) {
    this.github = github;
  };

  var isCrossdartApplied = false;

  window.CrossdartTree.prototype.applyCrossdart = function (json) {
    var path = this.github.path.libPath;
    var allReferences = json[path];
    if (allReferences) {
      var referencesByLines = groupBy(allReferences, function (r) { return parseInt(r.line, 10); });
      for (var line in referencesByLines) {
        var references = referencesByLines[line];
        var lineContent = getLineContent(line);
        var newLineContent = "";
        var lastStop = 0;
        for (var index in references) {
          var reference = references[index];
          var realOffset = getRealOffset(line, reference.offset);
          newLineContent += lineContent.substr(lastStop, realOffset - lastStop);
          var href = this.github.path.buildAbsolutePath(reference.remotePath);
          newLineContent += "<a href='" + href + "' class='crossdart-link'>";
          var end = reference.offset + reference.length;
          realOffset = getRealOffset(line, reference.offset);
          var realEnd = getRealOffset(line, end);
          newLineContent += lineContent.substr(realOffset, realEnd - realOffset);
          newLineContent += "</a>";
          lastStop = realEnd;
        }
        var lastReference = references[references.length - 1];
        var lastEnd = lastReference.offset + lastReference.length;
        var lastRealEnd = getRealOffset(line, lastEnd);
        newLineContent += lineContent.substr(lastRealEnd);

        setLineContent(line, newLineContent);
      }
    }
  };

  function getLineElement (line) {
    return window.document.querySelector("#LC" + line);
  }

  function getLineContent(line) {
    return getLineElement(line).innerHTML;
  }

  function setLineContent(line, content) {
    getLineElement(line).innerHTML = content;
  }

  function getRealOffset(line, offset) {
    var regexps = [[/(<[^>]*>)/g, 0], [/(&\w+;)/g, 1]];
    var content = getLineContent(line);
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


  var applyCrossdart = function (crossdartBaseUrl) {
    if (!isCrossdartApplied) {
      var github = new Github();
      if (github.type === Github.TREE) {
        github.path.getRealRef(function (ref) {
          var crossdartUrl = Path.join([crossdartBaseUrl, ref, "crossdart.json"]);
          Request.get(crossdartUrl, function (json) {
            console.log(json);
            var crossdart = new CrossdartTree(github);
            crossdart.applyCrossdart(json);
            isCrossdartApplied = true;
          }, function () {
            console.log("the default Github's Crossdart file is missing");
          });
        });
      }
    }
  };

  chrome.extension.sendMessage({type:'showPageAction'});

  chrome.runtime.onMessage.addListener(function (request) {
    if (request.url) {
      applyCrossdart(request.url);
    }
  });
}());
