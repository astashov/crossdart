(function () {
  window.CrossdartTree = function (github) {
    this.github = github;
    this.handledLines = [];
  };

  window.CrossdartTree.prototype.applyJson = function (json) {
    var path = this.github.path.path;
    var allEntities = json[path];
    if (allEntities) {
      var entitiesByLines = groupEntitiesByLinesAndTypes(allEntities);
      for (var line in entitiesByLines) {
        if (this.handledLines.indexOf(line) === -1) {
          var entities = entitiesByLines[line];
          entities.sort(function (a, b) {
            return a.offset - b.offset;
          });
          var newContent = applyEntities(this.github, this.github.path.ref, getLineContent(line), entities);
          setLineContent(line, newContent);
          this.handledLines.push(line);
        }
      }
    }
  };

  function groupEntitiesByLinesAndTypes(allEntities) {
    var result = {};
    for (var type in allEntities) {
      var entities = allEntities[type];
      for (var i in entities) {
        var entity = JSON.parse(JSON.stringify(entities[i]));
        entity.type = type;
        var line = parseInt(entity.line, 10);
        result[line] = result[line] || [];
        result[line].push(entity);
      }
    }
    return result;
  }

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
