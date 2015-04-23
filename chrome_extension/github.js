(function () {
  window.Github = function () {
    var pathname = Path.current();
    var splittedPath = Path.split(pathname);
    this.user = splittedPath[0];
    this.project = splittedPath[1];
    this.basePath = Path.join([this.user, this.project]);
    if (Path.isTree(pathname)) {
      this.type = Github.TREE;
      this.path = buildTreePath(this);
    } else if (Path.isPull(pathname)) {
      this.type = Github.PULL_REQUEST;
      this.path = new PullPath(this);
    }
  };

  window.Github.TREE = "tree";
  window.Github.PULL_REQUEST = "pull_request";
  var API_HOST = "https://api.github.com";
  window.Github.HOST = "https://github.com";

  window.Github.isTree = function () {
    return Path.isTree(Path.current());
  };

  window.Github.isPullSplit = function () {
    return Path.isPull(Path.current()) &&
      document.querySelector("meta[name='diff-view']").attributes.content.value === "split";
  };

  window.Github.isPullUnified = function () {
    return Path.isPull(Path.current()) &&
      document.querySelector("meta[name='diff-view']").attributes.content.value === "unified";
  };

  window.Github.api = function (path, callback, errorCallback) {
    var url = Path.join([API_HOST, path]);
    if (Github.token) {
      url += (url.match(/\?/) ? "&" : "?");
      url += "access_token=" + Github.token;
    }
    Request.get(url, callback, errorCallback);
  };
}());
