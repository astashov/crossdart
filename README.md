# Crossdart

This project does two things:

1. It's a generator of the site [http://crossdart.info](Crossdart)
2. It's a generator of the JSON Crossdart metadata, which is used for the Crossdart Chrome extension, to make the Dart code on Github hyperlinked in tree views and pull requests.

Let's review the second case, since you can get some benefits from it for your project.

## Demo

[Here](https://github.com/astashov/crossdart/raw/6f9a0e6d609c25c98f8ba0d6a05015de5a8693a4/demo.gif) (22MB) 

## Installation

Unfortunately, for now this is not just one-click installation, you have to do plenty of steps to make it work.
I'll try to document them here in details, to simplify the ramp up process.

Install it globally:

```bash
$ pub global activate crossdart
```

and then run as

```bash
$ pub global run crossdart:crossdart --sdkpath /path/to/dart-sdk --projectpath /path/to/your/project
```

It will generate the crossdart.json file, which you will need to put somewhere, for example, to S3 (see below).

Then, install Crossdart Chrome Extension from Chrome Web Store, and you are good to go.

Alternatively, you can add `crossdart` package as a dev dependency to your project:

```yaml
dev_dependencies:
  crossdart: any
```

and then run it as:

```bash
$ pub run crossdart:crossdart --sdkpath /path/to/dart-sdk --projectpath /path/to/your/project
```

## Uploading metadata

You need some publicly available place to store metadatas for every single commit for your project. I use S3 for that. It's cheap and relatively easy to configure.

You probably may want to create a separate bucket on S3 for crossdart metadata files, and then set correct CORS configuration for it. For that, click to the bucket in AWS S3 console, and in the "Properties" tab find "Add CORS Configuration". You can add something like this there:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CORSConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <CORSRule>
    <AllowedOrigin>*</AllowedOrigin>
    <AllowedMethod>GET</AllowedMethod>
  </CORSRule>
</CORSConfiguration>
```

To deliver your metadata files to S3, you can use s3cmd tool. Create a file `.s3cfg` with the contents:

```
[default]
access_key = YourAccessKey
secret_key = YourSecretKey
use_https = True
```

and then run `s3cmd` to put newly created file. Something like:

```bash
$ s3cmd -P -c ./.s3cfg put ./crossdart.json s3://my-bucket/my-project/32c139a7775736e96e476b1e0c89dd20e6588155/crossdart.json
```

The structure of the URL on S3 is important. It should always end with git sha and `crossdart.json`. Like above, the URL ends with `32c139a7775736e96e476b1e0c89dd20e6588155/crossdart.json`

## Integrating with Travis CI

Doing all the uploads to S3 manually is very cumbersome, so better to use some machinery, like CI or build server, to do that stuff for you. I personally use Travis CI for that. Here's how my configuration looks like:

`.travis.yml` file:

```yaml
language: dart
dart:
  - stable
install:
  # Here are other stuff to install
  - travis_retry sudo apt-get install --yes s3cmd
# ...
# Other sections if needed
# ...
after_success:
  - tool/crossdart_runner
```

`tool/crossdart_runner` file:

```bash
#!/bin/bash
#
# This script is invoked by Travis CI to generate Crossdart metadata for the Crossdart Chrome extension
if [ "$TRAVIS_PULL_REQUEST" != "false" ]
then
  CROSSDART_HASH="${TRAVIS_COMMIT_RANGE#*...}"
else
  CROSSDART_HASH="${TRAVIS_COMMIT}"
fi
echo "Installing crossdart"
pub global activate crossdart
echo "Generating metadata for crossdart"
pub global run crossdart:crossdart --sdkpath $DART_SDK --projectpath .
echo "Copying the crossdart json file to S3 ($CROSSDART_HASH)"
s3cmd -P -c ./.s3cfg put ./crossdart.json s3://my-bucket/my-project/$CROSSDART_HASH/crossdart.json
```

Now, every time somebody pushes to 'master', after Travis run, I'll have hyperlinked code of my project on Github.
And every time somebody creates a pull request for me on Github, it's code also going to be hyperlinked.

How cool is that! :)

## Setting up the Crossdart Chrome extension:

After installing Crossdart Chrome extension, you'll see a little "XD" icon in Chrome's URL bar on Github pages.
If you click to it, you'll see a little popup, where you can turn Crossdart on for the current project, and also
specify the URL where it should get the metadata files from. You only should provide a base for this URL, the extension
will later append git sha and 'crossdart.json' to it. I.e. if you specify URL in this field like:

```
https://my-bucket.s3.amazonaws.com/crossdart/my-project
```

then the extension will try to find crossdart.json files by URLs, which will look like:

```
https://my-bucket.s3.amazonaws.com/crossdart/my-project/4a9f8b41d042183116bbfaba31bdea109cc3080d/crossdart.json
```

If your project is private, you also will need to create access token, and paste it into the field in the popup as well.
You can do that there: https://github.com/settings/tokens/new.

## Contributing

Please use Github's bug tracker for bugs. Pull Requests are welcome.
