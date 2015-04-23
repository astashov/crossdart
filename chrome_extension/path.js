Path = {
  current: function () {
    return decodeURIComponent(location.pathname);
  },

  normalize: function (part) {
    return (part || "").toString().replace(/(^\/|\/$)/, "");
  },

  join: function (parts) {
    return parts.map(Path.normalize).join("/");
  },

  split: function (path) {
    return Path.normalize(path).split("/");
  },

  isTree: function (path) {
    return path.match(/^\/[^\/]+\/[^\/]+\/blob\/[^\/]+\/lib\/(.*)$/);
  },

  isPull: function (path) {
    return path.match(/^\/[^\/]+\/[^\/]+\/pull\/\d+\/files/);
  }
};
