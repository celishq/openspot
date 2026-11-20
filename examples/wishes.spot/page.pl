#!/usr/bin/perl
# Reads a product page on stdin and prints one line: title, price, currency, image, type.
# With --price <text>, prints the price and the currency that the text holds.
use strict;
use warnings;
use utf8;
use Encode qw(decode);

binmode(STDOUT, ':encoding(UTF-8)');

my @symbols = (
    [ qr/\$/, 'USD' ], [ qr/€/, 'EUR' ], [ qr/£/, 'GBP' ], [ qr/₴|грн/i, 'UAH' ],
    [ qr/¥/, 'JPY' ], [ qr/zł/i, 'PLN' ], [ qr/₹/, 'INR' ], [ qr/₩/, 'KRW' ],
);

sub number {
    my ($text) = @_;
    return '' unless defined $text;
    $text =~ s/[\s\x{a0}\x{202f}\x{2009}]//g;
    return '' unless $text =~ /(\d[\d.,]*)/;
    my $n = $1;
    $n =~ s/[.,]+$//;
    if ($n =~ /,/ && $n =~ /\./) {
        if (rindex($n, ',') > rindex($n, '.')) { $n =~ s/\.//g; $n =~ s/,/./; }
        else { $n =~ s/,//g; }
    }
    elsif ($n =~ /^\d+,\d{1,2}$/) { $n =~ s/,/./; }
    elsif ($n =~ /,/) { $n =~ s/,//g; }
    elsif ($n =~ /^\d{1,3}(\.\d{3})+$/) { $n =~ s/\.//g; }
    return '' unless $n =~ /^\d+(\.\d+)?$/ && $n > 0;
    $n = sprintf('%.2f', $n);
    $n =~ s/\.00$//;
    return $n;
}

sub currency {
    my ($text) = @_;
    return '' unless defined $text;
    for my $pair (@symbols) { return $pair->[1] if $text =~ $pair->[0]; }
    return $1 if $text =~ /(?<![A-Za-z])(USD|EUR|GBP|UAH|PLN|CHF|CZK|SEK|NOK|DKK|HUF|RON|BGN|TRY|ILS|AED|JPY|CNY|INR|KRW|CAD|AUD|NZD|BRL|MXN|SGD|HKD)(?![A-Za-z])/;
    return '';
}

# A name from the words of the link, such as seneka-moralni-lysty for a shop that hides its page.
sub slug {
    my ($link) = @_;
    my ($path) = $link =~ m{^https?://[^/?#]+([^?#]*)};
    my $best = "";
    for my $part (split m{/}, $path // "") {
        $part =~ s/\.(html?|php|aspx?)$//i;
        $part =~ s/%([0-9a-f]{2})/chr(hex($1))/gie;
        next unless $part =~ /[-_]/ && $part =~ /\pL{3}/;
        $best = $part if length($part) > length($best);
    }
    $best =~ s/[-_]+/ /g;
    $best =~ s/(?:\s+[a-z]*\d[\w]*)+$//i if $best =~ /\pL{3}.*\s/;
    $best =~ s/^\s+|\s+$//g;
    return ucfirst $best;
}

sub plain {
    my ($text) = @_;
    return '' unless defined $text;
    my %named = (amp => '&', quot => '"', apos => "'", lt => '<', gt => '>', nbsp => ' ', ndash => '–', mdash => '—');
    $text =~ s/&#x([0-9a-f]+);/chr(hex($1))/gie;
    $text =~ s/&#(\d+);/chr($1)/ge;
    $text =~ s/&(\w+);/exists $named{lc $1} ? $named{lc $1} : "&$1;"/ge;
    $text =~ s/\\u([0-9a-f]{4})/chr(hex($1))/gie;
    $text =~ s/\\\//\//g;
    $text =~ s/[\x00-\x1f\x7f]+/ /g;
    $text =~ s/\s+/ /g;
    $text =~ s/^\s+|\s+$//g;
    return $text;
}

if (@ARGV && $ARGV[0] eq '--price') {
    my $text = decode('UTF-8', $ARGV[1] // '');
    print number($text), "\t", currency(uc $text), "\n";
    exit 0;
}

my $url = decode('UTF-8', $ARGV[0] // '');
my $raw = do { local $/; <STDIN> } // '';
my $charset = $raw =~ /charset\s*=\s*["']?([\w-]+)/i ? $1 : 'UTF-8';
my $html = eval { decode($charset, $raw) } // decode('UTF-8', $raw);

my %meta;
while ($html =~ /<meta\b([^>]*)>/gis) {
    my ($tag, %at) = ($1);
    while ($tag =~ /([\w:-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+))/g) {
        $at{lc $1} = defined $2 ? $2 : defined $3 ? $3 : $4;
    }
    my $key = lc($at{property} // $at{name} // $at{itemprop} // '');
    next if $key eq '' || !defined $at{content} || $at{content} eq '';
    $meta{$key} //= $at{content};
}

my $ld = join("\n", $html =~ /<script[^>]*application\/ld\+json[^>]*>(.*?)<\/script>/gis);
sub ld { my ($key, $form) = @_; return $ld =~ /"$key"\s*:\s*$form/is ? $1 : undef; }

# The picture of a product among the images of a page that names none: one that the page marks as the product's, or as
# its gallery or cover, else the first large one. A logo, an icon or a sprite is never the product.
sub shown_image {
    my ($best, $first);
    while ($html =~ /<img\b([^>]*)>/gis) {
        my $tag = $1;
        my ($src) = $tag =~ /\b(?:data-src|data-original|data-lazy-src|src)\s*=\s*["']([^"']+)["']/i;
        ($src) = $tag =~ /\bsrcset\s*=\s*["']\s*([^\s"',]+)/i unless defined $src && $src !~ /^data:/i;
        next unless defined $src && $src !~ /^data:/i;
        next if $src =~ /logo|icon|sprite|pixel|spacer|avatar|badge|flag|payment|banner|\.svg(?:$|\?)/i
            || $tag =~ /\b(?:class|id|alt)\s*=\s*["'][^"']*(?:logo|icon|avatar|banner)/i;
        my ($width) = $tag =~ /\bwidth\s*=\s*["']?(\d+)/i;
        next if defined $width && $width < 120;
        return $src if $tag =~ /itemprop\s*=\s*["']image|(?:class|id)\s*=\s*["'][^"']*(?:product|gallery|cover|zoom|main-?image|primary)/i;
        $first //= $src if $src =~ /\.(?:jpe?g|png|webp|avif)(?:$|\?)/i || (defined $width && $width >= 200);
    }
    return $first;
}

my $title = $meta{'og:title'} // $meta{'twitter:title'};
$title //= $1 if $html =~ /<title[^>]*>(.*?)<\/title>/is;
$title = plain($title);
$title =~ s/^Amazon\.[a-z.]+\s*:\s*//i;
$title = $1 if $title =~ /^(.{8,}?)\s+[|–—]\s+\S.*$/;
$title = $1 if $title =~ /^(.{8,}?)\s+[-|–—]\s+(?:купити|купить|buy|shop|kaufen|kup|acheter|comprar|ціна|цена|price|замовити|заказать)\b.*$/i;
$title = "" if $title =~ /^(just a moment|access denied|robot check|attention required|are you a human|pardon our interruption|403 forbidden|page not found|error)\b/i || $title !~ /\s/ && $title =~ /^[\w-]+\.[a-z.]+$/i;
my $read = $title eq "" ? 0 : 1;
$title = slug($url) if $title eq "";
$title = substr($title, 0, 117) . '…' if length($title) > 118;

my $core = $html =~ /id="(?:corePrice[^"]*|apex_desktop[^"]*|price_inside_buybox|priceblock_ourprice)"(.{0,4000})/s ? $1 : "";
my $amazon = $core =~ /a-price-symbol">([^<]*)<.*?a-price-whole">([\d.,]+)<.*?a-price-fraction">(\d+)/s ? plain("$1$2.$3") : undef;
my $shown = $url !~ m{^https?://[^/]*amazon\.} && $html =~ /class=["'][^"']*price[^"']*["'][^>]*>\s*([^<]{0,12}\d[^<]{0,12})</i ? plain($1) : undef;
$shown = undef unless defined $shown && currency($shown) ne "";
my $tagged = $html =~ /itemprop=["']price["'][^>]*content=["']([^"']+)/i ? $1 : undef;
my $price = '';
for my $found ($meta{'product:price:amount'}, $meta{'og:price:amount'}, $meta{'price'}, $tagged,
               ld('price', '"?([\d.,]+)'), ld('lowPrice', '"?([\d.,]+)'), $amazon, $shown) {
    $price = number($found);
    last if $price ne '';
}

my $currency = '';
for my $found ($meta{'product:price:currency'}, $meta{'og:price:currency'}, $meta{'pricecurrency'},
               ld('priceCurrency', '"([A-Za-z]{3})"'), $amazon, $shown) {
    $currency = currency($found);
    last if $currency ne '';
}
$currency = '' if $price eq '';

my $image = $meta{'og:image:secure_url'} // $meta{'og:image'} // $meta{'twitter:image'} // $meta{'twitter:image:src'}
    // ld('image', '\[?\s*"([^"]+)"') // ld('image', '\{[^}]*?"url"\s*:\s*"([^"]+)"')
    // ($html =~ /data-old-hires="(https:[^"]+)"/ ? $1 : undef) // ($html =~ /"hiRes":"(https:[^"]+)"/ ? $1 : undef)
    // shown_image() // '';
$image = plain($image);
my ($origin) = $url =~ m{^(https?://[^/?#]+)};
$image = "https:$image" if $image =~ m{^//};
if ($image ne '' && $image !~ m{^(?:https?:)?/} && defined $origin) {
    my ($folder) = $url =~ m{^https?://[^/?#]+(/[^?#]*/)};
    my $path = ($folder // '/') . $image;
    1 while $path =~ s{/(?!\.\./)[^/]+/\.\./}{/};
    $path =~ s{/\./}{/}g;
    $path =~ s{^/(?:\.\./)+}{/};
    $image = $path;
}
$image = ($origin // '') . $image if $image =~ m{^/};
$image =~ s{^http://}{https://};
$image = '' unless $image =~ m{^https://\S+$};

my $words = lc join(' ', $title, $meta{'og:type'} // '', plain(ld('category', '"([^"]*)"')), $url);
my @types = (
    [ Books   => qr/\b(books?|novel|paperback|hardcover|kindle|isbn|audiobook|manga|книг\w*)\b/ ],
    [ Gadgets => qr/\b(phones?|iphone|ipad|macbook|laptop|tablet|headphones?|earbuds|airpods|camera|keyboard|mouse|monitor|charger|speaker|console|playstation|xbox|nintendo|drone|smartwatch|watch|electronics|gadgets?|usb|ssd|gpu|router|kindle)\b/ ],
    [ Clothes => qr/\b(shirts?|t-shirts?|dress(es)?|jeans|jackets?|sneakers?|shoes?|boots|hoodies?|sweaters?|coats?|skirts?|pants|trousers|shorts|socks|scarf|hat|cap|clothing|clothes|apparel|fashion)\b/ ],
    [ Home    => qr/\b(sofa|bookcases?|bookshel\w+|lamp|chair|table|desk|mug|pillow|blanket|kitchen|furniture|vase|candle|rug|shelf|bedding|cookware|home)\b/ ],
    [ Beauty  => qr/\b(perfume|fragrance|lipstick|skincare|serum|shampoo|makeup|cosmetics?|moisturi[sz]er|beauty)\b/ ],
    [ Toys    => qr/\b(lego|toys?|puzzles?|board game|dolls?|plush|games?)\b/ ],
    [ Sports  => qr/\b(yoga|bike|bicycle|dumbbells?|fitness|running|tent|ski|snowboard|football|basketball|tennis|hiking|sports?)\b/ ],
);
my $type = 'Other';
for my $pair (@types) { if ($words =~ $pair->[1]) { $type = $pair->[0]; last; } }
$type = 'Books' if $type eq 'Gadgets' && $words =~ /\bkindle edition\b/;

print join("\t", $title, $price, $currency, $image, $type, $read), "\n";
