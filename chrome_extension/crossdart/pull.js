(function () {
  window.CROSSDART_PULL_OLD = "old";
  window.CROSSDART_PULL_NEW = "new";

  var CrossdartPull = function (github) {
    this.github = github;
    this.handledLinesByFiles = {};

    this.applyJson = function (type, json, ref) {
      this.handledLinesByFiles[type] = this.handledLinesByFiles[type] || {};
      var fileElements = document.querySelectorAll("#files .file");
      for (var index in fileElements) {
        if (fileElements.hasOwnProperty(index) && index.match(/\d+/)) {
          var fileElement = fileElements[index];
          var file = fileElement.querySelector(".file-header").attributes["data-path"].value;
          this.handledLinesByFiles[type][file] = this.handledLinesByFiles[type][file] || [];
          var referencesByLines = groupBy(json[file] || [], function (r) { return parseInt(r.line, 10); });
          for (var line in referencesByLines) {
            if (this._doesLineElementExist(type, file, line) && this.handledLinesByFiles[type][file].indexOf(line) === -1) {
              var references = referencesByLines[line];
              var content = this._getLineContent(type, file, line);
              var prefix = content[0];
              content = content.substr(1);
              var newContent = applyReferences(this.github, ref, content, references);
              this._setLineContent(type, file, line, prefix + newContent);
              this.handledLinesByFiles[type][file].push(line);
            }
          }
        }
      }
    };

    this._doesLineElementExist = function (type, file, line) {
      return !!this._getLineElement(type, file, line);
    };

    this._getLineContent = function (type, file, line) {
      return this._getLineElement(type, file, line).innerHTML;
    };

    this._setLineContent = function (type, file, line, content) {
      this._getLineElement(type, file, line).innerHTML = content;
    };
  };

  window.CrossdartPullSplit = function (github) {
    CrossdartPull.apply(this, [github]);
    this._getLineElement = function (type, file, line) {
      var fileHeader = document.querySelector(".file-header[data-path='" + file + "']");
      var lineElements = fileHeader.parentElement.querySelectorAll("[data-line-number~='" + line + "'] + td");
      var lineElement = Array.prototype.filter.call(lineElements, function (i) {
        var index = Array.prototype.indexOf.call(i.parentNode.children, i);
        return (type === CROSSDART_PULL_OLD ? index === 1 : index === 3);
      })[0];
      if (lineElement) {
        if (lineElement.className.includes("blob-code-inner")) {
          return lineElement;
        } else {
          return lineElement.querySelector(".blob-code-inner");
        }
      }
    }
  };

  window.CrossdartPullUnified = function (github) {
    CrossdartPull.apply(this, [github]);

    this._getLineElement = function (type, file, line) {
      var fileHeader = document.querySelector(".file-header[data-path='" + file + "']");
      var elIndex = (type === CROSSDART_PULL_OLD ? 1 : 2);
      var lineNumberElement = fileHeader.parentElement.querySelector(
        "[data-line-number~='" + line + "']:nth-child(" + elIndex + ")"
      );
      if (lineNumberElement) {
        var lineContainerChildren = lineNumberElement.parentNode.children;
        var lineElement = lineContainerChildren[lineContainerChildren.length - 1];
        if (lineElement) {
          if (lineElement.className.includes("blob-code-inner")) {
            return lineElement;
          } else {
            return lineElement.querySelector(".blob-code-inner");
          }
        }
      }
    }
  };

}());

