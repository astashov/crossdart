(function () {
  window.Github = function () {
    var splittedPath = Path.split(location.pathname);
    this.user = splittedPath[0];
    this.project = splittedPath[1];
    this.basePath = Path.join([this.user, this.project]);
    this.type = getType(location.pathname);
    if (this.type === Github.TREE) {
      this.path = new TreePath(this, location.pathname);
    } else {
      this.path = undefined;
    }
  };

  window.Github.TREE = "tree";
  window.Github.PULL_REQUEST = "pull_request";
  var API_HOST = "https://api.github.com";
  var HOST = "https://github.com";

  function getType(url) {
    if (url.match(/^\/[^\/]+\/[^\/]+\/blob\/[^\/]+\/lib\/(.*)$/)) {
      return Github.TREE;
    } else if (url.match(/^\/[^\/]+\/[^\/]+\/pull\/\d+\/files/)) {
      return Github.PULL_REQUEST;
    }
  }

  window.TreePath = function (github, path) {
    this.absolutePath = path;
    var splittedPath = Path.split(location.pathname);
    this.github = github;
    this.ref = splittedPath[3];
    this.path = splittedPath.slice(4).join("/");
    this.libPath = splittedPath.slice(5).join("/");
  };

  window.TreePath.prototype.getRealRef = function (callback) {
    if (this._getRealRef === undefined) {
      if (this.ref.match(/[a-z0-9]{40}/)) {
        this._getRealRef = this.ref;
        callback(this._getRealRef);
      } else {
        var path = Path.join(["repos", this.github.basePath, "git", "refs", "heads", this.ref]);
        api(path, function (json) {
          this._getRealRef = json.object.sha;
          callback(this._getRealRef);
        });
      }
    } else {
      callback(this._getRealRef);
    }
  };

  window.TreePath.prototype.buildAbsolutePath = function (path) {
    if (path.match(/^http/)) {
      return path;
    } else {
      return Path.join([HOST, this.github.basePath, "blob", this.ref, "lib", path]);
    }
  };

  function api(path, callback, errorCallback) {
    Request.get(Path.join([API_HOST, path]), callback, errorCallback);
  }

}());
