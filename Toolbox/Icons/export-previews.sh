#!/bin/sh
# Renders the Icon Composer icons in this folder into Assets.xcassets/Icon Previews,
# which the app icon picker in Settings shows. Run it again after editing an icon.
#
# The picker draws the tool glyph itself so it can move it when the device tilts, so
# every icon is exported without its glyph as "Background <name>" (light and dark), and
# the glyph is stored once as the vector image "Icon Glyph".

set -e
cd "$(dirname "$0")"

ICTOOL="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
PREVIEWS="../Assets.xcassets/Icon Previews"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

rm -rf "$PREVIEWS"
mkdir -p "$PREVIEWS"
printf '{\n  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n' > "$PREVIEWS/Contents.json"

for icon in *.icon; do
	name="Background ${icon%.icon}"
	set="$PREVIEWS/$name.imageset"
	mkdir -p "$set"

	# hide the glyph layers, keep everything else (fill, Pride stripes)
	rm -rf "$TMP/bg.icon"
	cp -R "$icon" "$TMP/bg.icon"
	python3 -I -c '
import json, sys
path = sys.argv[1]
icon = json.load(open(path))
for layer in icon["groups"][0]["layers"]:
    layer["hidden"] = True
json.dump(icon, open(path, "w"), indent=2)
' "$TMP/bg.icon/icon.json"

	for rendition in Default Dark; do
		"$ICTOOL" "$TMP/bg.icon" --export-image --output-file "$set/$rendition.png" \
			--platform iOS --rendition $rendition --width 220 --height 220 --scale 3 > /dev/null
	done

	cat > "$set/Contents.json" <<EOF
{
  "images" : [
    {
      "filename" : "Default.png",
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "Dark.png",
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

# the full primary icon for the launch screen, which can't draw an .icon file itself
launch="$PREVIEWS/Launch Icon.imageset"
mkdir -p "$launch"
for rendition in Default Dark; do
	for scale in 2 3; do
		"$ICTOOL" Toolbox.icon --export-image --output-file "$launch/$rendition@${scale}x.png" \
			--platform iOS --rendition $rendition --width 160 --height 160 --scale $scale > /dev/null
	done
done
cat > "$launch/Contents.json" <<EOF
{
  "images" : [
    {
      "filename" : "Default@2x.png",
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "Dark@2x.png",
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "filename" : "Default@3x.png",
      "idiom" : "universal",
      "scale" : "3x"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "Dark@3x.png",
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# both glyph layers in one SVG, same 160×160 canvas as in the .icon files
glyph="$PREVIEWS/Icon Glyph.imageset"
mkdir -p "$glyph"
{
	echo '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 160 160">'
	grep -ho '<path [^>]*>' Toolbox.icon/Assets/Toolbox1.svg Toolbox.icon/Assets/Toolbox2.svg | sed 's/ class="[^"]*"//'
	echo '</svg>'
} > "$glyph/Glyph.svg"
cat > "$glyph/Contents.json" <<EOF
{
  "images" : [
    {
      "filename" : "Glyph.svg",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "preserves-vector-representation" : true,
    "template-rendering-intent" : "template"
  }
}
EOF
