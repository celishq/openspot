#!/bin/sh
. "$OPENSPOT_SH"
cover="$OPENSPOT_DATA/cover.jpg"

# Prints the card: the cover, the song and its artist, how far it played, and the controls. It takes the title, the
# artist, the share played from 0 to 1, the time played, whether it plays, and the path of the cover.
card() {
  printf 'frame=\nclass=gap-part large:flex-row\n\n'
  printf 'picture=cover\nclass=large:w-1/2 large:aspect-square\n'; openspot_kv icon "$6"; printf '\n'
  printf 'box=side\nclass=gap-part large:grow\n\ntext=song\nparent=side\nclass=bar:flex\n'; openspot_kv title "$1"; openspot_kv detail "$2"; printf '\n'
  printf 'number=time\nparent=side\nmax=1\nchart=bar\n'; openspot_kv display "$4"; openspot_kv value "$3"; printf '\n'
  printf 'box=controls\nparent=side\nclass=gap-part large:flex-row large:justify-between\n\nbutton=prev\nparent=controls\ntitle=Previous\nicon=backward.fill\nlook=bare\nclose=false\n\n'
  if [ "$5" = playing ]; then printf 'button=play\nparent=controls\ntitle=Pause\nicon=pause.fill\nlook=bare\nclose=false\n\n'; else printf 'button=play\nparent=controls\ntitle=Play\nicon=play.fill\nlook=bare\nclose=false\n\n'; fi
  printf 'button=next\nparent=controls\ntitle=Next\nicon=forward.fill\nlook=bare\nclose=false\n'
}

# Asks Music for one value of the current song, only while Music runs, so that a read never opens it.
music() {
  pgrep -xq Music && osascript -e "tell application \"Music\" to $1" 2>/dev/null
}

case "$1" in
  show)
    state=$(music "player state as text")
    if [ -z "$state" ] || [ "$state" = stopped ]; then
      printf 'frame=\nclass=gap-part\n\ntext=song\nclass=bar:flex\ntitle=Nothing playing\ndetail=Open Music to play a song\n'
      exit 0
    fi
    name=$(music "name of current track")
    artist=$(music "artist of current track")
    position=$(music "player position")
    duration=$(music "duration of current track")
    music "set out to open for access (POSIX file \"$cover\") with write permission
      set eof out to 0
      write (raw data of artwork 1 of current track) to out
      close access out" >/dev/null || rm -f "$cover"
    share=$(awk -v p="$position" -v d="$duration" 'BEGIN { printf "%.2f", (d > 0 ? p / d : 0) }')
    played=$(awk -v p="$position" 'BEGIN { printf "%d:%02d", p / 60, p % 60 }')
    card "$name" "$artist" "$share" "$played" "$state" "$( [ -s "$cover" ] && echo "$cover" || echo music.note )"
    ;;
  play) music "playpause" >/dev/null ;;
  prev) music "previous track" >/dev/null ;;
  next) music "next track" >/dev/null ;;
esac
