#!/bin/sh
[ "$1" != show ] || exit 0
exec openspot playground open
