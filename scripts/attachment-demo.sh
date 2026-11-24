#!/bin/sh
set -e
cd "$(dirname "$0")/.."
state=.temp/openspot
[ -d "$state/spots" ] || make dev-state >/dev/null
for source in selection browser-tab fresh-copy; do
  rm -rf "$state/spots/$source.spot"
  cp -R "spots/$source.spot" "$state/spots/"
done
files="$PWD/$state/demo-files"
mkdir -p "$files"
printf 'Invoice\n' > "$files/Invoice.txt"
printf 'Contract\n' > "$files/Contract.txt"
sips -s format png /System/Applications/Calculator.app/Contents/Resources/AppIcon.icns --out "$files/Picture.png" >/dev/null
sips -s format gif "$files/Picture.png" --out "$files/Moving.gif" >/dev/null
say -o "$files/Voice.aiff" "Openspot" >/dev/null
demo() {
  folder="$state/spots/$1.spot"
  rm -rf "$folder"
  mkdir -p "$folder"
  if [ -n "$5" ]; then
    printf 'title = "%s"\nicon = "%s"\nuses = ["attachment"]\n\n[on]\n"attachment.pick" = "%s"\n' "$2" "$3" "$5" > "$folder/spot.toml"
    printf '#!/bin/sh\ncase "$1" in\n  attachment.pick) openspot attachment add %s ;;\nesac\n' "$4" > "$folder/$1.sh"
  else
    printf 'title = "%s"\nicon = "%s"\nuses = ["attachment"]\n\n[on]\n"panel.open" = true\n' "$2" "$3" > "$folder/spot.toml"
    printf '#!/bin/sh\ncase "$1" in\n  show) openspot attachment add %s ;;\nesac\n' "$4" > "$folder/$1.sh"
  fi
  chmod +x "$folder/$1.sh"
}
demo demo-text "Demo Text" "text.quote" '"text=The quick brown fox jumps over the lazy dog" title="Selected text" app=com.apple.Safari'
demo demo-link "Demo Link" "link" 'url=https://developer.apple.com/design/human-interface-guidelines title="Human Interface Guidelines" app=com.apple.Safari' '^com\\.apple\\.Safari$'
demo demo-note "Demo Note" "note.text" '"text=Buy milk, call the bank, book the flight" title="Note" app=com.apple.Notes' '^com\\.apple\\.Notes$'
demo demo-mail "Demo Mail" "envelope" 'url=message://demo title="Re: Contract" app=com.apple.mail' '^com\\.apple\\.mail$'
demo demo-page "Demo Page" "doc.richtext" "file=$files/Contract.txt title=Contract app=com.apple.Preview" '^com\\.apple\\.Preview$'
demo demo-files "Demo Files" "folder" "file=$files/Invoice.txt file=$files/Contract.txt app=com.apple.finder"
demo demo-picture "Demo Picture" "photo" "file=$files/Picture.png app=com.apple.finder"
demo demo-gif "Demo GIF" "photo.stack" "file=$files/Moving.gif app=com.apple.finder"
demo demo-voice "Demo Voice" "waveform" "file=$files/Voice.aiff app=com.apple.finder"
folder="$state/spots/show-me.spot"
rm -rf "$folder"
mkdir -p "$folder"
printf 'title = "Show Me"\nicon = "eye"\ndetail = "Shows what it was handed"\n\n[actions.link]\ntitle = "Show the link"\noffers = ["attachments"]\ninputs.url = { type = "url", required = true }\n\n[actions.words]\ntitle = "Show the text"\noffers = ["attachments"]\ninputs.text = { type = "text", required = true }\n\n[on]\ndrop = ["*"]\n' > "$folder/spot.toml"
printf '#!/bin/sh\ncase "$1" in\n  show) printf "text=x\\\\ntitle=Show Me\\\\n" ;;\n  drop|link|words) openspot toast "$(grep "^input\\." | head -1 | cut -c 7-)" ;;\nesac\n' > "$folder/show-me.sh"
chmod +x "$folder/show-me.sh"
echo "Attachment demo is in $state/spots. Open the Debug panel and press Tab. make dev-state removes it."
