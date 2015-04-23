(function () {
  window.CrossdartPullSplit = function (github) {
    this.github = github;
    this.handledLinesByFiles = {};
  };

  window.CrossdartPullSplit.OLD = "old";
  window.CrossdartPullSplit.NEW = "new";

  window.CrossdartPullSplit.prototype.applyJson = function (type, json, ref) {
    this.handledLinesByFiles[type] = this.handledLinesByFiles[type] || {};
    var fileElements = document.querySelectorAll("#files .file");
    for (var index in fileElements) {
      if (fileElements.hasOwnProperty(index) && index.match(/\d+/)) {
        var fileElement = fileElements[index];
        var file = fileElement.querySelector(".file-header").attributes["data-path"].value;
        this.handledLinesByFiles[type][file] = this.handledLinesByFiles[type][file] || [];
        var referencesByLines = groupBy(json[file] || [], function (r) { return parseInt(r.line, 10); });
        for (var line in referencesByLines) {
          if (doesLineElementExist(type, file, line) && this.handledLinesByFiles[type][file].indexOf(line) === -1) {
            var references = referencesByLines[line];
            var content = getLineContent(type, file, line);
            var prefix = content[0];
            content = content.substr(1);
            var newContent = applyReferences(this.github, ref, content, references);
            setLineContent(type, file, line, prefix + newContent);
            this.handledLinesByFiles[type][file].push(line);
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
    var lineElement = Array.prototype.filter.call(lineElements, function (i) {
      var index = Array.prototype.indexOf.call(i.parentNode.children, i);
      return (type === CrossdartPullSplit.OLD ? index === 1 : index === 3);
    })[0];
    if (lineElement) {
      if (lineElement.className.includes("blob-code-inner")) {
        return lineElement;
      } else {
        return lineElement.querySelector(".blob-code-inner");
      }
    }
  }

  function getLineContent(type, file, line) {
    return getLineElement(type, file, line).innerHTML;
  }

  function setLineContent(type, file, line, content) {
    getLineElement(type, file, line).innerHTML = content;
  }

}());

