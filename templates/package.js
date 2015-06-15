(function () {
  var versions = document.querySelectorAll(".version");
  for (var i = 0; i < versions.length; i += 1) {
    versions[i].addEventListener("click", onVersionClick);
  }
  var index;
  if (location.hash !== "") {
    selectVersion(location.hash.replace("#", ""));
  } else {
    selectVersion(versions[0].attributes["data-version"].value);
  }

  function onVersionClick(e) {
    selectVersion(e.target.attributes["data-version"].value);
  }

  function selectVersion(value) {
    var i;
    for (i = 0; i < versions.length; i += 1) {
      versions[i].classList.remove("is-selected");
    }
    var versionElement = document.querySelector(".version[data-version='" + value + "']");
    if (!versionElement) {
      versionElement = document.querySelector(".version:first-child");
    }
    value = versionElement.attributes["data-version"].value;
    location.hash = value;
    versionElement.classList.add("is-selected");
    var filesVersions = document.querySelectorAll(".files-version");
    for (i = 0; i < filesVersions.length; i += 1) {
      filesVersions[i].classList.remove("is-visible");
    }
    document.querySelector(".files-version[data-version='" + value + "']").classList.add("is-visible");
  }
}());
