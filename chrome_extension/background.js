chrome.extension.onMessage.addListener(function(message, sender) {
    if (message && message.crossdart && message.crossdart.action === 'initPopup') {
        chrome.pageAction.show(sender.tab.id);
        var pathname = decodeURIComponent(sender.tab.url.replace(/https?:\/\/(www.)?github.com\//, ""));
        var basePath = pathname.split("/").slice(0, 2).join("/");
        var token = localStorage.getItem(basePath + "/crossdartToken");
        var jsonUrl = localStorage.getItem(basePath + "/crossdartUrl");
        chrome.tabs.sendMessage(
          sender.tab.id, {crossdart: {action: 'popupInitialized', jsonUrl: jsonUrl, token: token}});
    }
});
