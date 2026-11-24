#!/bin/sh
# Wishes: keeps product links with their name, picture and price, and shares them as a list.
# The list is Wishes.md, in the folder of the setting Keep in, or else in $OPENSPOT_DATA. markdown.pl reads each wish of
# it as one line: id, type, price, currency, title, link, picture, notes, and writes such lines back as Wishes.md.
export LC_ALL=en_US.UTF-8
. "$OPENSPOT_SH"

here=$(dirname "$0")
folder=$(value setting.folder)
case "$folder" in "~") folder=$HOME ;; "~/"*) folder="$HOME/${folder#"~/"}" ;; esac
[ -n "$folder" ] || folder=$OPENSPOT_DATA
book="$folder/Wishes.md"
tab=$(printf '\t')
agent='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15'

list() { [ -f "$book" ] && perl "$here/markdown.pl" read < "$book"; }
link() { grep -Eo 'https?://[^[:space:]<>"]+' | head -n 1; }
clean() { printf '%s' "$1" | tr '\t\n\r' '   ' | sed 's/^ *//; s/ *$//'; }
field() { list | awk -F'\t' -v id="$1" -v n="$2" '$1 == id { print $n; exit }'; }
builtin() { printf 'Books\nClothes\nGadgets\nHome\nBeauty\nToys\nSports\nOther\n'; }
own() {
  if [ -f "$book" ]; then perl "$here/markdown.pl" types < "$book"; fi | awk -v B="$(builtin | tr '\n' '|')" 'BEGIN { split(B, a, "|"); for (i in a) b[a[i]] = 1 } NF && !b[$0] && !seen[$0]++'
}
types() { { builtin; own; } | awk 'NF && !seen[$0]++'; }
# The folder of the list as people read it, with ~ for the home folder.
where() { case "$folder" in "$HOME"/*) printf '~/%s' "${folder#"$HOME"/}" ;; *) printf '%s' "$folder" ;; esac; }
# save [own types]: writes the wishes on stdin as Wishes.md, with these own types, or else with those of the list as it is.
save() {
  if [ $# -gt 0 ]; then own=$1; else own=$(own); fi
  [ -d "$folder" ] && perl "$here/markdown.pl" write "$(builtin | tr '\n' '|')" "$own" | openspot_keep "$book" && return 0
  openspot toast "Wishes can't write Wishes.md in $(where). Choose another folder under Keep in, in its Settings."
  exit 1
}
# The id of the wish with the link <link>.
found() { list | U="$1" awk -F'\t' '$6 == ENVIRON["U"] { print $1; exit }'; }
hex() { printf '%s' "$1" | od -An -tx1 | tr -d ' \n'; }
unhex() { printf '%s' "$1" | perl -pe 's/([0-9a-f]{2})/chr hex $1/ge'; }

# Prints each wish with its section, in the order of the list:
# three sort keys, section, id, title, price, shop, icon, link, type.
arrange() {
  list | awk -F'\t' -v OFS='\t' -v group="$1" '
    function money(p, c,   s) {
      s = sprintf("%.2f", p); sub(/\.00$/, "", s)
      if (c in pre) return pre[c] s
      if (c in post) return s " " post[c]
      return c == "" ? s : s " " c
    }
    function range(p, c,   m) {
      m = (c in mult) ? mult[c] : 1
      if (p < 25 * m) { key = 1; return "Under " money(25 * m, c) }
      if (p < 50 * m) { key = 2; return money(25 * m, c) " – " money(50 * m, c) }
      if (p < 100 * m) { key = 3; return money(50 * m, c) " – " money(100 * m, c) }
      if (p < 250 * m) { key = 4; return money(100 * m, c) " – " money(250 * m, c) }
      if (p < 500 * m) { key = 5; return money(250 * m, c) " – " money(500 * m, c) }
      key = 6; return "Over " money(500 * m, c)
    }
    BEGIN {
      pre["USD"] = "$"; pre["EUR"] = "€"; pre["GBP"] = "£"; pre["JPY"] = "¥"; pre["CAD"] = "CA$"; pre["AUD"] = "A$"
      pre["INR"] = "₹"; pre["KRW"] = "₩"; post["UAH"] = "₴"; post["PLN"] = "zł"
      mult["UAH"] = 40; mult["PLN"] = 4; mult["JPY"] = 200; mult["INR"] = 100; mult["KRW"] = 1000
      mult["CZK"] = 20; mult["SEK"] = 10; mult["NOK"] = 10; mult["DKK"] = 10; mult["HUF"] = 400
      order["Books"] = 1; order["Clothes"] = 2; order["Gadgets"] = 3; order["Home"] = 4; order["Beauty"] = 5
      order["Toys"] = 6; order["Sports"] = 7; order["Other"] = 99
      icon["Books"] = "book"; icon["Clothes"] = "tshirt"; icon["Gadgets"] = "headphones"; icon["Home"] = "sofa"
      icon["Beauty"] = "sparkles"; icon["Toys"] = "puzzlepiece"; icon["Sports"] = "figure.run"
    }
    NF >= 6 {
      type = $2 == "" ? "Other" : $2
      price = $3 == "" ? "" : money($3, $4)
      shop = $6; sub(/^[a-z]+:\/\//, "", shop); sub(/^www\./, "", shop); sub(/[\/?#].*/, "", shop)
      picture = $7 ~ /^https:\/\// ? $7 : (type in icon ? icon[type] : "gift")
      if (group == "Price") {
        if ($3 == "") { key = 9; section = "No price" } else section = range($3 + 0, $4)
        print key, $4, $3 + 0, section, $1, $5, price, shop, picture, $6, type, $8
      } else
        print (type in order ? order[type] : 50), type, -NR, type, $1, $5, price, shop, picture, $6, type, $8
    }' | sort -t "$tab" -k1,1n -k2,2 -k3,3n
}

