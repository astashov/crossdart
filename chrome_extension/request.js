(function () {
  function request(method, url, payload, callback, errorCallback) {
    var httpRequest = new XMLHttpRequest();

    httpRequest.open(method, url, true);
    if (method === "POST") {
      httpRequest.setRequestHeader("Content-Type", "application/json");
    }
    httpRequest.send(payload);

    httpRequest.onreadystatechange = function(response) {
      if (httpRequest.readyState === 4) {
        if (httpRequest.status === 200) {
          callback(httpRequest.responseText);
        } else {
          if (errorCallback) {
            errorCallback(url, httpRequest.status, response);
          } else {
            console.log("Unhandled response " + httpRequest.status + " - " + httpRequest.responseText);
          }
        }
      }
    };
  }

  window.Request = {
    head: function (url, callback, errorCallback) {
      return request("HEAD", url, null, callback, errorCallback);
    },
    get: function (url, callback, errorCallback) {
      return request("GET", url, null, callback, errorCallback);
    },
    getJson: function (url, callback, errorCallback) {
      return request("GET", url, null, function (responseText) {
        return callback(JSON.parse(responseText));
      }, errorCallback);
    },
    post: function (url, payload, callback, errorCallback) {
      return request("POST", url, JSON.stringify(payload), callback, errorCallback);
    }
  }
}());
