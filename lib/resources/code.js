(function () {
  if (window.matchMedia('screen and (max-width: 750px)').matches) {
    var link = document.createElement('link');
    link.rel = 'stylesheet';
    link.type = 'text/css';
    link.href = 'https://fonts.googleapis.com/css?family=Roboto+Condensed:400,700,400italic,700italic';
    document.head.appendChild(link);
  }
}());

(function () {
  var allCodeLines = document.querySelectorAll(".code-line");

  var startLine;
  function highlightLine(hash) {
    var match = hash.match(/#line-(\d+)-?(\d+)?$/);
    if (match) {
      startLine = parseInt(match[1], 10);
      var endLine = parseInt(match[2], 10) || startLine;
      var allCodeLines = document.querySelectorAll(".code-line");
      for (var i = 0; i < allCodeLines.length; i += 1) {
        allCodeLines[i].classList.remove("is-highlighted");
      }
      if (typeof startLine === "number" && typeof endLine === "number" && startLine <= endLine) {
        for (var j = startLine; j <= endLine; j += 1) {
          var codeLine = document.querySelector("#code-line-" + j);
          if (codeLine) {
            codeLine.classList.add("is-highlighted");
          }
        }
        document.querySelector("#code-line-" + startLine).scrollIntoView();
      }
    }
  }

  window.onhashchange = function () {
    highlightLine(location.hash);
  };
  highlightLine(location.hash);

  for (var i = 0; i < allCodeLines.length; i += 1) {
    if (allCodeLines[i].textContent === "") {
      allCodeLines[i].innerHTML = "&nbsp;";
    }
  }

  var lineNumbers = document.querySelector(".wrapper .lines").querySelectorAll("a");
  var eventHandler = function (event) {
    if (event.shiftKey && startLine) {
      var line = parseInt(this.id.match(/line-(\d+)/)[1], 10);
      if (line == startLine) {
        location.hash = this.id;
      } else if (line > startLine) {
        location.hash = "line-" + startLine + "-" + line;
      } else {
        location.hash = "line-" + line + "-" + startLine;
      }
    } else {
      location.hash = this.id;
    }
  };
  for (var i = 0; i < lineNumbers.length; i += 1) {
    lineNumbers[i].addEventListener("click", eventHandler);
  }
}());

(function () {
  var foldables = document.querySelectorAll(".filetree--item--fold-icon,.filetree--item__directory > .filetree--item--info > .filetree--item--title");
  var IS_OPEN = "is-open";

  function foldablesOnClick(e) {
    var item = e.target.parentNode.parentNode;
    if (item.classList.contains(IS_OPEN)) {
      item.classList.remove(IS_OPEN);
    } else {
      item.classList.add(IS_OPEN);
    }
  }

  for (var i = 0; i < foldables.length; i += 1) {
    foldables[i].addEventListener("click", foldablesOnClick);
  }
}());

(function () {
  var originX;
  var dragHandle = document.querySelector(".filetree--drag-handle");
  var filetree = document.querySelector(".filetree");
  var code = document.querySelector(".code");
  var originalWidth = filetree.clientWidth;
  dragHandle.addEventListener("mousedown", function (e) {
    originX = e.clientX;
    document.body.classList.add("is-dragging-handle");
  });
  document.body.addEventListener("mouseup", function (e) {
    originX = null;
    originalWidth = filetree.clientWidth;
    document.body.classList.remove("is-dragging-handle");
  });
  document.body.addEventListener("mousemove", function (e) {
    if (originX) {
      var difference = e.clientX - originX;
      filetree.style.width = (originalWidth + difference) + "px";
      code.style.left = (originalWidth + difference) + "px";
    }
  });
}());

(function () {
  var button = document.querySelector(".nav--filetree-toggle");
  if (button) {
    button.addEventListener("click", function (e) {
      e.preventDefault();
      e.stopPropagation();
      var content = document.querySelector(".content");
      content.classList.toggle("is-filetree-visible");
    });
  }
}());

(function () {
  var filetreeRoot = document.querySelector(".filetree--root");
  var currentFile = document.querySelector(".filetree--item__file.is-current");
  if (currentFile.getBoundingClientRect().top > filetreeRoot.scrollTop + window.innerHeight) {
    filetreeRoot.scrollTop = currentFile.offsetTop - window.innerHeight / 2;
  }
}());

(function () {
  var fuzzyInput = document.querySelector(".filetree--fuzzy-search--input");
  var files = document.querySelectorAll(".filetree--item__file");
  var directories = document.querySelectorAll(".filetree--item__directory");
  var openState = [];
  var wasClear = fuzzyInput.value.trim().length === 0;

  document.body.addEventListener("keyup", function (e) {
    if (e.keyCode === 84) { // t
      fuzzyInput.focus();
    }
  });

  var onChange = function () {
    function savePreviouslyOpenedDirectories() {
      for (var i = 0; i < directories.length; i += 1) {
        openState[i] = directories[i].classList.contains("is-open");
      }
    }

    function openAllDirectories() {
      for (var i = 0; i < directories.length; i += 1) {
        directories[i].classList.add("is-open");
      }
    }

    function getTitleElement(fileElement) {
      var title = fileElement.querySelector(":scope > .filetree--item--info > .filetree--item--title > a");
      if (!title) {
        title = fileElement.querySelector(":scope > .filetree--item--info > .filetree--item--title");
      }
      return title;
    }

    function filterAndHighlighMatchingFiles() {
      for (var i = 0; i < files.length; i += 1) {
        var fileElement = files[i];
        var title = getTitleElement(fileElement);

        var results = fuzzy.filter(text, [title.innerHTML.replace(/<\/?em>/g, "").trim()], {pre: '<em>', post: '</em>'});
        if (results.length > 0) {
          fileElement.classList.remove("is-hidden");
          title.innerHTML = results[0].string;
        } else {
          fileElement.classList.add("is-hidden");
        }
      }
    }

    function hideDirectoriesWithAllHiddenFiles() {
      for (var i = 0; i < directories.length; i += 1) {
        var directory = directories[i];
        var directoryFiles = directory.querySelectorAll(".filetree--item__file");
        var areAllInvisible = true;
        for (var j = 0; j < directoryFiles.length; j += 1) {
          var directoryFile = directoryFiles[j];
          areAllInvisible = areAllInvisible && directoryFile.classList.contains("is-hidden");
        }
        if (areAllInvisible) {
          directory.classList.add("is-hidden");
        } else {
          directory.classList.remove("is-hidden");
        }
      }
    }

    function showAllFiles() {
      for (var i = 0; i < files.length; i += 1) {
        files[i].classList.remove("is-hidden");
        var title = getTitleElement(files[i]);
        title.innerHTML = title.innerHTML.replace(/<\/?em>/g, "");
      }
    }

    function showAndRestoreAllDirectories() {
      for (var i = 0; i < directories.length; i += 1) {
        directories[i].classList.remove("is-hidden");
        if (openState[i]) {
          directories[i].classList.add("is-open");
        } else {
          directories[i].classList.remove("is-open");
        }
      }
    }

    var text = fuzzyInput.value.trim();
    if (text.length > 0) {
      if (wasClear) {
        savePreviouslyOpenedDirectories();
      }
      openAllDirectories();
      filterAndHighlighMatchingFiles();
      hideDirectoriesWithAllHiddenFiles();
      wasClear = false;
    } else {
      showAllFiles();
      showAndRestoreAllDirectories();
      wasClear = true;
    }
  };

  fuzzyInput.addEventListener("keyup", onChange);
  if (fuzzyInput.value.trim().length > 0) {
    onChange();
  }
}());



/*
 * Fuzzy
 * https://github.com/myork/fuzzy
 *
 * Copyright (c) 2012 Matt York
 * Licensed under the MIT license.
 */
(function() {

  var root = this;

  var fuzzy = {};

  // Use in node or in browser
  if (typeof exports !== 'undefined') {
    module.exports = fuzzy;
  } else {
    root.fuzzy = fuzzy;
  }

  // Return all elements of `array` that have a fuzzy
  // match against `pattern`.
  fuzzy.simpleFilter = function(pattern, array) {
    return array.filter(function(string) {
      return fuzzy.test(pattern, string);
    });
  };

  // Does `pattern` fuzzy match `string`?
  fuzzy.test = function(pattern, string) {
    return fuzzy.match(pattern, string) !== null;
  };

  // If `pattern` matches `string`, wrap each matching character
  // in `opts.pre` and `opts.post`. If no match, return null
  fuzzy.match = function(pattern, string, opts) {
    opts = opts || {};
    var patternIdx = 0
      , result = []
      , len = string.length
      , totalScore = 0
      , currScore = 0
      // prefix
      , pre = opts.pre || ''
      // suffix
      , post = opts.post || ''
      // String to compare against. This might be a lowercase version of the
      // raw string
      , compareString =  opts.caseSensitive && string || string.toLowerCase()
      , ch, compareChar;

    pattern = opts.caseSensitive && pattern || pattern.toLowerCase();

    // For each character in the string, either add it to the result
    // or wrap in template if it's the next string in the pattern
    for(var idx = 0; idx < len; idx++) {
      ch = string[idx];
      if(compareString[idx] === pattern[patternIdx]) {
        ch = pre + ch + post;
        patternIdx += 1;

        // consecutive characters should increase the score more than linearly
        currScore += 1 + currScore;
      } else {
        currScore = 0;
      }
      totalScore += currScore;
      result[result.length] = ch;
    }

    // return rendered string if we have a match for every char
    if(patternIdx === pattern.length) {
      return {rendered: result.join(''), score: totalScore};
    }

    return null;
  };

  // The normal entry point. Filters `arr` for matches against `pattern`.
  // It returns an array with matching values of the type:
  //
  //     [{
  //         string:   '<b>lah' // The rendered string
  //       , index:    2        // The index of the element in `arr`
  //       , original: 'blah'   // The original element in `arr`
  //     }]
  //
  // `opts` is an optional argument bag. Details:
  //
  //    opts = {
  //        // string to put before a matching character
  //        pre:     '<b>'
  //
  //        // string to put after matching character
  //      , post:    '</b>'
  //
  //        // Optional function. Input is an entry in the given arr`,
  //        // output should be the string to test `pattern` against.
  //        // In this example, if `arr = [{crying: 'koala'}]` we would return
  //        // 'koala'.
  //      , extract: function(arg) { return arg.crying; }
  //    }
  fuzzy.filter = function(pattern, arr, opts) {
    opts = opts || {};
    return arr
      .reduce(function(prev, element, idx, arr) {
        var str = element;
        if(opts.extract) {
          str = opts.extract(element);
        }
        var rendered = fuzzy.match(pattern, str, opts);
        if(rendered != null) {
          prev[prev.length] = {
              string: rendered.rendered
            , score: rendered.score
            , index: idx
            , original: element
          };
        }
        return prev;
      }, [])

      // Sort by score. Browsers are inconsistent wrt stable/unstable
      // sorting, so force stable by using the index in the case of tie.
      // See http://ofb.net/~sethml/is-sort-stable.html
      .sort(function(a,b) {
        var compare = b.score - a.score;
        if(compare) return compare;
        return a.index - b.index;
      });
  };
}());

(function () {
  hljs.highlightBlock(document.querySelector(".code"));
}());
