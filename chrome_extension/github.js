(function () {
  window.Github = function () {
    var pathname = location.pathname;
    var splittedPath = Path.split(pathname);
    this.user = splittedPath[0];
    this.project = splittedPath[1];
    this.basePath = Path.join([this.user, this.project]);
    this.type = getType(pathname);
    if (this.type === Github.TREE) {
      this.path = buildTreePath(this);
    } else if (this.type === Github.PULL_REQUEST) {
      this.path = new PullPath(this);
    }
  };

  window.Github.TREE = "tree";
  window.Github.PULL_REQUEST = "pull_request";
  var API_HOST = "https://api.github.com";
  window.Github.HOST = "https://github.com";

  function getType(url) {
    if (url.match(/^\/[^\/]+\/[^\/]+\/blob\/[^\/]+\/lib\/(.*)$/)) {
      return Github.TREE;
    } else if (url.match(/^\/[^\/]+\/[^\/]+\/pull\/\d+\/files/)) {
      return Github.PULL_REQUEST;
    }
  }

  window.Github.api = function (path, callback, errorCallback) {
    var url = Path.join([API_HOST, path]);
    if (Github.token) {
      url += (url.match(/\?/) ? "&" : "?");
      url += "access_token=" + Github.token;
    }
    Request.get(url, callback, errorCallback);
  };

}());