show() {
  group=$(value setting.group)
  [ "$group" = Price ] || group=Type
  count=$(list | grep -c .)
  printf 'frame=\nrecents=false\n'
  [ "$count" -eq 1 ] && printf 'detail=1 wish\n'
  [ "$count" -gt 1 ] && printf 'detail=%s wishes\n' "$count"
  printf '\nfield=search\ntype=search\nplaceholder=Search wishes\n'
  printf '\nitems=items\n\nitem=add\nparent=items\ntitle=Add wish\nicon=plus.circle.fill\npin=top\nclose=false\nopen.title=Add Wish\nopen.wait=Reading the page\nhides=edit\nhides=remove\n'
  [ "$count" -eq 0 ] && printf 'detail=Press Return, then paste a product link\n'
  [ -d "$folder" ] || printf "\nitem=lost\nparent=items\ntitle=Wishes can't find %s\ndetail=Choose another folder under Keep in, in the Settings of Wishes\nicon=exclamationmark.triangle\ntone=warn\npin=top\nhides=edit\nhides=remove\n" "$(esc "$(where)")"
  printf '\n'
  [ "$count" -eq 0 ] && return
  arrange "$group" | awk -F'\t' -v group="$group" '
    function e(s) { gsub(/\\/, "\\\\", s); return s }
    $4 != last { last = $4; printf "box=s%d\nparent=items\ntitle=%s\n\n", ++sections, e($4) }
    {
      detail = $7
      if (group == "Price") detail = detail (detail == "" ? "" : " · ") $11
      detail = detail (detail == "" ? "" : " · ") $8
      if ($12 != "") detail = detail " · " $12
      printf "item=%s\nparent=s%d\ntitle=%s\ndetail=%s\nicon=%s\nurl=%s\nkeywords=%s,%s\nopen.title=Open in Browser\n\n", \
        $5, sections, e($6), e(detail), e($9), e($10), e($8), e($11)
    }'
  if [ "$group" = Price ]; then by='by price range'; else by='by type'; fi
  printf 'item=share\nparent=items\ntitle=Share list\ndetail=Copies your wishes as text, %s\nicon=square.and.arrow.up\npin=bottom\nopen.title=Copy List\nhides=edit\nhides=remove\n\n' "$by"
  printf 'button=edit\nparent=items\ntitle=Edit\nicon=pencil\nshortcut=cmd+e\nclose=false\nwait=Reading the page\n\n'
  printf 'button=remove\nparent=items\ntitle=Remove\nicon=trash\nshortcut=cmd+backspace\nconfirm=Press again to remove this wish\nclose=false\n'
}

