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
types() {
  { printf 'Books\nClothes\nGadgets\nHome\nBeauty\nToys\nSports\nOther\n'; list | cut -f2; } | awk 'NF && !seen[$0]++'
}

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
  printf '\ntext=add\ntitle=Add wish\nicon=plus.circle.fill\npin=top\nform=true\nclose=false\nopen.title=Add Wish\n'
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
  if [ "$group" = Price ]; then other=Type; else other=Price; fi
  printf 'button=byprice\ntitle=Copy List by Price\nicon=doc.on.doc\nshortcut=cmd+s\nscope=spot\n\n'
  printf 'button=bytype\ntitle=Copy List by Type\nicon=doc.on.doc\nshortcut=cmd+shift+s\nscope=spot\n\n'
  printf 'button=group\ntitle=Group by %s\nicon=rectangle.3.group\nshortcut=cmd+g\nscope=spot\nclose=false\n\n' "$other"
  printf 'button=type\ntitle=Change Type…\nicon=tag\nshortcut=cmd+t\nform=true\nclose=false\nhides=add\n\n'
  printf 'button=edit\ntitle=Edit Name and Price…\nicon=pencil\nshortcut=cmd+e\nform=true\nclose=false\n\n'
  printf 'button=copy\ntitle=Copy Link\nicon=link\nshortcut=cmd+shift+c\n\n'
  printf 'button=remove\ntitle=Remove\nicon=trash\nshortcut=cmd+backspace\nconfirm=Press again to remove this wish\nclose=false\n'
}

# change <id> <column> <value> [<column> <value>]
change() {
  list | A="$3" B="$5" awk -F'\t' -v OFS='\t' -v id="$1" -v a="$2" -v b="${4:-0}" '
    $1 == id { $a = ENVIRON["A"]; if (b > 0) $b = ENVIRON["B"] } { print }' | openspot_keep "$data"
}

# A link with no tracking words, such as utm_source or gclid, so that a shared list is short.
untrack() {
  perl -pe 'if (/^([^?#]*)\?([^#]*)(.*)$/s) { my ($a, $q, $z) = ($1, $2, $3); $q = join "&", grep { !/^(utm_\w+|gclid|gbraid|wbraid|gad_\w+|fbclid|yclid|msclkid|mc_[ce]id|_ga|_gl|srsltid)=/i } split /&/, $q; $_ = $a . ($q eq "" ? "" : "?$q") . $z }'
}

# The form of a new wish. It asks for the link, then shows what the page gave, to change before it is kept.
# The page that it read last waits in $OPENSPOT_DATA/page: link, title, price, currency, picture, type, read, and the
# browser whose open tab it read, with "title" or "html" before it.
# A shop that hides its page from programs is read from a tab of the same link, open in the person's browser.
add() {
  typed=$(clean "$(value input.link)")
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
    page=$(curl -sL --compressed --max-time 12 -A "$agent" -H 'Accept: text/html,application/xhtml+xml' \
      -H 'Accept-Language: en-US,en;q=0.9' "$url" </dev/null | head -c 4000000 | perl "$here/page.pl" "$url" 2>/dev/null)
    from=
    if [ "$(printf '%s\n' "$page" | cut -f6)" != 1 ]; then
      open=$(perl -e 'alarm 60; exec @ARGV' osascript -l JavaScript "$here/tab.js" "$url" 2>/dev/null)
      if [ -n "$open" ]; then
        from=$(printf '%s\n' "$open" | head -n 1)
        page=$(printf '%s\n' "$open" | tail -n +2 | perl "$here/page.pl" "$url" 2>/dev/null)
      fi
    fi
    read=$(printf '%s\t%s\t%s' "$url" "${page:-$tab$tab$tab${tab}Other${tab}0}" "$from")
    printf '%s\n' "$read" | openspot_keep "$OPENSPOT_DATA/page"
    name=
  fi
  if [ -z "$name" ]; then
    title=$(printf '%s\n' "$read" | cut -f2)
    price=$(printf '%s\n' "$read" | cut -f3)
    currency=$(printf '%s\n' "$read" | cut -f4)
    type=$(printf '%s\n' "$read" | cut -f6)
    seen=$(printf '%s\n' "$read" | cut -f7)
    from=$(printf '%s\n' "$read" | cut -f8)
    printf 'frame=\ntitle=New wish\n\nfield=link\ntitle=Link\nrequired=true\n'
    openspot_kv value "$url"
    printf '\nfield=name\ntitle=Name\nrequired=true\nplaceholder=What it is\n'
    if [ -n "$title" ]; then openspot_kv value "$title"; fi
    if [ "$seen" != 1 ]; then printf 'detail=From the link: the shop hides its page. Open it in your browser, then add it.\ntone=warn\n'; fi
    printf '\nfield=price\ntitle=Price\n'
    if [ -n "$price" ]; then
      openspot_kv value "$price${currency:+ $currency}"
    else
      here_currency=$(region)
      openspot_kv placeholder "Such as 250${here_currency:+ $here_currency}"
      case "$from" in
        title\ *) openspot_kv detail "To read the price, turn on Allow JavaScript from Apple Events in ${from#title }."; printf 'tone=warn\n' ;;
        *) if [ "$seen" = 1 ]; then printf 'detail=The page shows no price.\n'; fi ;;
      esac
    fi
    printf '\nchoice=type\ntitle=Type\n'
    types | awk -v now="${type:-Other}" '$0 == now { printf "value=t%d\n", NR }'
    types | awk '{ gsub(/\\/, "\\\\"); printf "\noption=t%d\ntitle=%s\n", NR, $0 }'
    printf '\nfield=newtype\ntitle=Or a new type\nplaceholder=Such as Plants\n'
    return
  fi
  given=$(perl "$here/page.pl" --price "$(value input.price)" 2>/dev/null)
  price=$(printf '%s\n' "$given" | cut -f1)
  currency=$(printf '%s\n' "$given" | cut -f2)
  [ -n "$currency" ] || currency=$(printf '%s\n' "$read" | cut -f4)
  [ -n "$currency" ] || currency=$(region)
  [ -n "$price" ] || currency=
  type=$(clean "$(value input.newtype)")
  if [ -z "$type" ]; then
    picked=$(value input.type)
    type=$(types | sed -n "${picked#t}p")
  fi
  [ -n "$type" ] || type=$(printf '%s\n' "$read" | cut -f6)
  id="w$(date +%s)$$"
  { list; printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "${type:-Other}" "$price" "$currency" "$name" "$url" "$(printf '%s\n' "$read" | cut -f5)"; } \
    | openspot_keep "$data" || exit 1
  rm -f "$OPENSPOT_DATA/page"
  openspot select "$id"
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

