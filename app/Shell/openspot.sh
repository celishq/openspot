# The shell helper of Openspot. `. "$OPENSPOT_SH"` gives `esc`, `value`, `openspot_kv`, `openspot_row`, `openspot_rows` and
# `openspot_serve`.
# Loading starts `cat` once, and each function starts `sed`, `tr` or `awk` only above 1 KB, where a shell loop is too slow.

# Whether the header of the script says `mode=stay` or `mode=always`: the comment lines at its top, read with no process.
_openspot_stays=
while IFS= read -r _openspot_line; do
  case $_openspot_line in
    '#'*) _openspot_line=${_openspot_line#\#} ;;
    *) break ;;
  esac
  _openspot_line=${_openspot_line#"${_openspot_line%%[! ]*}"}
  case $_openspot_line in
    mode=stay | mode=always) _openspot_stays=1 ;;
  esac
done < "$0" 2>/dev/null

# All of stdin, read once now, because each `$(value id)` runs in a subshell that would lose it. A staying script keeps
# its stdin for its calls, so this leaves it alone there, and `openspot_serve` fills it with the stdin of each call.
_openspot_stdin=
if [ -z "$_openspot_stays" ]; then
  _openspot_stdin=$(/bin/cat; printf x)
  _openspot_stdin=${_openspot_stdin%x}
fi

# Writes text as a value: a backslash as `\\` and a new line as `\n`.
esc() {
  if [ "${#1}" -gt 1024 ]; then
    printf '%s\n' "$1" | LC_ALL=C /usr/bin/sed -e 's/\\/\\\\/g' -e '$!s/$/\\n/' | LC_ALL=C /usr/bin/tr -d '\n'
    return
  fi
  _openspot_more=
  while IFS= read -r _openspot_line; do
    [ -z "$_openspot_more" ] || printf '\\n'
    _openspot_more=1
    while :; do
      case $_openspot_line in
        *\\*)
          IFS=\\ read -r _openspot_head _openspot_line <<EOF_OPENSPOT
$_openspot_line.
EOF_OPENSPOT
          printf '%s\\\\' "$_openspot_head"
          _openspot_line=${_openspot_line%.}
          ;;
        *)
          printf %s "$_openspot_line"
          break
          ;;
      esac
    done
  done <<EOF_OPENSPOT
${1-}
EOF_OPENSPOT
}

# Prints the real text of one value from stdin: `\n` as a new line and `\\` as a backslash. It prints nothing when stdin has no such value.
value() (
  if [ "${#_openspot_stdin}" -gt 1024 ]; then
    printf %s "$_openspot_stdin" |
      _OPENSPOT_ID=${1-} LC_ALL=C /usr/bin/awk 'index($0, ENVIRON["_OPENSPOT_ID"] "=") == 1 { printf "%s", substr($0, length(ENVIRON["_OPENSPOT_ID"]) + 2); exit }' |
      LC_ALL=C /usr/bin/sed -e 's/\\\\/\
/g' -e 's/\\\([^n]\)/\
\1/g' -e 's/\\$/\
/' -e 's/\\n/\\/g' |
      LC_ALL=C /usr/bin/tr '\n\\' '\\\n'
    return
  fi
  while IFS= read -r _openspot_line; do
    case $_openspot_line in
      "${1-}="*)
        _openspot_line=${_openspot_line#"$1="}
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
        return
        ;;
    esac
  done <<EOF_OPENSPOT
$_openspot_stdin
EOF_OPENSPOT
)

_openspot_nl='
'

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

# Reads the next call block of a staying script from stdin, and fails at the end of stdin (Y8). It sets `_openspot_call`,
# `_openspot_args` with one written argument on each line, and `_openspot_stdin`, and exports each variable of the call in
# place of those of the call before. A stop block gives no call.
_openspot_next() {
  _openspot_call= _openspot_args= _openspot_stdin=
  for _openspot_name in $_openspot_env; do unset "$_openspot_name"; done
  _openspot_env=
  while IFS= read -r _openspot_line; do
    case $_openspot_line in
      '') [ -z "$_openspot_call" ] || return 0 ;;
      call=*) _openspot_call=${_openspot_line#call=} ;;
      arg=*) _openspot_args="${_openspot_args:+$_openspot_args$_openspot_nl}${_openspot_line#arg=}" ;;
      env.OPENSPOT_*=*)
        _openspot_name=${_openspot_line%%=*}
        _openspot_name=${_openspot_name#env.}
        case $_openspot_name in *[!A-Z0-9_]*) continue ;; esac
        _openspot_decode "${_openspot_line#*=}"
        export "$_openspot_name=$_openspot_text"
        _openspot_env="$_openspot_env $_openspot_name"
        ;;
      input=*)
        _openspot_decode "${_openspot_line#input=}"
        _openspot_stdin=$_openspot_text
        ;;
    esac
  done
  return 1
}

# Runs the function in `_openspot_main` with these arguments, and with `_openspot_stdin` as its stdin.
_openspot_run() {
  if [ -z "$_openspot_stdin" ]; then
    "$_openspot_main" "$@" </dev/null
    return
  fi
  _openspot_feed=${_openspot_stdin%"$_openspot_nl"}
  "$_openspot_main" "$@" <<EOF_OPENSPOT
$_openspot_feed
EOF_OPENSPOT
}

# Runs a function with the three parts of each call: its arguments, its variables and its stdin (Y9). A script that runs
# once runs it once, with the arguments after its name, and returns its code. A staying script runs it for each call block
# on stdin, one at a time, and prints `call=<n>` before its output and `end=<n>` after it.
openspot_serve() {
  _openspot_main=$1
  shift
  if [ -z "$_openspot_stays" ]; then
    _openspot_run "$@"
    return
  fi
  while _openspot_next; do
    set --
    if [ -n "$_openspot_args" ]; then
      while IFS= read -r _openspot_line; do
        _openspot_decode "$_openspot_line"
        set -- "$@" "$_openspot_text"
      done <<EOF_OPENSPOT
$_openspot_args
EOF_OPENSPOT
    fi
    printf 'call=%s\n---\n' "$_openspot_call"
    _openspot_run "$@"
    printf '\n---\nend=%s\n---\n' "$_openspot_call"
  done
}

# Prints one line of a block with its value written for you, so that a new line or a backslash in the value stays in it (C8).
openspot_kv() {
  printf '%s=' "$1"
  esc "${2-}"
  printf '\n'
}

# Prints one row after a blank line: its id and title, and its detail and icon when they are given, each written for you
# (C8). More lines of the row can follow with `openspot_kv`.
openspot_row() {
  printf '\n'
  openspot_kv row "$1"
  openspot_kv title "${2-}"
  [ -z "${3-}" ] || openspot_kv detail "$3"
  [ -z "${4-}" ] || openspot_kv icon "$4"
}

# Prints a block for each line of stdin, a row or one of the kind given, such as `text`. A line holds its id, title, detail
# and icon split by tabs, and after them any more `key=value` fields of the block. Each backslash is written for you, and an
# empty field prints no line (C8).
openspot_rows() {
  LC_ALL=C /usr/bin/sed 's/\\/\\\\/g' | LC_ALL=C /usr/bin/awk -F '\t' -v kind="${1:-row}" '
    NF {
      printf "\n%s=%s\n", kind, $1
      if ($2 != "") printf "title=%s\n", $2
      if ($3 != "") printf "detail=%s\n", $3
      if ($4 != "") printf "icon=%s\n", $4
      for (i = 5; i <= NF; i++) if ($i != "") print $i
    }
    END { if (NR) print "" }'
}
