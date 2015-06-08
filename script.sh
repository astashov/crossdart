#!/bin/bash

function upload_files_to_s3 {
  while read -r line
  do
    s3cmd -P -c ./.s3cfg put -m 'text/html' html$line s3://crossdart.info$line
  done
}

dart --old_gen_heap_size=4096 bin/parse_packages.dart --sdkpath /Applications/dart/dart-sdk/ --installpath ~/projects/crossdart-out
dart --old_gen_heap_size=8000 bin/generate_packages_html.dart --sdkpath /Applications/dart/dart-sdk --outputpath ~/projects/mixbook/crossdart/html --packagespath ~/projects/crossdart-out/packages --templatespath ./templates
dart --old_gen_heap_size=4096 bin/updated_files_list.dart  --packagespath=/Users/anton/projects/crossdart-out/packages --outputpath=html | upload_files_to_s3
date +%s > html/timestamp
s3cmd -P -c ./.s3cfg put -m 'text/plain' html/timestamp s3://crossdart.info/timestamp
s3cmd -P -c ./.s3cfg put -m 'text/html' html/index.html s3://crossdart.info/index.html
s3cmd -P -c ./.s3cfg put -m 'text/css' html/style.css s3://crossdart.info/style.css
s3cmd -P -c ./.s3cfg put -m 'application/javascript' html/index.js s3://crossdart.info/index.js
s3cmd -P -c ./.s3cfg put -m 'application/javascript' html/package.js s3://crossdart.info/package.js
