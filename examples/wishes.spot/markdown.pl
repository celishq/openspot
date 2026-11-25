#!/usr/bin/perl
# Wishes.md, the list that people can read and edit by hand, and the lines that wishes.sh works with.
#
#   perl markdown.pl read < Wishes.md     prints each wish: id, type, price, currency, title, link, picture, notes
#   perl markdown.pl types < Wishes.md    prints each type, one ## heading each, in the order of the file
#   perl markdown.pl write <built-in types, split by |> <own types, one a line> < wishes
#                                         prints Wishes.md: the built-in types in their order, then the own ones,
#                                         each own type even with no wish, and Other last
#
# A wish is one line of its type, with its picture on the next:
#
#   ## Books
#
#   - [Таємниця таємниць](https://sens.in.ua/taiemnytsia-taiemnyts/) — 830 UAH — in hardcover
#     ![](https://sens.in.ua/cover.webp)
#
# Its id comes from its link, or from its title when it has none, so it stays the same while the link does.
use strict;
use warnings;
use utf8;
use Digest::MD5 qw(md5_hex);
use Encode qw(encode_utf8);

binmode STDIN, ':encoding(UTF-8)';
binmode STDOUT, ':encoding(UTF-8)';

my $mode = shift // '';
my $dash = "\x{2014}";

sub id_of {
    my ($link, $title) = @_;
    return 'w' . substr(md5_hex(encode_utf8($link ne '' ? $link : $title)), 0, 12);
}

sub flat {
    my $text = shift // '';
    $text =~ s/[\t\r\n]+/ /g;
    $text =~ s/^\s+|\s+$//g;
    return $text;
}

if ($mode eq 'read' || $mode eq 'types') {
    my ($type, @wishes, %seen) = ('Other');
    while (my $line = <STDIN>) {
        chomp $line;
        $line =~ s/\r$//;
        if ($line =~ /^##\s+(.+?)\s*#*\s*$/) {
            $type = $1;
            print "$type\n" if $mode eq 'types' && !$seen{$type}++;
            next;
        }
        if (@wishes && $line =~ /^\s+!\[[^\]]*\]\((\S+?)\)\s*$/) {
            $wishes[-1]{picture} = $1;
            next;
        }
        next unless $line =~ /^\s*[-*+]\s+(.+?)\s*$/;
        my $text = $1;
        my ($title, $link, $rest) = ('', '', '');
        if ($text =~ /^\[((?:\\.|[^\]\\])*)\]\(([^)\s]*)\)(.*)$/) {
            ($title, $link, $rest) = ($1, $2, $3);
            $title =~ s/\\(.)/$1/g;
        } else {
            ($title, $rest) = split /\s+$dash\s+/, $text, 2;
            $rest = defined $rest ? " $dash $rest" : '';
        }
        $rest =~ s/^\s*$dash\s*//;
        my @parts = grep { $_ ne '' } split /\s+$dash\s+/, $rest;
        my ($price, $currency) = ('', '');
        if (@parts && $parts[0] =~ /^(\d+(?:\.\d+)?)(?:\s+([A-Z]{3}))?$/) {
            ($price, $currency) = ($1, $2 // '');
            shift @parts;
        }
        push @wishes, { type => $type, price => $price, currency => $currency, title => flat($title), link => $link,
            picture => '', notes => flat(join " $dash ", @parts) };
    }
    exit 0 if $mode eq 'types';
    for my $wish (@wishes) {
        next if $wish->{title} eq '' && $wish->{link} eq '';
        print join("\t", id_of($wish->{link}, $wish->{title}), @$wish{qw(type price currency title link picture notes)}), "\n";
    }
    exit 0;
}

if ($mode eq 'write') {
    my @builtin = grep { $_ ne '' } split /\|/, (shift // '');
    my @own = grep { $_ ne '' } map { flat($_) } split /\n/, (shift // '');
    my (%of, @order);
    while (my $line = <STDIN>) {
        chomp $line;
        my @f = split /\t/, $line, -1;
        next if @f < 6;
        my $type = flat($f[1]) || 'Other';
        push @order, $type unless $of{$type};
        push @{ $of{$type} }, \@f;
    }
    my (@types, %listed);
    for my $type ((grep { $_ ne 'Other' } @builtin), @own, @order, 'Other') {
        next if $listed{$type}++;
        my $own = grep { $_ eq $type } @own;
        push @types, $type if $of{$type} || $own;
    }
    print "# Wishes\n";
    for my $type (@types) {
        print "\n## $type\n";
        print "\n" if $of{$type};
        for my $f (@{ $of{$type} || [] }) {
            my ($price, $currency, $title, $link, $picture, $notes) = map { flat($_) } @$f[2 .. 7];
            (my $shown = $title) =~ s/([\\\[\]])/\\$1/g;
            $link =~ s/ /%20/g;
            $link =~ s/\(/%28/g;
            $link =~ s/\)/%29/g;
            my $line = "- [$shown]($link)";
            $line .= " $dash $price" . ($currency ne '' ? " $currency" : '') if $price ne '';
            $line .= " $dash $notes" if $notes ne '';
            print "$line\n";
            print "  ![]($picture)\n" if $picture ne '';
        }
    }
    exit 0;
}

print STDERR "Use: markdown.pl read, types or write\n";
exit 2;
