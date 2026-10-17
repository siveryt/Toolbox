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

### ios app_store

```sh
[bundle exec] fastlane ios app_store
```

Everything for a release: all screenshots and images, then upload texts, screenshots, iPhone Duo screenshots and the header and search results images (needs ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH)

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Everything: capture iPhone, iPad, Watch and iPhone Duo, then frame (also builds the header and search results images)

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

### ios capture_duo

```sh
[bundle exec] fastlane ios capture_duo
```

Capture iPhone Duo screenshots (outer display) and lay them out like the framed ones

### ios frame

```sh
[bundle exec] fastlane ios frame
```

Add bezels, titles and backgrounds to the iPhone and iPad screenshots (layout: screenshots/Framefile.json)

### ios ppo_screenshots

```sh
[bundle exec] fastlane ios ppo_screenshots
```

Frame the screenshots again with the background and colors of every product page optimization variant in fastlane/ppo (run `screenshots` first)

### ios ppo_create_test

```sh
[bundle exec] fastlane ios ppo_create_test
```

Set up the product page optimization test from fastlane/ppo/variants.json with the ppo_screenshots images; doesn't submit or start it (needs ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH; dry_run:true only prints the plan)

### ios upload_metadata

```sh
[bundle exec] fastlane ios upload_metadata
```

Upload the App Store texts in fastlane/metadata to App Store Connect (needs ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH)

### ios upload_asset_library

```sh
[bundle exec] fastlane ios upload_asset_library
```

Upload the product page header and search results images through the App Asset Library API, which deliver doesn't support (needs ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH; dry_run:true only prints the plan)

### ios upload_screenshots

```sh
[bundle exec] fastlane ios upload_screenshots
```

Upload the framed iPhone, iPad and iPhone Duo and the Watch screenshots to App Store Connect (needs ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
