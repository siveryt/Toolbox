fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Everything: capture iPhone, iPad and Watch, then frame

### ios capture

```sh
[bundle exec] fastlane ios capture
```

Capture iPhone and iPad screenshots (devices and languages: Snapfile)

### ios capture_watch

```sh
[bundle exec] fastlane ios capture_watch
```

Capture Apple Watch screenshots (raw, no bezel)

### ios frame

```sh
[bundle exec] fastlane ios frame
```

Add bezels, titles and backgrounds to the iPhone and iPad screenshots (layout: screenshots/Framefile.json)

### ios upload_screenshots

```sh
[bundle exec] fastlane ios upload_screenshots
```

Upload the framed iPhone/iPad and the Watch screenshots to App Store Connect (needs ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
