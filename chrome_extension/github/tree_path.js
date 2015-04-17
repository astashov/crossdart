(function () {
  window.TreePath = function (github, ref, path) {
    this.github = github;
    this.ref = ref;
    this.path = path;
  };

  window.buildTreePath = function (github) {
    var splittedPath = Path.split(location.pathname);
    return new TreePath(github, splittedPath[3], splittedPath.slice(4).join("/"));
  };

  window.TreePath.prototype.getRealRef = function (callback) {
    if (this._getRealRef === undefined) {
      if (this.ref.match(/[a-z0-9]{40}/)) {
        this._getRealRef = this.ref;
        callback(this._getRealRef);
      } else {
        var path = Path.join(["repos", this.github.basePath, "git", "refs", "heads", this.ref]);
        Github.api(path, function (json) {
          this._getRealRef = json.object.sha;
          callback(this._getRealRef);
        });
      }
    } else {
      callback(this._getRealRef);
    }
  };

  window.TreePath.prototype.absolutePath = function () {
    if (this.path.match(/^http/)) {
      return this.path;
    } else {
      return Path.join([Github.HOST, this.github.basePath, "blob", this.ref, this.path]);
    }
  };

}());
