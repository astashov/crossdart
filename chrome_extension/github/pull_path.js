(function () {
  window.PullPath = function (github, path) {
    this.absolutePath = path;
    this.github = github;
    var splittedPath = Path.split(Path.current());
    this.id = parseInt(splittedPath[3], 10);
  };

  window.PullPath.prototype.getRealRefs = function (callback, errorCallback) {
    if (this._getRealRefs === undefined) {
      var path = Path.join(["repos", this.github.basePath, "pulls", this.id]);
      Github.api(path, function (json) {
        this._getRealRefs = [json.base.sha, json.head.sha];
        callback(this._getRealRefs);
      }, errorCallback);
    } else {
      callback(this._getRealRefs);
    }
  };

}());

