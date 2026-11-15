#!/bin/sh
. "$(dirname "$0")/checks.sh"
need app scripts
found=$(grep -rnE --include='*.swift' '\.(spring|easeIn|easeOut|easeInOut|linear|smooth|snappy|bouncy|timingCurve)\(|\.(smooth|snappy|bouncy|linear|easeIn|easeOut|easeInOut)([^A-Za-z(]|$)|\.delay\(|LinearKeyframe|SpringKeyframe|CubicKeyframe|NSAnimationContext|CABasicAnimation|CASpringAnimation' \
  app scripts \
  | grep -v '^app/Shell/Surface/SpotMotion.swift:' \
  | grep -v '^app/Core/Panel/MotionTokens.swift:' \
  | grep -v 'progressViewStyle(.linear)')
if [ -n "$found" ]; then
  echo "A motion writes its own curve. Use a curve of SpotMotion, with its numbers in MotionTokens:" >&2
  echo "$found" >&2
  exit 1
fi
hidden=$(grep -rnE --include='*.swift' '\.opacity\([^)]*\? *(1 *: *0|0 *: *1)\)' app/Shell)
if [ -n "$hidden" ]; then
  echo "A view hides with opacity 0, which drops its drawing. Hide it with MotionTokens.hiddenOpacity, and stop its hits:" >&2
  echo "$hidden" >&2
  exit 1
fi
echo "Motion check passed."
