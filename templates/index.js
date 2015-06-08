(function () {
  var search = document.querySelector("#search");

  search.addEventListener("change", function (e) { filterPackages(search.value); });
  search.addEventListener("keyup", function (e) { filterPackages(search.value); });

  function filterPackages(value) {
    var packages = document.querySelector(".packages");

    if (value !== "") {
      packages.classList.add("is-hidden");
    } else {
      packages.classList.remove("is-hidden");
    }

    if (value !== "") {
      var package = document.querySelectorAll(".package");
      for (var i = 0; i < package.length; i += 1) {
        var element = package[i];
        if (element.textContent.indexOf(value) !== -1) {
          element.classList.add("is-visible");
        } else {
          element.classList.remove("is-visible");
        }
      }
    }
  }
}());
