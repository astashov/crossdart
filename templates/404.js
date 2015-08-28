(function () {

    function PackageUrl(value) {
        this.value = value;
        var match = value.match(/\/p\/([^\/]+)\/([^\/]+)\/(.*)/);
        if (match) {
            this.name = match[1];
            this.version = match[2];
            this.path = match[3];
            this.str = this.name + "-" + this.version;
        }
        this.isValid = !!(this.name || this.version);
    }

    var packageUrl = new PackageUrl(location.pathname);

    var packages = JSON.parse(document.querySelector("#packages").textContent);
    var erroredPackages = JSON.parse(document.querySelector("#errored-packages").textContent);

    var packageIndexUrl = "/p/" + packageUrl.name + "/index.html";
    var packageVersionUrl = "/p/" + packageUrl.name + "/index.html#" + packageUrl.version;

    var packageIndexLink = "<a href='" + packageIndexUrl + "'>" + packageUrl.name + "</a>";
    var packageVersionLink = "<a href='" + packageVersionUrl + "'>" + packageUrl.str + "</a>";

    var message = "";
    if (packageUrl.isValid) {
        var versions = packages[packageUrl.name];
        var erroredVersions = erroredPackages[packageUrl.name];
        if (versions && versions.length > 0) {
            var file = packageUrl.path.replace(/\.html$/, "");
            if (versions.indexOf(packageUrl.version) !== -1) {
                if (packageUrl.path.match(/\.dart.html$/)) {
                    message = "It seems like you are trying to open the Dart file <b>" + file + "</b>, " +
                        "which doesn't exist in the package " + packageVersionLink + ". You can get the list of existing " +
                        "source files there - <a href='" + packageVersionUrl + "'>" + packageVersionUrl + "</a>";
                } else {
                    message = "It seems like you are trying to open a file in the package " + packageVersionLink + ", " +
                        "but it doesn't look like correct Dart file name. Check out the package's list of existing " +
                        "source files there - <a href='" + packageVersionUrl + "'>" + packageVersionUrl + "</a>";
                }
            } else {
                var latestUrl = "/p/" + packageUrl.name + "/" + versions[versions.length - 1] + "/" + packageUrl.path;
                message = "It seems like you are trying to open a Dart file in the package " + packageIndexLink +
                    " version <b>" + packageUrl.version + "</b>, but there is no such version for that package. ";
                if (erroredVersions.indexOf(packageUrl.version) !== -1) {
                    message += "We tried to generate Crossdart files for that package version, but there was an error. ";
                }
                message += "You can see the list " +
                    "of available versions there - <a href='" + packageIndexUrl + "'>" + packageIndexUrl + "</a>. " +
                    "Or try to open that file with the latest version available, here - <a href='" + latestUrl + "'>" + latestUrl + "</a>";
            }
        } else if (erroredVersions && erroredVersions.length > 0) {
            message = "It seems like you are trying to open the package <b>" + packageUrl.str + "</b>, " +
                "but there was an error with generating Crossdart files for that package. " +
                "Check the list of available packages <a href='/'>there</a>";
        } else {
            message = "It seems like you are trying to open the package <b>" + packageUrl.name + "</b>, " +
                "but there is no such package. Check the list of available packages <a href='/'>there</a>";
        }
    }

    document.querySelector(".tips").innerHTML = message;

}());
