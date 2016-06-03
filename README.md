# Crossdart

Analyzes source code of a given project, and emits one of the following:

* HTML pages with hyperlinked source code of the project.
* JSON file with the analysis data.
* Github version of the JSON file with the analysis data (for [Crossdart Chrome Extension](https://chrome.google.com/webstore/detail/crossdart-chrome-extensio/jmdjoliiaibifkklhipgmnciiealomhd))

## Installation

Install it via `pub global activate crossdart`.

## Usage

Run it as `pub global run crossdart`.

Required arguments:

* `--input` - path to your project
* `--dart-sdk` - path to Dart SDK

Optional arguments:

* `--output` - where to place the output (HTML or JSON). Will be the same as `--input` if omitted.
* `--hosted-url` - URL of Crossdart's site. `https://www.crossdart.info` by default.
* `--url-path-prefix` - path prefix on the Crossdart's site. `p` by default.
* `--output-format` - output format. Could be `github`, `html` or `json`. `github` by default.

## Example

```bash
$ pub global run crossdart --input=/home/john/my_dart_project --dart-sdk=/usr/lib/dart
$ pub global run crossdart --input=/home/john/my_dart_project --dart-sdk=/usr/lib/dart --output=/home/john/crossdart-output --output-format=html
```

## Contributing

Please use Github's bug tracker for bugs. Pull Requests are welcome.
