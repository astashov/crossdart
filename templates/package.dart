library crossdart.templates.package;

import 'dart:html';

void main() {
  ElementList versions = document.querySelectorAll(".version");
  versions.onClick.listen((MouseEvent e) {
    _selectVersion((e.target as Element).dataset["version"]);
  });
  _selectVersion(versions.first.dataset["version"]);
}

void _selectVersion(String value) {
  document.querySelectorAll(".version").classes.remove("is-selected");
  document.querySelector(".version[data-version='$value'").classes.add("is-selected");
  document.querySelectorAll(".files-version").classes.remove("is-visible");
  document.querySelector(".files-version[data-version='$value'").classes.add("is-visible");
}
