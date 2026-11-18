# The shell helper of Openspot. `. "$OPENSPOT_SH"` gives `esc`, `value`, `openspot_value`, `openspot_input`, `openspot_kv`,
# `openspot_row`, `openspot_rows`, `openspot_serve`, `openspot_keep` and `openspot_paste`.
# Loading starts `cat` once, and each function starts `sed`, `tr` or `awk` only above 1 KB, where a shell loop is too slow.

# Whether the spot.toml beside the script says `mode = "stay"` for it, read with no process: its top level for the script
# named after its folder, and its `[scripts.<name>]` table for another script.
_openspot_stays=
_openspot_name=${0##*/}
_openspot_name=${_openspot_name%.*}
_openspot_folder=${0%/*}
[ "$_openspot_folder" = "$0" ] && _openspot_folder=.
_openspot_table=
case ${_openspot_folder##*/} in
  "$_openspot_name".spot) ;;
  *.spot) _openspot_table=scripts.$_openspot_name ;;
esac
_openspot_in=
[ -z "$_openspot_table" ] && _openspot_in=1
while IFS= read -r _openspot_line; do
  _openspot_line=${_openspot_line#"${_openspot_line%%[! ]*}"}
  case $_openspot_line in
    '['*)
      _openspot_in=
      case $_openspot_line in "[$_openspot_table]"*) [ -n "$_openspot_table" ] && _openspot_in=1 ;; esac
      ;;
    mode=* | mode\ *)
      _openspot_line=${_openspot_line#mode}
      _openspot_line=${_openspot_line#"${_openspot_line%%[!= ]*}"}
      case $_openspot_in$_openspot_line in 1\"stay\"* | 1\'stay\'*) _openspot_stays=1 ;; esac
      ;;
  esac
done < "$_openspot_folder/spot.toml" 2>/dev/null

# All of stdin, read once now, because each `$(value id)` runs in a subshell that would lose it. A staying script keeps
# its stdin for its calls, so this leaves it alone there, and `openspot_serve` fills it with the stdin of each call.
_openspot_stdin=
if [ -z "$_openspot_stays" ]; then
  _openspot_stdin=$(/bin/cat; printf x)
  _openspot_stdin=${_openspot_stdin%x}
fi

_openspot_nl='
'

# Writes text as a value: a backslash as `\\` and a new line as `\n`. It works on the text in memory, so the text
# touches no file.
esc() {
  if [ "${#1}" -gt 1024 ]; then
    printf '%s\n' "$1" | LC_ALL=C /usr/bin/sed -e 's/\\/\\\\/g' -e '$!s/$/\\n/' | LC_ALL=C /usr/bin/tr -d '\n'
    return
  fi
  _openspot_left=${1-}
  _openspot_done=
  while :; do
    case $_openspot_left in
      *\\*) _openspot_done=$_openspot_done${_openspot_left%%\\*}\\\\ _openspot_left=${_openspot_left#*\\} ;;
      *) _openspot_left=$_openspot_done$_openspot_left; break ;;
    esac
  done
  _openspot_done=
  while :; do
    case $_openspot_left in
      *"$_openspot_nl"*) _openspot_done=$_openspot_done${_openspot_left%%"$_openspot_nl"*}\\n _openspot_left=${_openspot_left#*"$_openspot_nl"} ;;
      *) printf %s "$_openspot_done$_openspot_left"; return ;;
    esac
  done
}

