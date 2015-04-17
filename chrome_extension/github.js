(function () {
  window.Github = function () {
    var splittedPath = Path.split(location.pathname);
    this.user = splittedPath[0];
    this.project = splittedPath[1];
    this.basePath = Path.join([this.user, this.project]);
    this.type = getType(location.pathname);
    if (this.type === Github.TREE) {
      this.path = buildTreePath(this);
    } else if (this.type === Github.PULL_REQUEST) {
      this.path = new PullPath(this, location.pathname);
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
    Request.get(Path.join([API_HOST, path]), callback, errorCallback);
  };

}());