# A link with no tracking words, such as utm_source or gclid, so that a shared list is short.
untrack() {
  perl -pe 'if (/^([^?#]*)\?([^#]*)(.*)$/s) { my ($a, $q, $z) = ($1, $2, $3); $q = join "&", grep { !/^(utm_\w+|gclid|gbraid|wbraid|gad_\w+|fbclid|yclid|msclkid|mc_[ce]id|_ga|_gl|srsltid)=/i } split /&/, $q; $_ = $a . ($q eq "" ? "" : "?$q") . $z }'
}

# Reads the page of a link, and prints one line: title, price, currency, picture, type, read, and the browser whose
# open tab it read, with "file", "html" or "title" before it. A shop that hides its page from programs is read from a
# tab of the same link, open in the person's browser.
fetch() {
  page=$(curl -sL --compressed --max-time 12 -A "$agent" -H 'Accept: text/html,application/xhtml+xml' \
    -H 'Accept-Language: en-US,en;q=0.9' "$1" </dev/null | head -c 4000000 | perl "$here/page.pl" "$1" 2>/dev/null)
  from=
  for how in sent whole; do
    [ "$(printf '%s\n' "$page" | cut -f6)" != 1 ] || break
    saved=$(mktemp -d)
    open=$(perl -e 'alarm 60; exec @ARGV' osascript -l JavaScript "$here/tab.js" "$1" "$saved/page.html" "$how" 2>/dev/null)
    from=$(printf '%s\n' "$open" | head -n 1)
    case "$from" in
      file\ *)
        size=-1
        for wait in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
          now=$(wc -c 2>/dev/null < "$saved/page.html" | tr -d ' ')
          [ -n "$now" ] && [ "$now" -gt 0 ] && [ "$now" = "$size" ] && break
          size=${now:--1}
          perl -e 'select undef, undef, undef, 0.5'
        done
        if [ -s "$saved/page.html" ]; then page=$(perl "$here/page.pl" "$1" < "$saved/page.html" 2>/dev/null); fi
        ;;
      ?*) page=$(printf '%s\n' "$open" | tail -n +2 | perl "$here/page.pl" "$1" 2>/dev/null); rm -rf "$saved"; break ;;
      *) rm -rf "$saved"; break ;;
    esac
    rm -rf "$saved"
  done
  printf '%s\t%s\n' "${page:-$tab$tab$tab${tab}Other${tab}0}" "$from"
}