# Prints the real text of each value of a key from stdin, such as `value setting.city`, `value input.title` or `value event`,
# one per line: `\n` as a new line and `\\` as a backslash. It prints nothing when stdin has no such value.
value() (
  if [ "${#_openspot_stdin}" -gt 1024 ]; then
    printf %s "$_openspot_stdin" |
      _OPENSPOT_ID=${1-} LC_ALL=C /usr/bin/awk 'index($0, ENVIRON["_OPENSPOT_ID"] "=") == 1 { if (seen++) printf "%s", "\\n"; printf "%s", substr($0, length(ENVIRON["_OPENSPOT_ID"]) + 2) }' |
      LC_ALL=C /usr/bin/sed -e 's/\\\\/\
/g' -e 's/\\\([^n]\)/\
\1/g' -e 's/\\$/\
/' -e 's/\\n/\\/g' |
      LC_ALL=C /usr/bin/tr '\n\\' '\\\n'
    return
  fi
  _openspot_key=${1-}
  _openspot_seen=
  _openspot_left=$_openspot_stdin
  while [ -n "$_openspot_left" ]; do
    case $_openspot_left in
      *"$_openspot_nl"*) _openspot_line=${_openspot_left%%"$_openspot_nl"*} _openspot_left=${_openspot_left#*"$_openspot_nl"} ;;
      *) _openspot_line=$_openspot_left _openspot_left= ;;
    esac
    case $_openspot_line in
      "$_openspot_key="*)
        [ -z "$_openspot_seen" ] || printf '\n'
        _openspot_seen=1
        _openspot_line=${_openspot_line#"$_openspot_key="}
        set -f
        IFS=\\
        set -- $_openspot_line
        _openspot_plain=1
        for _openspot_part; do
          if [ -n "$_openspot_plain" ]; then
            printf %s "$_openspot_part"
            _openspot_plain=
          else
            case $_openspot_part in
              '') printf '\\'; _openspot_plain=1 ;;
              n*) printf '\n%s' "${_openspot_part#n}" ;;
              *) printf '\\%s' "$_openspot_part" ;;
            esac
          fi
        done
        ;;
    esac
  done
)

# Prints the real text of each value of a key from a text, such as the frame that an `openspot` call prints, as `value`
# does from stdin.
openspot_value() (
  _openspot_stdin=${2-}
  value "${1-}"
)

# Prints the stdin of the call as it came.
openspot_input() {
  printf %s "$_openspot_stdin"
}

# Sets `_openspot_text` to the real text of a value: `\n` as a new line and `\\` as a backslash. It starts `sed` and `tr`
# only above 1 KB.
_openspot_decode() {
  if [ "${#1}" -gt 1024 ]; then
    _openspot_text=$(printf %s "$1" | LC_ALL=C /usr/bin/sed -e 's/\\\\/\
/g' -e 's/\\\([^n]\)/\
\1/g' -e 's/\\$/\
/' -e 's/\\n/\\/g' | LC_ALL=C /usr/bin/tr '\n\\' '\\\n'; printf x)
    _openspot_text=${_openspot_text%x}
    return
  fi
  _openspot_text=
  _openspot_rest=$1
  while :; do
    case $_openspot_rest in
      *\\*)
        _openspot_text=$_openspot_text${_openspot_rest%%\\*}
        _openspot_rest=${_openspot_rest#*\\}
        case $_openspot_rest in
          n*) _openspot_text=$_openspot_text$_openspot_nl _openspot_rest=${_openspot_rest#n} ;;
          \\*) _openspot_text=$_openspot_text\\ _openspot_rest=${_openspot_rest#\\} ;;
          *) _openspot_text=$_openspot_text\\ ;;
        esac
        ;;
      *)
        _openspot_text=$_openspot_text$_openspot_rest
        return
        ;;
    esac
  done
}

# Reads the next call block of a staying script from stdin, and fails at the end of stdin (protocol: Modes). It sets `_openspot_call`,
# `_openspot_args` with one written argument on each line, and `_openspot_stdin` with the other lines of the block, the stdin
# of the call. A stop block gives no call.
_openspot_next() {
  _openspot_call= _openspot_args= _openspot_stdin= _openspot_count=0
  while IFS= read -r _openspot_line; do
    case $_openspot_line in
      '') [ -z "$_openspot_call" ] || return 0 ;;
      call=*) _openspot_call=${_openspot_line#call=} ;;
      arg=*)
        [ "$_openspot_count" = 0 ] || _openspot_args=$_openspot_args$_openspot_nl
        _openspot_args=$_openspot_args${_openspot_line#arg=}
        _openspot_count=$((_openspot_count + 1))
        ;;
      *) [ -z "$_openspot_call" ] || _openspot_stdin=$_openspot_stdin$_openspot_line$_openspot_nl ;;
    esac
  done
  return 1
}

