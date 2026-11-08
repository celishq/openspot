# The shell helper of Openspot. `. "$OPENSPOT_SH"` gives `esc` and `value`, and `next` and `arg` in a staying script.
# Loading starts `cat` once, and each function starts `sed`, `tr` or `awk` only above 1 KB, where a shell loop is too slow.

# All of stdin, read once now, because each `$(value id)` runs in a subshell that would lose it. A staying script keeps
# its stdin for its calls, so this leaves it alone there, and `next` fills it with the values of each call.
_openspot_stdin=
if [ -z "${OPENSPOT_STAY:-}" ]; then
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

# Reads the next call of a staying script from stdin, and fails at the end of stdin. It sets `call` to its number, `reason`
# to why a read came, and `stop` to the number of a call that a stop block names. `arg <n>` and `value <id>` then give the
# arguments and the values of that call.
next() {
  call= reason= stop= _openspot_args= _openspot_stdin=
  while IFS= read -r _openspot_line; do
    case $_openspot_line in
      '') [ -z "$call$stop" ] || return 0 ;;
      call=*) [ -n "$call$_openspot_args$_openspot_stdin" ] || call=${_openspot_line#call=} ;;
      stop=*) [ -n "$call" ] && _openspot_stdin="$_openspot_stdin$_openspot_line
" || stop=${_openspot_line#stop=} ;;
      reason=*) [ -n "$_openspot_args" ] && _openspot_stdin="$_openspot_stdin$_openspot_line
" || reason=${_openspot_line#reason=} ;;
      arg=*) _openspot_args="$_openspot_args$_openspot_line
" ;;
      *) _openspot_stdin="$_openspot_stdin$_openspot_line
" ;;
    esac
  done
  return 1
}

# Prints the real text of argument `n` of the call that `next` read, counting from 1, as `value` prints a value.
arg() (
  _openspot_count=0
  while IFS= read -r _openspot_line; do
    _openspot_count=$((_openspot_count + 1))
    if [ "$_openspot_count" = "${1-}" ]; then
      _openspot_stdin=$_openspot_line
      value arg
      return
    fi
  done <<EOF_OPENSPOT
$_openspot_args
EOF_OPENSPOT
)
