Path = {
  normalize: function (part) {
    return (part || "").toString().replace(/(^\/|\/$)/, "");
  },

  join: function (parts) {
    return parts.map(Path.normalize).join("/");
  },

  split: function (path) {
    return Path.normalize(path).split("/");
  }
};
