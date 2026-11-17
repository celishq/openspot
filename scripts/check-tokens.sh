#!/bin/sh
. "$(dirname "$0")/checks.sh"
need app/Shell
found=$(mktemp)
trap 'rm -f "$found"' EXIT
find app/Shell -name '*.swift' | grep -vE '^app/Shell/(Picture|Mac|Tools)/|^app/Shell/Theme/(Spot(Theme|Type)(\+[A-Za-z]+)?|ThemeColor\+AppKit)\.swift$' | sort | while read -r file; do
  awk -v f="$file" '
    /Duration|TimeInterval|\.milliseconds\(|\.seconds\(|asyncAfter|Task\.sleep/ { next }
    {
      line = $0
      gsub(/"([^"\\]|\\.)*"/, "\"\"", line)
      gsub(/\[[0-9]+\]/, "[]", line)
      gsub(/[\/*] *2([^0-9.]|$)/, " ", line)
      gsub(/(^|[^0-9.A-Za-z_])2 *[*\/]/, " ", line)
      num = "(([2-9]|[1-9][0-9]+)(\\.[0-9]+)?|[0-9]*\\.[0-9]*[1-9][0-9]*)([^0-9A-Za-z_.]|$)"
      call = "\\.(padding|frame|offset|position|blur|shadow|opacity|scaleEffect|minimumScaleFactor|tracking|kerning|lineSpacing|stroke|strokeBorder|font|system|systemFont)\\(([^()]*(\\([^()]*\\)[^()]*)*[^0-9A-Za-z_.])?"
      label = "(^|[^A-Za-z0-9_])(spacing|width|height|minWidth|maxWidth|idealWidth|minHeight|maxHeight|idealHeight|radius|cornerRadius|lineWidth|size|ofSize|x|y|dx|dy|gap|side|location|leastScale|inset|line): *(-?[^,)]*[^0-9A-Za-z_.])?"
      decl = "(: *(CGFloat|CGSize|CGPoint|NSSize|EdgeInsets|Double) *= *([^=]*[^0-9A-Za-z_.])?|(CGSize|NSSize|CGPoint|EdgeInsets|NSRect|CGRect)\\(([^)]*[^0-9A-Za-z_.])?)"
      fraction = "static let [A-Za-z]+ = *-?[0-9]*\\.[0-9]*[1-9]"
      colour = "(Color|NSColor)\\((red|white|hue|srgbRed|calibratedWhite|deviceWhite): *[0-9]|(Color|NSColor)\\.(white|black|gray|red|green|blue|orange|yellow|purple|pink|cyan|mint|teal|indigo|brown)([^A-Za-z0-9_]|$)|(^|[^A-Za-z0-9_])\\.(white|black|gray|red|green|blue|orange|yellow|purple|pink|cyan|mint|teal|indigo|brown)([^A-Za-z0-9_]|$)"
      if (line ~ (call num) || line ~ (label num) || line ~ (decl num) || line ~ fraction || line ~ colour) print f ": " $0
    }
  ' "$file"
done | sed 's/: *$//; s/:  */: /' >"$found"
compare tokens "$found" "A view draws with a number or a colour of its own. Name it in SpotTokens, SpotTheme, SpotType or MotionTokens, and read the name:" || exit 1
echo "Tokens check passed."
