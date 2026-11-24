#!/bin/sh
set -e
cd "$(dirname "$0")/.."
state=.temp/openspot
[ -d "$state/spots" ] || make dev-state >/dev/null
for source in finder-selection browser-tab selected-text fresh-copy; do
  rm -rf "$state/spots/$source.spot"
  cp -R "spots/$source.spot" "$state/spots/"
done
files="$PWD/$state/demo-files"
mkdir -p "$files"
printf 'Invoice\n' > "$files/Invoice.txt"
printf 'Contract\n' > "$files/Contract.txt"
demo() {
  folder="$state/spots/$1.spot"
  rm -rf "$folder"
  mkdir -p "$folder"
  printf 'title = "%s"\nicon = "%s"\nuses = ["context"]\n\n[on]\n"panel.open" = true\n' "$2" "$3" > "$folder/spot.toml"
  printf '#!/bin/sh\ncase "$1" in\n  show) openspot context add %s ;;\nesac\n' "$4" > "$folder/$1.sh"
  chmod +x "$folder/$1.sh"
}
demo demo-text "Demo Text" "text.quote" '"text=The quick brown fox jumps over the lazy dog" title="Selected text" app=com.apple.Safari'
demo demo-link "Demo Link" "link" 'url=https://developer.apple.com/design/human-interface-guidelines title="Human Interface Guidelines" app=com.apple.Safari'
demo demo-note "Demo Note" "note.text" '"text=Buy milk, call the bank, book the flight" title="Note" app=com.apple.Notes'
demo demo-mail "Demo Mail" "envelope" 'url=message://demo title="Re: Contract" app=com.apple.mail'
demo demo-page "Demo Page" "doc.richtext" "file=$files/Contract.txt title=Contract app=com.apple.Preview"
demo demo-files "Demo Files" "folder" "file=$files/Invoice.txt file=$files/Contract.txt app=com.apple.finder"
folder="$state/spots/show-me.spot"
rm -rf "$folder"
mkdir -p "$folder"
printf 'title = "Show Me"\nicon = "eye"\ndetail = "Shows what it was handed"\n\n[on]\ndrop = ["url", "text", "*"]\n' > "$folder/spot.toml"
printf '#!/bin/sh\ncase "$1" in\n  show) printf "text=x\\\\ntitle=Show Me\\\\n" ;;\n  drop) openspot toast "$(grep "^input\\\\." | head -1 | cut -c 7-)" ;;\nesac\n' > "$folder/show-me.sh"
chmod +x "$folder/show-me.sh"
echo "Context demo is in $state/spots. Open the Debug panel and press Tab. make dev-state removes it."
