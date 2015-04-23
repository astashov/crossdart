(function () {
  var pathname, hash;

  function detectLocationChange() {
    if (Path.current() !== pathname || location.hash !== hash) {
      var event = new CustomEvent(EVENT.LOCATION_CHANGE, {
        detail: {before: {pathname: pathname, hash: hash}, now: {pathname: Path.current(), hash: location.hash}}
      });
      document.dispatchEvent(event);
      pathname = Path.current();
      hash = location.hash;
    }
    setTimeout(detectLocationChange, 200);
  }

  detectLocationChange();
}());
