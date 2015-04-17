(function () {
  window.CrossdartPull = function (github) {
    this.github = github;
  };

  window.CrossdartPull.OLD = "old";
  window.CrossdartPull.NEW = "new";

  window.CrossdartPull.prototype.applyJson = function (type, json, ref) {
    var fileElements = document.querySelectorAll("#files .file");
    for (var index in fileElements) {
      if (fileElements.hasOwnProperty(index) && index.match(/\d+/)) {
        var fileElement = fileElements[index];
        var file = fileElement.querySelector(".file-header").attributes["data-path"].value;
        var referencesByLines = groupBy(json[file] || [], function (r) { return parseInt(r.line, 10); });
        for (var line in referencesByLines) {
          if (doesLineElementExist(type, file, line)) {
            var references = referencesByLines[line];
            var content = getLineContent(type, file, line);
            var regexp = /^(<b.*<\/b>.)/;
            var match = content.match(regexp);
            var prefix = "";
            if (match) {
              content = content.replace(regexp, "");
              prefix = match[1];
            }
            var newContent = applyReferences(this.github, ref, content, references);
            setLineContent(type, file, line, prefix + newContent);
          }
        }
      }
    }
  };

  function doesLineElementExist(type, file, line) {
    return !!getLineElement(type, file, line);
  }

  function getLineElement(type, file, line) {
    var fileHeader = document.querySelector(".file-header[data-path='" + file + "']");
    var lineElements = fileHeader.parentElement.querySelectorAll("[data-line-number~='" + line + "'] + td");
    return Array.prototype.filter.call(lineElements, function (i) {
      var index = Array.prototype.indexOf.call(i.parentNode.children, i);
      return (type === CrossdartPull.OLD ? index === 1 : index === 3);
    })[0];
  }

  function getLineContent(type, file, line) {
    return getLineElement(type, file, line).innerHTML;
  }

  function setLineContent(type, file, line, content) {
    getLineElement(type, file, line).innerHTML = content;
  }

}());

