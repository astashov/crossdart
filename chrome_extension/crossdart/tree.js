(function () {
  window.CrossdartTree = function (github) {
    this.github = github;
  };

  window.CrossdartTree.prototype.applyJson = function (json) {
    var path = this.github.path.path;
    var allReferences = json[path];
    if (allReferences) {
      var referencesByLines = groupBy(allReferences, function (r) { return parseInt(r.line, 10); });
      for (var line in referencesByLines) {
        var references = referencesByLines[line];
        var newContent = applyReferences(this.github, this.github.path.ref, getLineContent(line), references);
        setLineContent(line, newContent);
      }
    }
  };

  function getLineElement(line) {
    return window.document.querySelector("#LC" + line);
  }

  function getLineContent(line) {
    return getLineElement(line).innerHTML;
  }

  function setLineContent(line, content) {
    getLineElement(line).innerHTML = content;
  }
}());
