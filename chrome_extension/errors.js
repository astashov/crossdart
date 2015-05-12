(function () {

  window.Errors = {};
  window.Errors.URL_HELP = "It could look something like: 'https://my-crossdarts.s3.amazonaws.com/my-project', then the Crossdart Chrome extension " +
      "will try to make a call to this url + sha + /crossdart.json, e.g.: " +
      "'https://my-crossdarts.s3.amazonaws.com/my-project/36a6c88/crossdart.json'";

  window.Errors.showUrlError = function (url, status, response) {
    var message = "Got error trying to access '" + url + "', HTTP response code: '" + status + "'.<br />" +
        "Make sure you specified the right base in the page action popup (with the XD icon). " +
        window.Errors.URL_HELP;
    showErrorMessage(message);
  };

  window.Errors.showMissingJsonUrlError = function () {
    var message = "You should specify base for the url where to retrieve the JSON file with the Crossdart " +
        "project metadata from. " + window.Errors.URL_HELP;
    showErrorMessage(message);
  };

  window.Errors.showTokenError = function (url, status, response) {
    var message = "Got error trying to access '" + url + "', HTTP response code: '" + status + "'.<br />";
    if (status.toString() === '404') {
      message += " If this is a private project, make sure you added the correct access token in the page " +
          "action popup (with the XD icon), and then refresh the page.";
    }
    showErrorMessage(message);
  };

  function showErrorMessage(message) {
    var element = document.querySelector("#crossdart-error");
    if (element) {
      element.parentNode.removeChild(element);
    }
    element = document.createElement("div");
    element.setAttribute("style",
       "position: fixed; top: 0; left: 0; width: 100%; padding: 1em 10em; background: #FFD1CA; " +
       "border-bottom: #C7786C 1px solid; z-index: 1000; " +
       "text-align: center; font-size: 14px;");
    element.setAttribute("id", "crossdart-error");
    element.innerHTML = "Crossdart error: " + message;
    document.querySelector("body").appendChild(element);
    var close = document.createElement("button");
    close.setAttribute("style",
       "position: absolute; top: 5px; right: 5px; color: red; font-size: 14px; background: none; border: none");
    close.addEventListener("click", function () {
      element.parentNode.removeChild(element);
    });
    close.textContent = "X";
    element.appendChild(close);
  }

}());
