Request = {
  get: function (url, callback, errorCallback) {
    var httpRequest = new XMLHttpRequest();

    httpRequest.open('GET', url, true);
    httpRequest.send(null);

    httpRequest.onreadystatechange = function(response) {
      if (httpRequest.readyState === 4) {
        if (httpRequest.status === 200) {
          callback(JSON.parse(httpRequest.responseText));
        } else {
          if (errorCallback) {
            errorCallback();
          } else {
            console.log("Unhandled response " + httpRequest.status + " - " + httpRequest.responseText);
          }
        }
      }
    };
  }
};
