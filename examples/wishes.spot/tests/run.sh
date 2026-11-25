#!/bin/sh
# Runs the tests of Wishes: what page.pl reads from a product page. `make verify` runs each `tests/run.sh` of a spot.
# It reads no network: each page is text of this file.
set -e
export LC_ALL=en_US.UTF-8
spot=$(cd "$(dirname "$0")/.." && pwd)
tab=$(printf '\t')
failed=0

# reads <name> <link> <page> <title> <price> <currency> <picture> <type> <read>
reads() {
  got=$(printf '%s' "$3" | perl "$spot/page.pl" "$2")
  want="$4$tab$5$tab$6$tab$7$tab$8$tab$9"
  [ "$got" = "$want" ] && return
  printf 'page.pl, %s:\n  want %s\n  got  %s\n' "$1" "$want" "$got"
  failed=1
}

# prices <text> <price> <currency>
prices() {
  got=$(perl "$spot/page.pl" --price "$1")
  [ "$got" = "$2$tab$3" ] && return
  printf 'page.pl --price %s:\n  want %s\n  got  %s\n' "$1" "$2$tab$3" "$got"
  failed=1
}

reads 'the tags of a shop' 'https://shop.example/p/1' \
  '<meta property="og:title" content="Wool sweater | Shop"><meta content="https://shop.example/a.jpg" property="og:image">
   <meta property="product:price:amount" content="89.00"><meta property="product:price:currency" content="EUR">' \
  'Wool sweater' 89 EUR 'https://shop.example/a.jpg' Clothes 1

reads 'the data of a product' 'https://shop.example/p/2' \
  '<title>Tom&#39;s &amp; Co headphones</title>
   <script type="application/ld+json">{"@type":"Product","image":["\/img\/h.jpg"],"offers":{"price":"1.299,50","priceCurrency":"UAH"}}</script>' \
  "Tom's & Co headphones" 1299.50 UAH 'https://shop.example/img/h.jpg' Gadgets 1

reads 'a book named by its breadcrumbs' 'https://sens.example/taiemnytsia/' \
  '<title>Таємниця таємниць</title><div class="breadcrumbs"><ol><li>Інтернет-магазин книг</li><li>Проза</li></ol></div>' \
  'Таємниця таємниць' '' '' '' Books 1

reads 'a book named by its details' 'https://shop.example/p/9' \
  '<title>Таємниця таємниць</title><dl><dt>Видавництво</dt><dd>КСД</dd><dt>Кількість сторінок</dt><dd>608</dd></dl>' \
  'Таємниця таємниць' '' '' '' Books 1

reads 'a phone in Ukrainian' 'https://shop.example/p/10' \
  '<title>Смартфон Pixel 9 128 ГБ</title>' \
  'Смартфон Pixel 9 128 ГБ' '' '' '' Gadgets 1

reads 'a thing with no cue' 'https://shop.example/p/11' \
  '<title>Таємний сад</title><p>Видавництво не вказано</p>' \
  'Таємний сад' '' '' '' Other 1

reads 'a price that only shows' 'https://books.example/p/3' \
  '<title>A Light in the Attic | Books</title><p class="price_color">£51.77</p>' \
  'A Light in the Attic' 51.77 GBP '' Books 1

reads 'a page with no price' 'https://shop.example/p/4' \
  '<meta property="og:title" content="Oak bookcase"><span class="price-note">Ask us</span>' \
  'Oak bookcase' '' '' '' Home 1

reads 'the price of another product on Amazon' 'https://www.amazon.com/dp/B000' \
  '<title>Amazon.com: Smart Speaker : Electronics</title><img data-old-hires="https://m.example/s.jpg">
   <li class="a-carousel-card"><span class="a-offscreen">$4499</span><span class="a-price">$44.99</span></li>' \
  'Smart Speaker : Electronics' '' '' 'https://m.example/s.jpg' Gadgets 1

reads 'the price of the product on Amazon' 'https://www.amazon.com/dp/B001' \
  '<title>Amazon.com: Desk lamp</title><div id="corePrice_feature_div"><span class="a-price-symbol">$</span><span class="a-price-whole">44<span class="a-price-decimal">.</span></span><span class="a-price-fraction">99</span></div>' \
  'Desk lamp' 44.99 USD '' Home 1

