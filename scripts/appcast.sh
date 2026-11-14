#!/bin/sh
cat <<FEED
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Openspot</title>
    <item>
      <title>$1</title>
      <pubDate>$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')</pubDate>
      <sparkle:version>$2</sparkle:version>
      <sparkle:shortVersionString>$1</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>26.0</sparkle:minimumSystemVersion>
      <enclosure url="$3" type="application/x-apple-diskimage" $4 />
    </item>
  </channel>
</rss>
FEED
