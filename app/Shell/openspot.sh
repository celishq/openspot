# The shell helper of Openspot. `. "$OPENSPOT_SH"` gives `esc` and `value`, and starts no program.

# All of stdin, read once now, because each `$(value id)` runs in a subshell that would lose it. A staying script keeps
# its stdin for its calls, so this leaves it alone there.
_openspot_stdin=
if [ -z "${OPENSPOT_STAYS:-}" ]; then
  while IFS= read -r _openspot_line || [ -n "$_openspot_line" ]; do
    _openspot_stdin=$_openspot_stdin$_openspot_line'
'
  done
fi

# Writes text as a value: a backslash as `\\` and a new line as `\n`.
esc() {
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
