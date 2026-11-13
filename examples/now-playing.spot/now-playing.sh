#!/bin/sh
# title=Now playing
# icon=music.note
# detail=The song in Music, with its controls
# on=panel.open
# on=clock.5
# preview=sample
. "$OPENSPOT_SH"
here=$(cd "$(dirname "$0")" && pwd)
cover="$OPENSPOT_DATA/cover.jpg"

# Prints the card: the cover, the song and its artist, how far it played, and the controls. It takes the title, the
# artist, the share played from 0 to 1, the time played, whether it plays, and the path of the cover.
card() {
  printf 'grid.large=cover cover cover song song song\ngrid.large=cover cover cover time time time\ngrid.large=cover cover cover prev play next\nmain=song\n\n'
  printf 'picture=cover\n'; openspot_kv icon "$6"; printf '\n'
  printf 'text=song\n'; openspot_kv title "$1"; openspot_kv detail "$2"; printf '\n'
  printf 'graph=time\n'; openspot_kv title "$4"; openspot_kv value "$3"; printf '\n'
  printf 'button=prev\ntitle=Previous\nicon=backward.fill\nlook=bare\n\n'
  if [ "$5" = playing ]; then printf 'button=play\ntitle=Pause\nicon=pause.fill\nlook=bare\n\n'; else printf 'button=play\ntitle=Play\nicon=play.fill\nlook=bare\n\n'; fi
  printf 'button=next\ntitle=Next\nicon=forward.fill\nlook=bare\n'
}

# Asks Music for one value of the current song, only while Music runs, so that a read never opens it.
music() {
  pgrep -xq Music && osascript -e "tell application \"Music\" to $1" 2>/dev/null
}

case "$1" in
  read)
    if [ "$OPENSPOT_REASON" = spot.preview ]; then
      card "Midnight Drive" "Neon Coast" 0.42 "1:42" playing "$here/cover.jpg"
      exit 0
    fi
    state=$(music "player state as text")
    if [ -z "$state" ] || [ "$state" = stopped ]; then
      printf 'text=song\ntitle=Nothing playing\ndetail=Open Music to play a song\n'
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
