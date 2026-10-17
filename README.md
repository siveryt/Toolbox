# Toolbox

![GitHub commit activity](https://img.shields.io/github/commit-activity/m/siveryt/toolbox)


Toolbox is an OpenSource iOS App, that provides **a lot** of tools. The goal of Toolbox is to create one powerful app, that provides tools for nearly every situation. 

[![Download on the AppStore](assets/appstore.svg)](http://toolbox.sivery.de/download) 

## Contribution
I'm happy about **every** contribution! You can contribute to things like, Localization or you could also add whole new features. If your changes are good you will be merged into the main branch. If you aren't sure if your idea would be merged, just contact me .
Read more about how you can contribute [here](http://toolbox.sivery.de/contribution.html).

If you have any ideas for new tools, let me know via [E-Mail](mailto:toolbox@sivery.de)


## Releasing

### TestFlight
Every push to `main` that touches the app builds it and uploads it to TestFlight via GitHub Actions ([testflight.yml](.github/workflows/testflight.yml)), including generated "What to Test" notes in English and German. Changes only to `web/`, `fastlane/`, the README or the Gemfile don't trigger a build. Setup of secrets, certificate and API key: [docs/actions/Setup Testflight.md](docs/actions/Setup%20Testflight.md).

Run it by hand (a manual run is a dry run unless you say otherwise):

```bash
gh workflow run testflight.yml
gh workflow run testflight.yml -f dry_run=false
```

### App Store
Everything around the App Store version — texts, screenshots and images — is done with fastlane. It needs ImageMagick, the App Store Connect API key and a version in *Prepare for Submission* in App Store Connect.

```bash
brew install imagemagick
bundle install
```

Put the API key into `fastlane/.env` (git-ignored, read by fastlane automatically) and the `.p8` file somewhere outside the repository:

```
ASC_KEY_ID=ABC123XYZ
ASC_ISSUER_ID=12345678-aaaa-bbbb-cccc-1234567890ab
ASC_KEY_PATH=/Users/you/.appstoreconnect/private_keys/AuthKey_ABC123XYZ.p8
```

Then one command creates every screenshot and image and uploads it all:

```bash
LANG=en_US.UTF-8 bundle exec fastlane app_store
```

The steps are separate lanes as well (prefix each with `LANG=en_US.UTF-8 bundle exec fastlane`):

| Lane | What it does | Output |
|---|---|---|
| `screenshots` | `capture`, `capture_watch`, `capture_duo`, then `frame` | |
| `capture` | iPhone and iPad screenshots (devices and languages: `fastlane/Snapfile`) | `fastlane/screenshots/` |
| `capture_watch` | Apple Watch screenshots, raw without bezel | `fastlane/screenshots-watch/` |
| `capture_duo` | iPhone Duo screenshots (outer display), laid out like the framed ones | `fastlane/screenshots-duo/` |
| `frame` | Bezels, titles and backgrounds (layout: `fastlane/screenshots/Framefile.json`); also builds the product page header and search results images | `*_framed.png`, `fastlane/creative-assets/` |
| `upload_metadata` | Name, subtitle, keywords, description and What's New from `fastlane/metadata/` | |
| `upload_screenshots` | iPhone, iPad and Watch screenshots (replaces the existing ones) | |
| `upload_asset_library` | iPhone Duo screenshots, header and search results images via the App Asset Library API; add `dry_run:true` to only print the plan | |

Selecting the build and submitting the version for review stays manual in App Store Connect.

Custom scripts that run between the steps go into [fastlane/hooks/](fastlane/hooks/README.md). The `frame` lane also puts the English iPhone main screen on the website (`web/assets/mainscreen.webp`); commit the updated image to publish it.

### Translations
Translations happen on [Crowdin](https://crowdin.com/project/toolbox), which syncs with this repository and opens "New Crowdin updates" pull requests from the `crowdin` branch. Review and merge them; Crowdin creates the branch again for the next update.

### App icons
The icons are Icon Composer files in `Toolbox/Icons/`. After adding or editing one, regenerate the previews the icon picker shows:

```bash
Toolbox/Icons/export-previews.sh
```

## Website
The website in `web/` is static HTML served by nginx. Build and run it locally with Docker:

```bash
docker build -t toolbox-web web
docker run --rm -p 8080:80 toolbox-web
```

Then open http://localhost:8080.

Every push to `main` that changes `web/` rebuilds the image via GitHub Actions ([web.yml](.github/workflows/web.yml)) and publishes it to the GitHub Container Registry. To rebuild it by hand: `gh workflow run web.yml`. On the server:

```bash
docker run -d --name toolbox-web --restart unless-stopped -p 8080:80 ghcr.io/siveryt/toolbox-web:latest
```
