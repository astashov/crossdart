(function () {
  function applyTreeCrossdart(github, crossdartBaseUrl, crossdart) {
    github.path.getRealRef(function (ref) {
      var crossdartUrl = Path.join([crossdartBaseUrl, ref, "crossdart.json"]);
      Request.get(crossdartUrl, function (json) {
        crossdart.applyJson(json);
      }, Errors.showUrlError);
    }, Errors.showTokenError);
  }

  function applyPullSplitCrossdart(github, crossdartBaseUrl, crossdart) {
    github.path.getRealRefs(function (refs) {
      var oldRef = refs[0];
      var newRef = refs[1];
      var crossdartUrlOld = Path.join([crossdartBaseUrl, oldRef, "crossdart.json"]);
      Request.get(crossdartUrlOld, function (oldJson) {
        var crossdartUrlNew = Path.join([crossdartBaseUrl, newRef, "crossdart.json"]);
        Request.get(crossdartUrlNew, function (newJson) {
          crossdart.applyJson(CROSSDART_PULL_OLD, oldJson, oldRef);
          crossdart.applyJson(CROSSDART_PULL_NEW, newJson, newRef);
        }, Errors.showUrlError);
      }, Errors.showUrlError);
    }, Errors.showTokenError);
  }

  function applyPullUnifiedCrossdart(github, crossdartBaseUrl, crossdart) {
    github.path.getRealRefs(function (refs) {
      var oldRef = refs[0];
      var newRef = refs[1];
      var crossdartUrlOld = Path.join([crossdartBaseUrl, oldRef, "crossdart.json"]);
      Request.get(crossdartUrlOld, function (oldJson) {
        var crossdartUrlNew = Path.join([crossdartBaseUrl, newRef, "crossdart.json"]);
        Request.get(crossdartUrlNew, function (newJson) {
          crossdart.applyJson(CROSSDART_PULL_OLD, oldJson, oldRef);
          crossdart.applyJson(CROSSDART_PULL_NEW, newJson, newRef);
        }, Errors.showUrlError);
      }, Errors.showUrlError);
    }, Errors.showTokenError);
  }

  var crossdart;
  function applyCrossdart(crossdartBaseUrl, shouldReuseCrossdart) {
    if (enabled) {
      if (!crossdartBaseUrl || crossdartBaseUrl.toString().trim() === "") {
        Errors.showMissingJsonUrlError();
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

}());
