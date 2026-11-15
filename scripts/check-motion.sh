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
echo "Motion check passed."