# Prints the form of a wish: its title, link, name, price, currency, type, picture, whether the page was read, from
# where, and its notes. A new wish and an edit share it, so each value is changed in one place.
wishform() {
  printf 'frame=\ntype=form\n'
  openspot_kv title "$1"
  printf '\nfield=link\ntitle=Link\nrequired=true\n'
  openspot_kv value "$2"
  printf '\nfield=name\ntitle=Name\nrequired=true\nplaceholder=What it is\n'
  if [ -n "$3" ]; then openspot_kv value "$3"; fi
  if [ "$8" = 0 ]; then printf 'detail=From the link: the shop hides its page. Open it in your browser, then try again.\ntone=warn\n'; fi
  printf '\nfield=price\ntitle=Price\n'
  if [ -n "$4" ]; then
    openspot_kv value "$4${5:+ $5}"
  else
    guess=$(region)
    openspot_kv placeholder "Such as 250${guess:+ $guess}"
    case "$9" in
      title\ *) openspot_kv detail "To read the price, turn on Allow JavaScript from Apple Events in ${9#title }."; printf 'tone=warn\n' ;;
      *) if [ "$8" = 1 ]; then printf 'detail=The page shows no price.\n'; fi ;;
    esac
  fi
  printf '\nfield=notes\ntitle=Notes\nplaceholder=Such as size M or a colour\n'
  if [ -n "${10}" ]; then openspot_kv value "${10}"; fi
  printf '\nchoice=type\ntitle=Type\n'
  openspot_kv value "t$(hex "${6:-Other}")"
  { types; printf '%s\n' "${6:-Other}"; } | awk 'NF && !seen[$0]++' | while IFS= read -r one; do
    printf '\noption=t%s\n' "$(hex "$one")"
    openspot_kv title "$one"
    builtin | grep -qxF -- "$one" || printf 'remove=true\n'
  done
  printf '\noption=types\ntitle=Add type…\nicon=plus\nsend=true\n'
  printf '\nfield=picture\ntitle=Picture\nplaceholder=A link to an image\n'
  if [ -n "$7" ]; then openspot_kv value "$7"; fi
}

# Keeps the values of a sent form as the wish <id>, a new one or one that is there, in its place in the list.
# keep <id> <currency of the page>
keep() {
  url=$(clean "$(value input.link)" | link | untrack)
  given=$(perl "$here/page.pl" --price "$(value input.price)" 2>/dev/null)
  price=$(printf '%s\n' "$given" | cut -f1)
  currency=$(printf '%s\n' "$given" | cut -f2)
  [ -n "$currency" ] || currency=$2
  [ -n "$currency" ] || currency=$(region)
  [ -n "$price" ] || currency=
  forget
  picked=$(value input.type)
  type=$(unhex "${picked#t}")
  picture=$(clean "$(value input.picture)")
  case "$picture" in https://*) ;; http://*) picture="https://${picture#http://}" ;; *) picture= ;; esac
  notes=$(clean "$(value input.notes)")
  line=$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s' "$1" "${type:-Other}" "$price" "$currency" "$name" "$url" "$picture" "$notes")
  { list | L="$line" awk -F'\t' -v id="$1" '$1 == id { print ENVIRON["L"]; found = 1; next } { print } END { if (!found) print ENVIRON["L"] }'; } \
    | save
  rm -f "$OPENSPOT_DATA/draft"
}

# Deletes each type of your own that ⌘⌫ took out of the Type list, and moves its wishes to Other.
forget() {
  gone=$(value input.type.removed)
  [ -n "$gone" ] || return 0
  drop=$(printf '%s\n' "$gone" | while IFS= read -r id; do [ -n "$id" ] && unhex "${id#t}" && echo; done)
  kept=$(own | D="$drop" awk 'BEGIN { n = split(ENVIRON["D"], a, "\n"); for (i = 1; i <= n; i++) d[a[i]] = 1 } !d[$0]')
  list | D="$drop" awk -F'\t' -v OFS='\t' 'BEGIN { n = split(ENVIRON["D"], a, "\n"); for (i = 1; i <= n; i++) d[a[i]] = 1 } d[$2] { $2 = "Other" } { print }' \
    | save "$kept"
}

