var basePath;

var urlField = document.querySelector("#url");
var tokenField = document.querySelector("#token");
var enabledField = document.querySelector("#enabled");

urlField.addEventListener("change", saveChangesInUrl);
tokenField.addEventListener("change", saveChangesInToken);
enabledField.addEventListener("change", saveChangesInEnabled);

var button = document.querySelector("#button");
button.addEventListener("click", function () {
  chrome.tabs.query({active: true, currentWindow: true}, function(tabs) {
    sendApplyMessage(tabs[0].id);
  });
});

var tokenLink = document.querySelector("#token-link");
tokenLink.addEventListener("click", function () {
  chrome.tabs.query({active: true, currentWindow: true}, function(tabs) {
    chrome.tabs.sendMessage(tabs[0].id, {crossdart: {action: "tokenLink", url: tokenLink.attributes.href.value}});
  });
  return false;
});

function setTokenFieldValue() {
  tokenField.value = getTokenFromLocalStorage();
}

function setUrlFieldValue() {
  urlField.value = getUrlFromLocalStorage();
}

function setEnabledFieldValue() {
  enabledField.checked = getEnabledFromLocalStorage();
}

function setTokenToLocalStorage(value) {
  localStorage.setItem(getTokenKey(), value);
}

function setUrlToLocalStorage(value) {
  localStorage.setItem(getUrlKey(), value);
}

function setEnabledToLocalStorage(value) {
  localStorage.setItem(getEnabledKey(), value);
}

function getTokenKey() {
  return basePath + '/crossdartToken';
}

function getUrlKey() {
  return basePath + '/crossdartUrl';
}

function getEnabledKey() {
  return basePath + '/crossdartEnabled';
}

function getTokenFromLocalStorage() {
  return localStorage.getItem(getTokenKey());
}

function getUrlFromLocalStorage() {
  return localStorage.getItem(getUrlKey());
}

function getEnabledFromLocalStorage() {
  var isEnabled = localStorage.getItem(getEnabledKey());
  return isEnabled && isEnabled.toString() === "true";
}

function saveChangesInUrl() {
  chrome.tabs.query({active: true, currentWindow: true}, function(tabs) {
    setUrlToLocalStorage(urlField.value);
  });
}

function saveChangesInToken() {
  chrome.tabs.query({active: true, currentWindow: true}, function(tabs) {
    setTokenToLocalStorage(tokenField.value);
  });
}

function saveChangesInEnabled() {
  chrome.tabs.query({active: true, currentWindow: true}, function(tabs) {
    setEnabledToLocalStorage(enabledField.checked);
  });
}

function sendApplyMessage(id) {
  var token = getTokenFromLocalStorage();
  var url = getUrlFromLocalStorage();
  var enabled = getEnabledFromLocalStorage();
  chrome.tabs.sendMessage(id, {crossdart: {action: "apply", jsonUrl: url, token: token, enabled: enabled}});
}

chrome.tabs.query({active: true, currentWindow: true}, function(tabs) {
  var pathname = decodeURIComponent(tabs[0].url.replace(/https?:\/\/(www.)?github.com\//, ""));
  basePath = pathname.split("/").slice(0, 2).join("/");
  setTokenFieldValue();
  setUrlFieldValue();
  setEnabledFieldValue();
  var urlInfo = document.querySelector(".crossdart-url--info");
  urlInfo.innerHTML = urlInfo.innerHTML + " " + window.Errors.URL_HELP;
});
