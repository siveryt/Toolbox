#!/bin/sh
# Renders every Icon Composer icon in this folder into a "Preview <name>" image set,
# which the app icon picker in Settings shows. Run it again after editing an icon.

set -e
cd "$(dirname "$0")"

ICTOOL="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
PREVIEWS="../Assets.xcassets/Icon Previews"

rm -rf "$PREVIEWS"
mkdir -p "$PREVIEWS"
printf '{\n  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n' > "$PREVIEWS/Contents.json"

for icon in *.icon; do
	name="Preview ${icon%.icon}"
	set="$PREVIEWS/$name.imageset"
	mkdir -p "$set"
	"$ICTOOL" "$icon" --export-image --output-file "$set/$name.png" \
		--platform iOS --rendition Default --width 180 --height 180 --scale 3 > /dev/null
	cat > "$set/Contents.json" <<EOF
{
  "images" : [
    {
      "filename" : "$name.png",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF
done