retype() {
  [ -n "$1" ] || return
  new=$(clean "$(value input.new)")
  picked=$(value input.type)
  if [ -z "$new" ] && [ -z "$picked" ]; then
    now=$(field "$1" 2)
    printf 'frame=\ntitle=Type of %s\n\nchoice=type\ntitle=Type\n' "$(esc "$(field "$1" 5)")"
    types | awk -v now="${now:-Other}" '$0 == now { printf "value=t%d\n", NR }'
    types | awk '{ gsub(/\\/, "\\\\"); printf "\noption=t%d\ntitle=%s\n", NR, $0 }'
    printf '\nfield=new\ntitle=New type\nplaceholder=Such as Plants\n'
    return
  fi
  [ -n "$new" ] || new=$(types | sed -n "${picked#t}p")
  if [ -n "$new" ]; then change "$1" 2 "$new"; fi
}

edit() {
  [ -n "$1" ] || return
  name=$(clean "$(value input.name)")
  if [ -z "$name" ]; then
    price=$(field "$1" 3)
    currency=$(field "$1" 4)
    printf 'frame=\ntitle=Edit wish\n\nfield=name\ntitle=Name\nrequired=true\n'
    openspot_kv value "$(field "$1" 5)"
    printf '\nfield=price\ntitle=Price\nplaceholder=Such as 29.99 EUR\n'
    if [ -n "$price" ]; then openspot_kv value "$price${currency:+ $currency}"; fi
    return
  fi
  typed=$(perl "$here/page.pl" --price "$(value input.price)" 2>/dev/null)
  price=$(printf '%s\n' "$typed" | cut -f1)
  currency=$(printf '%s\n' "$typed" | cut -f2)
  [ -n "$currency" ] || currency=$(field "$1" 4)
  [ -n "$currency" ] || currency=$(region)
  [ -n "$price" ] || currency=
  change "$1" 5 "$name" && change "$1" 3 "$price" 4 "$currency"
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
    if [ "$2" = add ]; then
      add
    else
      url=$(value item.url)
      [ -n "$url" ] || url=$(field "$2" 6)
      if [ -n "$url" ]; then open "$url"; fi
    fi
    ;;
  byprice) share Price ;;
  bytype) share Type ;;
  group)
    if [ "$(value setting.group)" = Price ]; then openspot setting set group Type; else openspot setting set group Price; fi
    ;;
  type) retype "$2" ;;
  edit) edit "$2" ;;
  copy)
    url=$(value item.url)
    [ -n "$url" ] || url=$(field "$2" 6)
    if [ -n "$url" ]; then printf '%s' "$url" | openspot clipboard copy && openspot toast 'Copied the link.'; fi
    ;;
  remove) if [ -n "$2" ]; then list | awk -F'\t' -v id="$2" '$1 != id' | openspot_keep "$data"; fi ;;
esac
