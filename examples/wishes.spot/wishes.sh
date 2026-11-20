#!/bin/sh
# Wishes: keeps product links with their name, picture and price, and shares them as a list.
# Each wish is one line of $OPENSPOT_DATA/wishes.tsv: id, type, price, currency, title, link, picture.
export LC_ALL=en_US.UTF-8
. "$OPENSPOT_SH"

here=$(dirname "$0")
data="$OPENSPOT_DATA/wishes.tsv"
tab=$(printf '\t')
agent='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15'

list() { [ -f "$data" ] && cat "$data"; }
link() { grep -Eo 'https?://[^[:space:]<>"]+' | head -n 1; }
clean() { printf '%s' "$1" | tr '\t\n\r' '   ' | sed 's/^ *//; s/ *$//'; }
field() { list | awk -F'\t' -v id="$1" -v n="$2" '$1 == id { print $n; exit }'; }
kinds="$OPENSPOT_DATA/types"
types() {
  if [ -f "$kinds" ]; then cat "$kinds"; else { printf 'Books\nClothes\nGadgets\nHome\nBeauty\nToys\nSports\nOther\n'; list | cut -f2; }; fi | awk 'NF && !seen[$0]++'
}
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
        print key, $4, $3 + 0, section, $1, $5, price, shop, picture, $6, type
      } else
        print (type in order ? order[type] : 50), type, -NR, type, $1, $5, price, shop, picture, $6, type
    }' | sort -t "$tab" -k1,1n -k2,2 -k3,3n
}

