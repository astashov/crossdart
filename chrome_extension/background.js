chrome.extension.onMessage.addListener(function(message, sender) {
    if (message && message.type === 'showPageAction') {
        chrome.pageAction.show(sender.tab.id);
        var url = localStorage.getItem("crossdartUrl");
        chrome.tabs.sendMessage(sender.tab.id, {url: url});
    }
});