# Add type… in the Type list: the values of the wish wait in $OPENSPOT_DATA/draft while a form of one field asks for
# the new type, then the wish comes back with it chosen.
# retype <the wish, add or its id> <title of its form>, which prints a form and succeeds when the call was one of these.
retype() {
  draft="$OPENSPOT_DATA/draft"
  if [ "$(value input.type)" = types ]; then
    forget
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$(clean "$(value input.link)")" "$(clean "$(value input.name)")" \
      "$(clean "$(value input.price)")" "$(clean "$(value input.picture)")" "$(clean "$(value input.notes)")" | openspot_keep "$draft"
    printf 'frame=\ntype=form\ntitle=New type\n\nfield=newtype\ntitle=Name\nplaceholder=Such as Plants\nrequired=true\n'
    return 0
  fi
  new=$(clean "$(value input.newtype)")
  [ -n "$new" ] && [ -s "$draft" ] && [ "$(cut -f1 < "$draft")" = "$1" ] || return 1
  kept=$({ own; printf '%s\n' "$new"; } | awk -v B="$(builtin | tr '\n' '|')" 'BEGIN { split(B, a, "|"); for (i in a) b[a[i]] = 1 } NF && !b[$0] && !seen[$0]++')
  list | save "$kept"
  at() { cut -f"$(($1 + 1))" < "$draft"; }
  wishform "$2" "$(at 1)" "$(at 2)" "$(at 3)" '' "$new" "$(at 4)" '' '' "$(at 5)"
}

# The form of a new wish. It asks for the link, then shows what the page gave, to change before it is kept.
# The page that it read last waits in $OPENSPOT_DATA/page: the link, then the line that fetch prints.
add() {
  retype add 'New wish' && return
  typed=$(clean "$(value input.link)")
  [ -n "$typed" ] || typed=$(clean "$(value input.search)")
  url=$(printf '%s\n' "$typed" | link | untrack)
  if [ -z "$url" ]; then
    printf 'frame=\ntype=form\ntitle=New wish\n\nfield=link\ntitle=Link\nplaceholder=Paste a product link\nrequired=true\n'
    if [ -n "$typed" ]; then printf 'detail=A link starts with https://\ntone=warn\n'; fi
    return
  fi
  there=$(found "$url")
  if [ -n "$there" ]; then
    openspot select "$there"
    openspot toast 'This link is already in your wishes.'
    return
  fi
  read=$(cat "$OPENSPOT_DATA/page" 2>/dev/null)
  name=$(clean "$(value input.name)")
  if [ "$(printf '%s\n' "$read" | cut -f1)" != "$url" ]; then
    read=$(printf '%s\t%s' "$url" "$(fetch "$url")")
    printf '%s\n' "$read" | openspot_keep "$OPENSPOT_DATA/page"
    name=
  fi
  if [ -z "$name" ]; then
    at() { printf '%s\n' "$read" | cut -f"$1"; }
    wishform 'New wish' "$url" "$(at 2)" "$(at 3)" "$(at 4)" "$(at 6)" "$(at 5)" "$(at 7)" "$(at 8)"
    return
  fi
  id="w$(date +%s)$$"
  keep "$id" "$(printf '%s\n' "$read" | cut -f4)"
  rm -f "$OPENSPOT_DATA/page"
  openspot select "$(found "$url")"
}

# The form of a wish that is there, with each of its values. A wish that lacks its picture, its price or a name of its
# own, one taken from its link, reads its page again for them.
edit() {
  [ -n "$1" ] || return
  [ -n "$(field "$1" 1)" ] || return
  retype "$1" 'Edit wish' && return
  name=$(clean "$(value input.name)")
  if [ -n "$name" ]; then
    keep "$1" "$(field "$1" 4)"
    openspot select "$(found "$url")"
    return
  fi
  url=$(field "$1" 6)
  name=$(field "$1" 5)
  price=$(field "$1" 3)
  currency=$(field "$1" 4)
  picture=$(field "$1" 7)
  bare=$(printf '' | perl "$here/page.pl" "$url" 2>/dev/null | cut -f1)
  if [ -z "$picture" ] || [ -z "$price" ] || [ "$name" = "$bare" ]; then
    page=$(fetch "$url")
    if [ "$(printf '%s\n' "$page" | cut -f6)" = 1 ]; then
      [ "$name" != "$bare" ] || name=$(printf '%s\n' "$page" | cut -f1)
      if [ -z "$price" ]; then
        price=$(printf '%s\n' "$page" | cut -f2)
        currency=$(printf '%s\n' "$page" | cut -f3)
      fi
    fi
    [ -n "$picture" ] || picture=$(printf '%s\n' "$page" | cut -f4)
  fi
  wishform 'Edit wish' "$url" "$name" "$price" "$currency" "$(field "$1" 2)" "$picture" '' '' "$(field "$1" 8)"
}