# Runs a function with the three parts of each call: its arguments, its variables and its stdin (protocol: Modes). A script that runs
# once runs it once, with the arguments after its name, and returns its code. A staying script runs it for each call block
# on stdin, one at a time, and prints `call=<n>` before its output and `end=<n>` after it. The function gets an empty
# stdin: the stdin of the call stays in memory, for `value` and `openspot_input`, so it touches no file and no pipe.
openspot_serve() {
  _openspot_main=$1
  shift
  if [ -z "$_openspot_stays" ]; then
    "$_openspot_main" "$@" </dev/null
    return
  fi
  while _openspot_next; do
    set --
    _openspot_left=$_openspot_args
    while [ "$_openspot_count" -gt 0 ]; do
      _openspot_decode "${_openspot_left%%"$_openspot_nl"*}"
      set -- "$@" "$_openspot_text"
      case $_openspot_left in
        *"$_openspot_nl"*) _openspot_left=${_openspot_left#*"$_openspot_nl"} ;;
        *) break ;;
      esac
    done
    printf 'call=%s\n---\n' "$_openspot_call"
    "$_openspot_main" "$@" </dev/null
    printf '\n---\nend=%s\n---\n' "$_openspot_call"
  done
}

# Prints one line of a block with its value written for you, so that a new line or a backslash in the value stays in it (protocol: The calls).
openspot_kv() {
  printf '%s=' "$1"
  esc "${2-}"
  printf '\n'
}

# Prints one item, a `text` block, after a blank line: its id and title, and its detail and icon when they are given, each
# written for you (protocol: The calls). More lines of the item can follow with `openspot_kv`.
openspot_row() {
  printf '\n'
  openspot_kv text "$1"
  openspot_kv title "${2-}"
  [ -z "${3-}" ] || openspot_kv detail "$3"
  [ -z "${4-}" ] || openspot_kv icon "$4"
}

# Prints an item for each line of stdin, a `text` block or one of the kind given, such as `switch`. A line holds its id, title, detail
# and icon split by tabs, and after them any more `key=value` fields of the block. Each backslash is written for you, and an
# empty field prints no line (protocol: The calls).
openspot_rows() {
  LC_ALL=C /usr/bin/sed 's/\\/\\\\/g' | LC_ALL=C /usr/bin/awk -F '\t' -v kind="${1:-text}" '
    NF {
      printf "\n%s=%s\n", kind, $1
      if ($2 != "") printf "title=%s\n", $2
      if ($3 != "") printf "detail=%s\n", $3
      if ($4 != "") printf "icon=%s\n", $4
      for (i = 5; i <= NF; i++) if ($i != "") print $i
    }
    END { if (NR) print "" }'
}

# Keeps a text in a file as a whole: the second argument, or all of stdin with no second argument. It writes a new file
# beside the old one and moves it into place, so that a reader gets the whole old text or the whole new one. It makes the
# folder of the file, and fails with the old file as it was.
openspot_keep() {
  case $1 in */*) /bin/mkdir -p "${1%/*}" 2>/dev/null || return 1 ;; esac
  _openspot_part=$(/usr/bin/mktemp "$1.XXXXXX" 2>/dev/null) || return 1
  if [ $# -gt 1 ]; then printf %s "$2"; else /bin/cat; fi > "$_openspot_part" && /bin/mv -f "$_openspot_part" "$1" && return 0
  /bin/rm -f "$_openspot_part"
  return 1
}

# Pastes a text into the front app, then puts back the text that the clipboard held, also when the paste fails. A clipboard
# that held no text is cleared, so the pasted text does not stay on it. It returns the code of the paste, and prints what
# the paste prints. It needs `uses=clipboard`.
openspot_paste() {
  _openspot_held=$(openspot clipboard read </dev/null 2>/dev/null; printf x)
  printf %s "${1-}" | openspot clipboard copy > /dev/null || return
  openspot clipboard paste </dev/null
  _openspot_code=$?
  [ "$_openspot_code" != 0 ] || sleep "${_openspot_paste_pause:-0.3}"
  printf %s "${_openspot_held%x}" | openspot clipboard copy > /dev/null
  return "$_openspot_code"
}