show() {
  group=$(value setting.group)
  [ "$group" = Price ] || group=Type
  count=$(list | grep -c .)
  printf 'frame=\nrecents=false\n'
  [ "$count" -eq 1 ] && printf 'detail=1 wish\n'
  [ "$count" -gt 1 ] && printf 'detail=%s wishes\n' "$count"
  printf '\ntext=add\ntitle=Add wish\nicon=plus.circle.fill\npin=top\nform=true\nclose=false\nopen.title=Add Wish\nhides=edit\nhides=remove\n'
  [ "$count" -eq 0 ] && printf 'detail=Press Return, then paste a product link\n'
  printf '\n'
  [ "$count" -eq 0 ] && return
  arrange "$group" | awk -F'\t' -v group="$group" '
    function e(s) { gsub(/\\/, "\\\\", s); return s }
    $4 != last { last = $4; printf "section=s%d\ntitle=%s\n\n", ++sections, e($4) }
    {
      detail = $7
      if (group == "Price") detail = detail (detail == "" ? "" : " · ") $11
      detail = detail (detail == "" ? "" : " · ") $8
      printf "text=%s\ntitle=%s\ndetail=%s\nicon=%s\nurl=%s\nkeywords=%s,%s\nopen.title=Open in Browser\n\n", \
        $5, e($6), e(detail), e($9), e($10), e($8), e($11)
    }'
  if [ "$group" = Price ]; then by='by price range'; else by='by type'; fi
  printf 'text=share\ntitle=Share list\ndetail=Copies your wishes as text, %s\nicon=square.and.arrow.up\npin=bottom\nopen.title=Copy List\nhides=edit\nhides=remove\n\n' "$by"
  printf 'button=edit\ntitle=Edit\nicon=pencil\nshortcut=cmd+e\nform=true\nclose=false\n\n'
  printf 'button=remove\ntitle=Remove\nicon=trash\nshortcut=cmd+backspace\nconfirm=Press again to remove this wish\nclose=false\n'
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

# Prints the form of a wish: its title, link, name, price, currency, type, picture, whether the page was read, and from
# where. A new wish and an edit share it, so each value is changed in one place.
wishform() {
  printf 'frame=\n'
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
  printf '\nchoice=type\ntitle=Type\n'
  openspot_kv value "t$(hex "${6:-Other}")"
  { types; printf '%s\n' "${6:-Other}"; } | awk 'NF && !seen[$0]++' | while IFS= read -r one; do
    printf '\noption=t%s\n' "$(hex "$one")"
    openspot_kv title "$one"
  done
  printf '\noption=types\ntitle=Edit types…\n'
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
  picked=$(value input.type)
  type=$(unhex "${picked#t}")
  picture=$(clean "$(value input.picture)")
  case "$picture" in https://*) ;; http://*) picture="https://${picture#http://}" ;; *) picture= ;; esac
  line=$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s' "$1" "${type:-Other}" "$price" "$currency" "$name" "$url" "$picture")
  { list | L="$line" awk -F'\t' -v id="$1" '$1 == id { print ENVIRON["L"]; found = 1; next } { print } END { if (!found) print ENVIRON["L"] }'; } \
    | openspot_keep "$data" || exit 1
  rm -f "$OPENSPOT_DATA/draft"
}

# Edit types… in the menu of a wish's type: the values of the wish wait in $OPENSPOT_DATA/draft while a form adds a
# type and takes out the ones that are unticked, then the wish comes back with the new type chosen.
# retype <the wish, add or its id> <title of its form> <its type before>, which prints a form and succeeds when the call
# was one of these. A draft waits ten minutes for its Types form.
retype() {
  draft="$OPENSPOT_DATA/draft"
  if [ "$(value input.type)" = types ]; then
    printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$(clean "$(value input.link)")" "$(clean "$(value input.name)")" \
      "$(clean "$(value input.price)")" "$(clean "$(value input.picture)")" | openspot_keep "$draft"
    printf 'frame=\ntitle=Types\n\nfield=newtype\ntitle=New type\nplaceholder=Such as Plants\n'
    printf '\nchoice=keep\ntitle=Your types\ntype=multiple\n'
    types | while IFS= read -r one; do openspot_kv value "t$(hex "$one")"; done
    types | while IFS= read -r one; do printf '\noption=t%s\n' "$(hex "$one")"; openspot_kv title "$one"; done
    return 0
  fi
  new=$(clean "$(value input.newtype)")
  kept=$(value input.keep)
  [ -s "$draft" ] && [ -z "$(value input.link)$(value input.name)$(value search)" ] || return 1
  [ "$(cut -f1 < "$draft")" = "$1" ] && [ -n "$(find "$draft" -mmin -10)" ] || return 1
  shift
  if [ -n "$new$kept" ]; then
    { printf '%s\n' "$kept" | while IFS= read -r id; do [ -n "$id" ] && unhex "${id#t}" && echo; done; [ -z "$new" ] || printf '%s\n' "$new"; } \
      | awk 'NF && !seen[$0]++' | openspot_keep "$kinds" || exit 1
  fi
  at() { cut -f"$(($1 + 1))" < "$draft"; }
  type=$2
  types | grep -qxF -- "$type" || type=
  [ -z "$new" ] || type=$new
  [ -n "$type" ] || type=$(types | head -n 1)
  wishform "$1" "$(at 1)" "$(at 2)" "$(at 3)" '' "$type" "$(at 4)" '' ''
}

# The form of a new wish. It asks for the link, then shows what the page gave, to change before it is kept.
# The page that it read last waits in $OPENSPOT_DATA/page: the link, then the line that fetch prints.
add() {
  retype add 'New wish' "$(cut -f6 "$OPENSPOT_DATA/page" 2>/dev/null)" && return
  typed=$(clean "$(value input.link)")
  [ -n "$typed" ] || typed=$(clean "$(value search)")
  url=$(printf '%s\n' "$typed" | link | untrack)
  if [ -z "$url" ]; then
    printf 'frame=\ntitle=New wish\n\nfield=link\ntitle=Link\nplaceholder=Paste a product link\nrequired=true\n'
    if [ -n "$typed" ]; then printf 'detail=A link starts with https://\ntone=warn\n'; fi
    return
  fi
  found=$(list | U="$url" awk -F'\t' '$6 == ENVIRON["U"] { print $1; exit }')
  if [ -n "$found" ]; then
    openspot select "$found"
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
  openspot select "$id"
}

# The form of a wish that is there, with each of its values. A wish that lacks its picture, its price or a name of its
# own, one taken from its link, reads its page again for them.
edit() {
  [ -n "$1" ] || return
  [ -n "$(field "$1" 1)" ] || return
  retype "$1" 'Edit wish' "$(field "$1" 2)" && return
  name=$(clean "$(value input.name)")
  if [ -n "$name" ]; then
    keep "$1" "$(field "$1" 4)"
    openspot select "$1"
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
  wishform 'Edit wish' "$url" "$name" "$price" "$currency" "$(field "$1" 2)" "$picture" '' ''
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
    { printf "• %s%s\n  %s\n", $6, ($7 == "" ? "" : " — " $7), $10 }' | openspot clipboard copy \
    && openspot toast 'Copied your list. Paste it into a message.'
}

case "$1" in
  show) show ;;
  open)
    case "$2" in
      add) add ;;
      share) if [ "$(value setting.group)" = Price ]; then share Price; else share Type; fi ;;
      *)
        url=$(value item.url)
        [ -n "$url" ] || url=$(field "$2" 6)
        if [ -n "$url" ]; then open "$url"; fi
        ;;
    esac
    ;;
  edit) edit "$2" ;;
  remove) if [ -n "$2" ]; then list | awk -F'\t' -v id="$2" '$1 != id' | openspot_keep "$data"; fi ;;
esac
