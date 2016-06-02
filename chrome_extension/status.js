(function () {
  var refStatuses = []; // [{ref: null, status: null}, {ref: null, status: null}];

  function showStatus(content, showSpinner) {
    var element = document.querySelector("#crossdart-status");
    if (!element) {
      element = document.createElement("div");
      element.setAttribute("style",
        "position: fixed; top: 10px; right: 10px; width: 26em; padding: 1em 1.8em; background: #fefefe; " +
        "border: #C7786C 1px solid; z-index: 999; color: #666; " +
        "text-align: left; font-size: 12px; min-height: 50px;");
      element.setAttribute("id", "crossdart-status");
      var contents = document.createElement("div");
      contents.setAttribute("class", "crossdart-status-contents");
      element.appendChild(contents);
      contents.innerHTML = content;
      document.querySelector("body").appendChild(element);
      var close = document.createElement("button");
      close.setAttribute("style",
        "position: absolute; top: 5px; right: 5px; color: red; font-size: 14px; background: none; border: none");
      close.addEventListener("click", function () {
        element.parentNode.removeChild(element);
      });
      close.textContent = "X";
      element.appendChild(close);
    } else {
      element.querySelector(".crossdart-status-contents").innerHTML = content;
    }
    var spinner = element.querySelector(".crossdart-loader");
    if (showSpinner && !spinner) {
      spinner = document.createElement("div");
      spinner.setAttribute("class", "crossdart-loader");
      element.appendChild(spinner);
    } else if (!showSpinner && spinner) {
      spinner.parentNode.removeChild(spinner);
    }
  }

  function statusMessage(refStatus) {
    var status;
    if (refStatus.status === "error") {
      var github = new Github();
      var url = "https://www.crossdart.info/metadata/" + github.basePath + "/" + refStatus.ref + "/log.txt";
      status = "<a href='" + url + "'>" + refStatus.status + "</a>";
    } else {
      status = refStatus.status;
    }
    return "<div>Getting metadata for " + refStatus.ref.substring(0, 8) + " - " + status + "</div>";
  }

  window.Status = {
    show: function (index, ref, status) {
      refStatuses[index] = {ref: ref, status: status};
      var message = [];
      if (refStatuses[0] && refStatuses[0].ref) {
        message.push(statusMessage(refStatuses[0]));
      }
      if (refStatuses[1] && refStatuses[1].ref) {
        message.push(statusMessage(refStatuses[1]));
      }
      if (message.length === 0 || ((!refStatuses[0] || refStatuses[0].status === "done") && (!refStatuses[1] || refStatuses[1].status === "done"))) {
        var element = document.querySelector("#crossdart-status");
        if (element) {
          element.parentNode.removeChild(element);
        }
      } else {
        var html = "<div>" + message.join("") + "</div>";
        var showSpinner = (refStatuses[0] && refStatuses[0].status !== "error" && refStatuses[0].status !== "done") ||
          (refStatuses[1] && refStatuses[1].status !== "error" && refStatuses[1].status !== "done");
        showStatus(html, showSpinner);
      }
    }
  };
}());
