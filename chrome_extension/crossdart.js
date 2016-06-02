(function () {
  function applyTreeCrossdart(github, crossdartBaseUrl, crossdart) {
    github.path.getRealRef(function (ref) {
      var crossdartUrl = Path.join([crossdartBaseUrl, ref, "crossdart.json"]);
      Request.getJson(crossdartUrl, function (json) {
        crossdart.applyJson(json);
      }, Errors.showUrlError);
    }, Errors.showTokenError);
  }

  function applyPullSplitCrossdart(github, crossdartBaseUrl, crossdart) {
    github.path.getRealRefs(function (refs) {
      var oldRef = refs[0];
      var newRef = refs[1];
      var crossdartUrlOld = Path.join([crossdartBaseUrl, oldRef, "crossdart.json"]);
      Request.getJson(crossdartUrlOld, function (oldJson) {
        crossdart.applyJson(CROSSDART_PULL_OLD, oldJson, oldRef);
      }, Errors.showUrlError);
      var crossdartUrlNew = Path.join([crossdartBaseUrl, newRef, "crossdart.json"]);
      Request.getJson(crossdartUrlNew, function (newJson) {
        crossdart.applyJson(CROSSDART_PULL_NEW, newJson, newRef);
      }, Errors.showUrlError);
    }, Errors.showTokenError);
  }

  function applyPullUnifiedCrossdart(github, crossdartBaseUrl, crossdart) {
    github.path.getRealRefs(function (refs) {
      var oldRef = refs[0];
      var newRef = refs[1];
      var crossdartUrlOld = Path.join([crossdartBaseUrl, oldRef, "crossdart.json"]);
      Request.getJson(crossdartUrlOld, function (oldJson) {
        crossdart.applyJson(CROSSDART_PULL_OLD, oldJson, oldRef);
      }, Errors.showUrlError);
      var crossdartUrlNew = Path.join([crossdartBaseUrl, newRef, "crossdart.json"]);
      Request.getJson(crossdartUrlNew, function (newJson) {
        crossdart.applyJson(CROSSDART_PULL_NEW, newJson, newRef);
      }, Errors.showUrlError);
    }, Errors.showTokenError);
  }

  function checkRef(index, github, baseUrl, ref, callback) {
    var url = baseUrl + "/" + ref + "/crossdart.json";
    Request.head(url, function () {
      Status.show(index, ref, "done");
      callback();
    },
    function () {
      Request.get(baseUrl + "/" + ref + "/status.txt", function (status) {
        Status.show(index, ref, status);
        if (status !== "error") {
          setTimeout(function () {
            checkRef(index, github, baseUrl, ref, callback);
          }, 1000);
        }
      }, function () {
        Request.post("https://metadata.crossdart.info/analyze", {
          url: "https://github.com/" + github.basePath,
          sha: ref
        }, function () {
          setTimeout(function () {
            checkRef(index, github, baseUrl, ref, callback);
          }, 1000);
        });
      });
    });
  }

  function fetchMetadataUrl(shouldReuseCrossdart) {
    var github = new Github();
    var baseUrl = "https://www.crossdart.info/metadata/" + github.basePath;
    if (github.type === Github.PULL_REQUEST) {
      github.path.getRealRefs(function (refs) {
        var isOneDone = false;
        checkRef(0, github, baseUrl, refs[0], function () {
          if (isOneDone) {
            applyCrossdart(baseUrl, shouldReuseCrossdart);
          }
          isOneDone = true;
        });
        checkRef(1, github, baseUrl, refs[1], function () {
          if (isOneDone) {
            applyCrossdart(baseUrl, shouldReuseCrossdart);
          }
          isOneDone = true;
        });
      });
    } else {
      github.path.getRealRef(function (ref) {
        checkRef(0, github, baseUrl, ref, function () {
          applyCrossdart(baseUrl, shouldReuseCrossdart);
        });
      });
    }
  }

  var crossdart;
  function applyCrossdart(crossdartBaseUrl, shouldReuseCrossdart) {
    if (enabled) {
      if (!crossdartBaseUrl || crossdartBaseUrl.toString().trim() === "") {
        fetchMetadataUrl();
      } else {
        var github = new Github();
        if (Github.isTree()) {
          if (!shouldReuseCrossdart || !crossdart) {
            crossdart = new CrossdartTree(github);
          }
          applyTreeCrossdart(github, crossdartBaseUrl, crossdart);
        } else if (Github.isPullSplit()) {
          if (!shouldReuseCrossdart || !crossdart) {
            crossdart = new CrossdartPullSplit(github);
          }
          applyPullSplitCrossdart(github, crossdartBaseUrl, crossdart);
        } else if (Github.isPullUnified()) {
          if (!shouldReuseCrossdart || !crossdart) {
            crossdart = new CrossdartPullUnified(github);
          }
          applyPullUnifiedCrossdart(github, crossdartBaseUrl, crossdart);
        }
      }
    }
  }

  chrome.extension.sendMessage({crossdart: {action: 'initPopup'}});

  var jsonUrl;
  var enabled;
  chrome.runtime.onMessage.addListener(function (request) {
    if (request.crossdart) {
      if (request.crossdart.action === 'popupInitialized' || request.crossdart.action === 'apply') {
        window.Github.token = request.crossdart.token;
        jsonUrl = request.crossdart.jsonUrl;
        enabled = request.crossdart.enabled;
        if (enabled) {
          applyCrossdart(jsonUrl, request.crossdart.action === 'apply');
        }
      } else if (request.crossdart.action === 'tokenLink') {
        location.href = request.crossdart.url;
      }
    }
  });

  document.addEventListener(EVENT.LOCATION_CHANGE, function (e) {
    var oldPath = e.detail.before.pathname;
    var newPath = e.detail.now.pathname;
    var condition = false;
    condition = condition || (oldPath !== newPath && Path.isTree(newPath));
    condition = condition || (!Path.isPull(oldPath) && Path.isPull(newPath));
    if (condition) {
      applyCrossdart(jsonUrl);
    }
  });

  document.body.addEventListener("click", function (e) {
    var className = e.target.className;
    if (className.includes("octicon-unfold") || className.includes("diff-expander")) {
      setTimeout(function () {
        applyCrossdart(jsonUrl, true);
      }, 500);
    }
  });

  var tooltip;
  document.addEventListener("click", function (e) {
    if (e.target.className == "crossdart-declaration") {
      var content = declarationTooltipContent(e.target);
      if (tooltip) {
        tooltip.destroy();
      }
      tooltip = new Tooltip(e.target, {tooltipOffset: {x: 0, y: 8}});

      var documentBodyListener = function (e) {
        tooltip.hide();
        document.body.removeEventListener("click", documentBodyListener);
      };
      document.body.addEventListener("click", documentBodyListener);

      tooltip.setContent(content);
      tooltip.show();
    }
  });

  function declarationTooltipContent(element) {
    var references = JSON.parse(element.attributes["data-references"].value);
    var ref = element.attributes["data-ref"].value;
    var div = document.createElement("div");
    div.className = "crossdart-declaration--contents";
    var label = document.createElement("div");
    label.className = "crossdart-declaration--contents--label";
    label.appendChild(document.createTextNode("Usages:"));
    div.appendChild(label);
    var ul = document.createElement("ul");
    references.forEach(function (reference) {
      var a = document.createElement("a");
      var href = new TreePath(new Github(), ref, reference.remotePath).absolutePath();
      a.setAttribute("href", href);
      a.appendChild(document.createTextNode(reference.remotePath));
      var li = document.createElement("li");
      li.appendChild(a);
      ul.appendChild(li);
    });
    div.appendChild(ul);
    return div;
  }

}());