reads 'a page that a shop refused, named from its link' 'https://shop.example/knyhy/seneka-moralni-lysty/?utm_source=x' '<title>Just a moment...</title>' \
  'Seneka moralni lysty' '' '' '' Other 0

reads 'a link of codes, with no words' 'https://www.amazon.com/dp/B09B8V1LZ3' '' '' '' '' '' Other 0

reads 'a title with the shop''s buy words' 'https://shop.example/p/7' \
  '<title>Сенека. Моральні листи до Луцилія - купити за низькою ціною в Україні</title>' \
  'Сенека. Моральні листи до Луцилія' '' '' '' Other 1

reads 'a title with a dash of its own' 'https://shop.example/p/8' '<title>Spider-Man - Into the Spider-Verse</title>' \
  'Spider-Man - Into the Spider-Verse' '' '' '' Other 1

reads 'a picture among the images of a page' 'https://shop.example/p/9' \
  '<title>Lamp</title><img src="/img/logo.png" class="logo"><img width="40" src="/a/tiny.jpg"><img class="product-gallery__photo" data-src="/media/lamp.webp" src="data:image/gif;base64,R0">' \
  Lamp '' '' 'https://shop.example/media/lamp.webp' Home 1

reads 'a picture at a path beside the page' 'https://shop.example/catalogue/cup/index.html' \
  '<title>A cup</title><div class="item active"><img src="../../media/cup.jpg" alt="A cup"></div>' \
  'A cup' '' '' 'https://shop.example/media/cup.jpg' Other 1

reads 'no picture when a page has only its logo' 'https://shop.example/p/11' '<title>A mug</title><img src="/assets/logo.png">' \
  'A mug' '' '' '' Home 1

prices '$29.99' 29.99 USD
prices '29,99 eur' 29.99 EUR
prices '1 299,50 грн' 1299.50 UAH
prices '1,299.00' 1299 ''
prices 'soon' '' ''
prices '526 UAN' 526 ''

