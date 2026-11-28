export LC_ALL=C
cd "${1:-$(dirname "$0")/..}" || exit 1

spot_folders="spots store examples"

need() {
  for folder; do
    [ -d "$folder" ] || { echo "$(basename "$0"): $(pwd)/$folder is missing." >&2; exit 1; }
  done
}

compare() {
  list=scripts/breaks/$1.txt
  [ -f "$list" ] || { echo "$(basename "$0"): $(pwd)/$list is missing." >&2; exit 1; }
  sort "$2" >"$2.found"
  sort "$list" >"$2.listed"
  added=$(comm -13 "$2.listed" "$2.found")
  gone=$(comm -23 "$2.listed" "$2.found")
  rm -f "$2.found" "$2.listed"
  [ -z "$added" ] || printf '%s\n%s\n' "$3" "$added" >&2
  [ -z "$gone" ] || printf 'Fixed, so remove each from %s:\n%s\n' "$list" "$gone" >&2
  [ -z "$added" ] && [ -z "$gone" ]
}