# The currency of a price typed with none: the one of the shop's country, or else of the Mac's region.
region() {
  case "$(printf '%s' "${url:-}" | sed 's|^[a-z]*://||; s|[/:?#].*||; s|.*\.||')" in
    ua) echo UAH; return ;; pl) echo PLN; return ;; uk) echo GBP; return ;; jp) echo JPY; return ;; cz) echo CZK; return ;;
    de|fr|es|it|nl|be|at|ie|pt|fi|gr|ee|lv|lt|sk|si|lu|hr|eu) echo EUR; return ;;
  esac
  case "$(defaults read -g AppleLocale 2>/dev/null | sed 's/@.*//; s/.*_//')" in
    US) echo USD ;; UA) echo UAH ;; GB) echo GBP ;; PL) echo PLN ;; JP) echo JPY ;; CA) echo CAD ;; AU) echo AUD ;;
    CH) echo CHF ;; SE) echo SEK ;; NO) echo NOK ;; DK) echo DKK ;; CZ) echo CZK ;; IN) echo INR ;; KR) echo KRW ;;
    DE|FR|ES|IT|NL|BE|AT|IE|PT|FI|GR|EE|LV|LT|SK|SI|LU|MT|CY|HR) echo EUR ;;
  esac
}

share() {
  arrange "$1" | awk -F'\t' '
    BEGIN { print "My wishlist" }
    $4 != last { last = $4; printf "\n%s\n", $4 }
    { printf "• %s%s\n", $6, ($7 == "" ? "" : " — " $7); if ($12 != "") printf "  Note: %s\n", $12; printf "  %s\n", $10 }' | openspot clipboard copy \
    && openspot toast 'Copied your list. Paste it into a message.'
}

# Keep in, in the Settings of Wishes: asks for a folder and keeps the list there. A folder that holds a Wishes.md already
# keeps its own list, and the one here stays as it is. Else the list moves into the folder.
move() {
  picked=$(openspot folder pick) || exit 1
  [ -n "$picked" ] && [ "$picked" != "$folder" ] || return 0
  moves=
  if [ ! -f "$picked/Wishes.md" ] && [ -f "$book" ]; then
    openspot_keep "$picked/Wishes.md" "$(cat "$book")
" || { openspot toast "Wishes can't write Wishes.md in $picked."; exit 1; }
    moves=1
  fi
  old=$book
  folder=$picked
  openspot setting set folder "$(where)" || exit 1
  [ -z "$moves" ] || rm -f "$old"
  if [ -n "$moves" ]; then openspot toast "Moved your list to $(where)/Wishes.md."; else openspot toast "Wishes now reads $(where)/Wishes.md."; fi
}

# The list of an older Wishes, wishes.tsv with its own types in types, comes into Wishes.md once, and stays as it was.
old="$OPENSPOT_DATA/wishes.tsv"
if [ -d "$folder" ] && [ ! -f "$book" ] && [ -s "$old" ] && [ ! -e "$OPENSPOT_DATA/imported" ]; then
  save "$(cat "$OPENSPOT_DATA/types" 2>/dev/null)" < "$old" && : > "$OPENSPOT_DATA/imported"
fi

item=$(value input.item)
case "$1" in
  show) show ;;
  press)
    case "$item" in
      add) add ;;
      share) if [ "$(value setting.group)" = Price ]; then share Price; else share Type; fi ;;
      *)
        url=$(value item.url)
        [ -n "$url" ] || url=$(field "$item" 6)
        if [ -n "$url" ]; then open "$url"; fi
        ;;
    esac
    ;;
  edit) edit "$item" ;;
  remove) if [ -n "$item" ]; then list | awk -F'\t' -v id="$item" '$1 != id' | save; fi ;;
  folder) move ;;
esac
