#!/bin/sh
cd "$(dirname "$0")/../app" || exit 1
found=$(grep -rnE '\.(spring|easeIn|easeOut|easeInOut|linear|smooth|snappy|bouncy|timingCurve)\(|\.(smooth|snappy|bouncy|linear|easeIn|easeOut|easeInOut)([^A-Za-z(]|$)|\.delay\(|LinearKeyframe|SpringKeyframe|CubicKeyframe|NSAnimationContext|CABasicAnimation|CASpringAnimation' \
  Core Shell --include='*.swift' \
  | grep -v '^Shell/Surface/SpotMotion.swift:' \
  | grep -v '^Core/Panel/MotionTokens.swift:' \
  | grep -v 'progressViewStyle(.linear)')
if [ -n "$found" ]; then
  echo "A motion writes its own curve. Use a curve of SpotMotion, with its numbers in MotionTokens:"
  echo "$found"
  exit 1
fi
