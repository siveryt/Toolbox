# Toolbox

![GitHub commit activity](https://img.shields.io/github/commit-activity/m/siveryt/toolbox)


Toolbox is an OpenSource iOS App, that provides **a lot** of tools. The goal of Toolbox is to create one powerful app, that provides tools for nearly every situation. 

[![Download on the AppStore](assets/appstore.svg)](http://toolbox.sivery.de/download) 

## Contribution
I'm happy about **every** contribution! You can contribute to things like, Localization or you could also add whole new features. If your changes are good you will be merged into the main branch. If you aren't sure if your idea would be merged, just contact me .
Read more about how you can contribute [here](http://toolbox.sivery.de/contribution.html).

If you have any ideas for new tools, let me know via [E-Mail](mailto:toolbox@sivery.de)


## Screenshots
The App Store screenshots are generated with fastlane: snapshot drives the UI tests in `ToolboxUITests/` and `ToolboxWatchUITests/`, frameit adds bezels, titles and backgrounds.

```bash
bundle install
bundle exec fastlane screenshots
```

This captures iPhone, iPad and Apple Watch and frames the results. The single steps are available as separate lanes:

| Lane | What it does | Output |
|---|---|---|
| `capture` | iPhone and iPad screenshots (devices and languages: `fastlane/Snapfile`) | `fastlane/screenshots/` |
| `capture_watch` | Apple Watch screenshots, raw without bezel | `fastlane/screenshots-watch/` |
| `frame` | Bezels, titles and backgrounds (layout: `fastlane/screenshots/Framefile.json`) | `*_framed.png` next to the originals |
| `upload_screenshots` | Upload to App Store Connect (needs `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH`) | |

Custom scripts that run between the steps go into [fastlane/hooks/](fastlane/hooks/README.md).

## Website
The website in `web/` is static HTML served by nginx. Build and run it locally with Docker:

```bash
docker build -t toolbox-web web
docker run --rm -p 8080:80 toolbox-web
```

Then open http://localhost:8080.

Every push to `main` that changes `web/` rebuilds the image via GitHub Actions ([web.yml](.github/workflows/web.yml)) and publishes it to the GitHub Container Registry:

```bash
docker run -d --name toolbox-web --restart unless-stopped -p 8080:80 ghcr.io/siveryt/toolbox-web:latest
```
