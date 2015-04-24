(function () {
  function applyTreeCrossdart(github, crossdartBaseUrl, crossdart) {
    github.path.getRealRef(function (ref) {
      var crossdartUrl = Path.join([crossdartBaseUrl, ref, "crossdart.json"]);
      Request.get(crossdartUrl, function (json) {
        crossdart.applyJson(json);
      }, function () {
        console.log("the default Github's Crossdart file is missing");
      });
    });
  }

  function applyPullSplitCrossdart(github, crossdartBaseUrl, crossdart) {
    github.path.getRealRefs(function (refs) {
      var oldRef = refs[0];
      var newRef = refs[1];
      var crossdartUrlOld = Path.join([crossdartBaseUrl, oldRef, "crossdart.json"]);
      Request.get(crossdartUrlOld, function (oldJson) {
        var crossdartUrlNew = Path.join([crossdartBaseUrl, newRef, "crossdart.json"]);
        Request.get(crossdartUrlNew, function (newJson) {
          crossdart.applyJson(CrossdartPullSplit.OLD, oldJson, oldRef);
          crossdart.applyJson(CrossdartPullSplit.NEW, newJson, newRef);
        });
      });
    });
  }

  var crossdart;
  function applyCrossdart(crossdartBaseUrl, shouldReuseCrossdart) {
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
    }
  }

  chrome.extension.sendMessage({crossdart: {action: 'initPopup'}});

  var jsonUrl;
  chrome.runtime.onMessage.addListener(function (request) {
    if (request.crossdart) {
      if (request.crossdart.action === 'popupInitialized' || request.crossdart.action === 'apply') {
        window.Github.token = request.crossdart.token;
        jsonUrl = request.crossdart.jsonUrl;
        applyCrossdart(jsonUrl, request.crossdart.action === 'apply');
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
