#!/bin/sh
. "$TASKS/checks.sh"
file panel.png
used render && file panel.png | grep -q "PNG image"
