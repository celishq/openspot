#!/bin/sh
export LC_ALL=en_US.UTF-8
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"

# Makes a jq value safe for one line of a text block, and gives the words and the tone of a state of checks.
defs='def esc: gsub("\\\\"; "\\\\") | gsub("\n"; "\\n");
def checks: {SUCCESS: "Checks passed", FAILURE: "Checks failed", ERROR: "Checks failed", PENDING: "Checks running", EXPECTED: "Checks running"}[.state // ""] // "No checks";
def tone: {SUCCESS: "good", FAILURE: "bad", ERROR: "bad", PENDING: "warn", EXPECTED: "warn"}[.state // ""];
def about: (checks + (if .asked then " · To review" else "" end) + " · " + .repo) | esc;'

query='query($mine: String!, $asked: String!) {
  mine: search(query: $mine, type: ISSUE, first: 30) { nodes { ...pull } }
  asked: search(query: $asked, type: ISSUE, first: 30) { nodes { ...pull } }
}
fragment pull on PullRequest {
  title url repository { name }
  commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
}'

# Prints the open pull requests of the person, then those that wait for their review, each one once.
pulls() {
  if ! command -v gh >/dev/null; then
    echo "Install gh to see pull requests." >&2
    exit 1
  fi
  answer=$(gh api graphql -f query="$query" \
    -f mine="is:open is:pr author:@me archived:false" \
    -f asked="is:open is:pr review-requested:@me archived:false") || exit 1
  printf '%s' "$answer" | jq -c 'def shape($asked): {title, url, repo: .repository.name, asked: $asked, state: .commits.nodes[0].commit.statusCheckRollup.state};
    ([.data.mine.nodes[] | shape(false)] + [.data.asked.nodes[] | shape(true)])
    | reduce .[] as $pull ([]; if any(.[]; .url == $pull.url) then . else . + [$pull] end)'
}

case "$1" in
  metric)
    [ "$2" = open ] || exit 1
    list=$(pulls) || exit 1
    printf '%s' "$list" | jq -r "$defs"'"title=\(length) open\nsymbol=arrow.triangle.pull",
      (if length == 0 then "hidden=true" else empty end),
      (.[] | "row=\(.title | esc)\nrow.detail=\(about)", (tone | if . then "row.tone=\(.)" else empty end))'
    ;;
  items)
    list=$(pulls) || exit 1
    printf '%s' "$list" | jq -r "$defs"'.[] | "title=\(.title | esc)\nsubtitle=\(about)\nrun=\(.url | esc)\nsymbol=\({good: "checkmark.circle", bad: "xmark.circle", warn: "clock"}[tone // ""] // "arrow.triangle.pull")\n"'
    ;;
  copy)
    printf '%s' "$2" | pbcopy
    ;;
  *)
    open "$1"
    ;;
esac
