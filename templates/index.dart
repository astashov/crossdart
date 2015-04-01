library crossdart.templates.index;

import 'dart:html';

void main() {
  InputElement search = document.querySelector("#search");
  search.onChange.listen((Event event) => _filterPackages(search.value));
  search.onKeyUp.listen((Event event) => _filterPackages(search.value));
}

void _filterPackages(String value) {
  document.querySelector(".packages").classes.toggle("is-hidden", value != "");
  if (value != "") {
    document.querySelectorAll(".package").forEach((Element e) {
      e.classes.toggle("is-visible", e.text.contains(value));
    });
  }
}