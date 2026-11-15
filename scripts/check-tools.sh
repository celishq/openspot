#!/bin/sh
. "$(dirname "$0")/checks.sh"
need app
found=$(find app -name '*.swift' -not -path 'app/Tests/*' -not -path '*/Openspot.xcodeproj/*' | sort | while read -r file; do
  awk -v f="$file" '
    /^[[:space:]]*#if OPENSPOT_TOOLS[[:space:]]*$/ && !depth { depth = 1; next }
    depth && /^[[:space:]]*#if/ { depth++; next }
    depth && /^[[:space:]]*#endif/ { depth--; next }
    !depth && /OPENSPOT_PROBE|SpotMotionProbe/ { print f ":" FNR ": " $0 }
  ' "$file"
done)
if [ -f app/project.yml ]; then
  found="$found$(awk '
    { match($0, /^ */); indent[NR] = RLENGTH; text[NR] = $0 }
    /OPENSPOT_TOOLS/ {
      parent = ""
      for (i = NR - 1; i > 0; i--) if (indent[i] < indent[NR] && text[i] ~ /:[[:space:]]*$/) { parent = text[i]; break }
      if (parent !~ /^[[:space:]]*Debug:[[:space:]]*$/) print "app/project.yml:" NR ": " $0
    }
  ' app/project.yml)"
fi
if [ -f scripts/release.sh ]; then
  found="$found$(grep -n OPENSPOT_TOOLS scripts/release.sh | sed 's|^|scripts/release.sh:|')"
fi
if [ -n "$found" ]; then
  echo "The shipped app holds the motion probe. Keep it inside #if OPENSPOT_TOOLS, which only a Debug build or a tool run sets:" >&2
  echo "$found" >&2
  exit 1
fi
echo "Tools check passed."
