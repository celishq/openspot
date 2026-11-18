#!/bin/sh
printf 'frame=\ndetail=1h 24m left\nactive=true\nrecents=false\n\n'
printf 'button=open\ntitle=Select\n\n'
printf 'row=off\ntitle=Turn off\n\n'
printf 'row=1800\ntitle=30 minutes\n\nrow=7200\ntitle=2 hours\n\n'
printf 'row=custom\ntitle=Custom…\n\nrow=0\ntitle=Until turned off\n'
printf '\nrow=display\ntitle=Keep the display on\ndetail=Off lets the screen lock\nicon=display\npin=bottom\ntype=toggle\nvalue=true\nclose=false\n'
printf '\nrow=lid\ntitle=Work with the lid closed\ndetail=Can grow hot in a bag\nicon=laptopcomputer\npin=bottom\ntype=toggle\nvalue=false\nclose=false\n'
