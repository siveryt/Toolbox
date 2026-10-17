# Screenshot hooks

Every executable file in these folders runs in name order (`10-foo.sh`, `20-bar.py`, ...) at the matching point of the pipeline. A non-zero exit aborts the lane.

| Folder | Runs after | `SCREENSHOTS_DIR` |
|---|---|---|
| `post_capture.d/` | iPhone/iPad capture, before frameit | `fastlane/screenshots` |
| `post_capture_watch.d/` | Watch capture | `fastlane/screenshots-watch` |
| `post_capture_duo.d/` | iPhone Duo capture | `fastlane/screenshots-duo` |
| `post_frame.d/` | frameit | `fastlane/screenshots` |
| `pre_upload.d/` | staging for `upload_screenshots`, before the upload | `fastlane/upload` |

Environment: `SCREENSHOTS_DIR`, `PROJECT_ROOT`, `HOOK_STAGE`. The working directory is the project root.

Files are laid out as `<SCREENSHOTS_DIR>/<language>/<device>-<name>.png`; frameit writes `..._framed.png` next to each original.

frameit has no Apple Watch frames, so `post_capture_watch.d/` is where a watch bezel script belongs.

frameit has no iPhone Duo bezel either: `post_capture_duo.d/10-layout` lays the Duo screenshots out like the framed ones (background, headline, title) at the size of the outer display. `post_frame.d/60-creative-assets` builds the product page header and search results images into `fastlane/creative-assets/<language>/`.