# The frames of wishes.sh in protocol 3, and its list in Wishes.md, with a fake `openspot` and a data folder under a
# hidden folder, as ~/.config is.
shell="$spot/../../app/Shell/openspot.sh"
if [ -f "$shell" ]; then
  work=$(mktemp -d)
  trap 'rm -rf "$work"' EXIT
  data="$work/.config/openspot/data/wishes"
  mkdir -p "$work/bin" "$data" "$work/iCloud Drive/Lists" "$work/Vault"
  printf '#!/bin/sh\necho "$*" >> "%s/calls"\ncase "$1 $2" in "folder pick") cat "%s/pick" ;; esac\n' "$work" "$work" > "$work/bin/openspot"
  chmod +x "$work/bin/openspot"
  printf 'w1\tBooks\t18\tUSD\tThe Design of Everyday Things\thttps://shop.example/b\thttps://shop.example/b.jpg\t\n' > "$data/wishes.tsv"
  printf 'Plants\n' > "$data/types"
  setting=
  call() { printf '%s\n%s' "$2" "$setting" | HOME="$work" PATH="$work/bin:$PATH" OPENSPOT_SH="$shell" OPENSPOT_DATA="$data" sh "$spot/wishes.sh" "$1"; }
  # frame <name> <handler> <stdin> <line>...: each line is in what the handler prints.
  frame() {
    name=$1 out=$(call "$2" "$3"); shift 3
    for line; do
      printf '%s\n' "$out" | grep -qxF -- "$line" && continue
      printf 'wishes.sh, %s: no line %s in\n%s\n' "$name" "$line" "$out"
      failed=1
    done
  }
  # book <name> <file> <line>...: each line is in the file.
  book() {
    name=$1 file=$2; shift 2
    for line; do
      grep -qxF -- "$line" "$file" 2>/dev/null && continue
      printf 'Wishes.md, %s: no line %s in\n%s\n' "$name" "$line" "$(cat "$file" 2>/dev/null)"
      failed=1
    done
  }
  id=$(call show '' | sed -n 's/^item=\(w.*\)/\1/p')

  frame 'the list from the older wishes.tsv' show '' 'field=search' 'type=search' 'items=items' 'item=add' 'parent=items' 'open.wait=Reading the page' \
    'box=s1' 'title=Books' "item=$id" 'parent=s1' 'item=share' 'button=edit' 'wait=Reading the page'
  book 'the older list' "$data/Wishes.md" '# Wishes' '## Books' \
    '- [The Design of Everyday Things](https://shop.example/b) — 18 USD' '  ![](https://shop.example/b.jpg)' '## Plants'
  [ -f "$data/wishes.tsv" ] || { printf 'wishes.sh dropped the older wishes.tsv\n'; failed=1; }
  frame 'a search that is no link' press "$(printf 'input.item=add\ninput.search=a sweater')" \
    'type=form' 'title=New wish' 'field=link' 'detail=A link starts with https://'
  frame 'the form of a wish' edit "input.item=$id" 'type=form' 'title=Edit wish' 'value=https://shop.example/b' \
    'value=The Design of Everyday Things' 'title=Plants'
  books=$(printf 'Books' | od -An -tx1 | tr -d ' \n')
  call edit "$(printf 'input.item=%s\ninput.link=https://shop.example/b\ninput.name=Design [2nd] book\ninput.price=20\ninput.notes=hardcover\ninput.type=t%s' "$id" "$books")" >/dev/null
  book 'a saved edit' "$data/Wishes.md" '- [Design \[2nd\] book](https://shop.example/b) — 20 USD — hardcover' '## Plants'

  printf '%s/Vault' "$work" > "$work/pick"
  call folder '' >/dev/null
  grep -qxF "setting set folder ~/Vault" "$work/calls" || { printf 'wishes.sh folder: no setting set in\n%s\n' "$(cat "$work/calls")"; failed=1; }
  book 'the moved list' "$work/Vault/Wishes.md" '- [Design \[2nd\] book](https://shop.example/b) — 20 USD — hardcover'
  [ ! -f "$data/Wishes.md" ] || { printf 'wishes.sh folder left the list behind\n'; failed=1; }
  setting="setting.folder=~/Vault"

  printf '# Wishes\n\n## Plants\n\n- [Fern](https://plants.example/fern) — 12 EUR\n' > "$work/iCloud Drive/Lists/Wishes.md"
  printf '%s/iCloud Drive/Lists' "$work" > "$work/pick"
  call folder '' >/dev/null
  book 'the list that the folder had' "$work/iCloud Drive/Lists/Wishes.md" '- [Fern](https://plants.example/fern) — 12 EUR'
  book 'the list that stays where it was' "$work/Vault/Wishes.md" '- [Design \[2nd\] book](https://shop.example/b) — 20 USD — hardcover'
  setting="setting.folder=$work/iCloud Drive/Lists"
  frame 'a list written by hand' show '' 'title=Plants' 'title=Fern' 'detail=€12 · plants.example'

  fern=$(call show '' | sed -n 's/^item=\(w.*\)/\1/p')
  call remove "input.item=$fern" >/dev/null
  book 'a removed wish keeps its own type' "$work/iCloud Drive/Lists/Wishes.md" '# Wishes' '## Plants'
  grep -q 'Fern' "$work/iCloud Drive/Lists/Wishes.md" && { printf 'wishes.sh remove left the wish\n'; failed=1; }

  setting="setting.folder=$work/Gone"
  frame 'a folder that is gone' show '' 'item=lost' "title=Wishes can't find ~/Gone"
  if call remove "input.item=$fern" >/dev/null; then printf 'wishes.sh wrote to a folder that is gone\n'; failed=1; fi
  grep -q "toast Wishes can't write Wishes.md in ~/Gone" "$work/calls" || { printf 'wishes.sh said nothing of a write that failed\n'; failed=1; }
  [ ! -d "$work/Gone" ] || { printf 'wishes.sh made the folder that was gone\n'; failed=1; }
fi
[ "$failed" = 0 ] && echo 'Wishes tests passed.'
exit "$failed"
