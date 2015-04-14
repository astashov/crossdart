var textField = document.querySelector("#url");
textField.value = localStorage.getItem('crossdartUrl');

function sendChangesInTextField() {
  chrome.tabs.query({active: true, currentWindow: true}, function(tabs) {
    localStorage.setItem('crossdartUrl', textField.value);
    var tab = tabs[0];
    chrome.tabs.sendMessage(tab.id, {url: textField.value});
  });
}

textField.addEventListener("blur", sendChangesInTextField);
textField.addEventListener("keydown", sendChangesInTextField);
textField.addEventListener("change", sendChangesInTextField);
