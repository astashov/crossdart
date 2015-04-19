var basePath;

var urlField = document.querySelector("#url");
urlField.value = localStorage.getItem('crossdartUrl');
var tokenField = document.querySelector("#token");

urlField.addEventListener("change", saveChangesInUrl);
tokenField.addEventListener("change", saveChangesInToken);

var button = document.querySelector("#button");
button.addEventListener("click", function () {
  chrome.tabs.query({active: true, currentWindow: true}, function(tabs) {
    sendApplyMessage(tabs[0].id);
  });
});

function setTokenFieldValue() {
  tokenField.value = getTokenFromLocalStorage();
}

function setTokenToLocalStorage(value) {
  localStorage.setItem(getTokenKey(), value);
}

function getTokenKey() {
  return basePath + '/crossdartToken';
}

function getTokenFromLocalStorage() {
  return localStorage.getItem(getTokenKey());
}

function getUrlFromLocalStorage() {
  return localStorage.getItem("crossdartUrl");
}

function saveChangesInUrl() {
  chrome.tabs.query({active: true, currentWindow: true}, function(tabs) {
    localStorage.setItem('crossdartUrl', urlField.value);
  });
}

function saveChangesInToken() {
  chrome.tabs.query({active: true, currentWindow: true}, function(tabs) {
    setTokenToLocalStorage(tokenField.value);
  });
}

function sendApplyMessage(id) {
  var token = getTokenFromLocalStorage(pathname);
  var url = getUrlFromLocalStorage();
  chrome.tabs.sendMessage(id, {crossdart: {action: "apply", jsonUrl: url, token: token}});
}

chrome.tabs.query({active: true, currentWindow: true}, function(tabs) {
  var pathname = tabs[0].url.replace(/https?:\/\/(www.)?github.com\//, "");
  basePath = pathname.split("/").slice(0, 2).join("/");
  setTokenFieldValue();
});
