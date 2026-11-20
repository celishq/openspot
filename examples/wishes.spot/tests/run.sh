#!/bin/sh
# Runs the tests of Wishes: what page.pl reads from a product page. `make verify` runs each `tests/run.sh` of a spot.
# It reads no network: each page is text of this file.
set -e
export LC_ALL=en_US.UTF-8
spot=$(cd "$(dirname "$0")/.." && pwd)
tab=$(printf '\t')
failed=0

# reads <name> <link> <page> <title> <price> <currency> <picture> <type>
reads() {
  got=$(printf '%s' "$3" | perl "$spot/page.pl" "$2")
  want="$4$tab$5$tab$6$tab$7$tab$8"
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
  'Wool sweater' 89 EUR 'https://shop.example/a.jpg' Clothes

reads 'the data of a product' 'https://shop.example/p/2' \
  '<title>Tom&#39;s &amp; Co headphones</title>
   <script type="application/ld+json">{"@type":"Product","image":["\/img\/h.jpg"],"offers":{"price":"1.299,50","priceCurrency":"UAH"}}</script>' \
  "Tom's & Co headphones" 1299.50 UAH 'https://shop.example/img/h.jpg' Gadgets

reads 'a price that only shows' 'https://books.example/p/3' \
  '<title>A Light in the Attic | Books</title><p class="price_color">£51.77</p>' \
  'A Light in the Attic' 51.77 GBP '' Books

reads 'a page with no price' 'https://shop.example/p/4' \
  '<meta property="og:title" content="Oak bookcase"><span class="price-note">Ask us</span>' \
  'Oak bookcase' '' '' '' Home

reads 'the price of another product on Amazon' 'https://www.amazon.com/dp/B000' \
  '<title>Amazon.com: Smart Speaker : Electronics</title><img data-old-hires="https://m.example/s.jpg">
   <li class="a-carousel-card"><span class="a-offscreen">$4499</span><span class="a-price">$44.99</span></li>' \
  'Smart Speaker : Electronics' '' '' 'https://m.example/s.jpg' Gadgets

reads 'the price of the product on Amazon' 'https://www.amazon.com/dp/B001' \
  '<title>Amazon.com: Desk lamp</title><div id="corePrice_feature_div"><span class="a-price-symbol">$</span><span class="a-price-whole">44<span class="a-price-decimal">.</span></span><span class="a-price-fraction">99</span></div>' \
  'Desk lamp' 44.99 USD '' Home

reads 'a page that a shop refused' 'https://shop.example/iphone-15' '<title>Just a moment...</title>' '' '' '' '' Gadgets

prices '$29.99' 29.99 USD
prices '29,99 eur' 29.99 EUR
prices '1 299,50 грн' 1299.50 UAH
prices '1,299.00' 1299 ''
prices 'soon' '' ''

[ "$failed" = 0 ] && echo 'Wishes tests passed.'
exit "$failed"
