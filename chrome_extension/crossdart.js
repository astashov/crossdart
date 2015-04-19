(function () {
  var isCrossdartApplied = false;

  function applyTreeCrossdart(github, crossdartBaseUrl) {
    github.path.getRealRef(function (ref) {
      var crossdartUrl = Path.join([crossdartBaseUrl, ref, "crossdart.json"]);
      Request.get(crossdartUrl, function (json) {
        var crossdart = new CrossdartTree(github);
        crossdart.applyJson(json);
        isCrossdartApplied = true;
      }, function () {
        console.log("the default Github's Crossdart file is missing");
      });
    });
  }

  function applyPullCrossdart(github, crossdartBaseUrl) {
    github.path.getRealRefs(function (refs) {
      var oldRef = refs[0];
      var newRef = refs[1];
      var crossdartUrlOld = Path.join([crossdartBaseUrl, oldRef, "crossdart.json"]);
      Request.get(crossdartUrlOld, function (oldJson) {
        var crossdartUrlNew = Path.join([crossdartBaseUrl, newRef, "crossdart.json"]);
        Request.get(crossdartUrlNew, function (newJson) {
          var crossdart = new CrossdartPull(github);
          crossdart.applyJson(CrossdartPull.OLD, oldJson, oldRef);
          crossdart.applyJson(CrossdartPull.NEW, newJson, newRef);
          isCrossdartApplied = true;
        });
      });
    });
  }

  function applyCrossdart(crossdartBaseUrl) {
    if (!isCrossdartApplied) {
      var github = new Github();
      if (github.type === Github.TREE) {
        applyTreeCrossdart(github, crossdartBaseUrl);
      } else if (github.type === Github.PULL_REQUEST) {
        applyPullCrossdart(github, crossdartBaseUrl);
      }
    }
  }

  chrome.extension.sendMessage({crossdart: {action: 'initPopup', pathname: location.pathname}});

  chrome.runtime.onMessage.addListener(function (request) {
    if (request.crossdart && request.crossdart.action === 'popupInitialized') {
      window.Github.token = request.crossdart.token;
      applyCrossdart(request.crossdart.jsonUrl);
    }
  });
}());
