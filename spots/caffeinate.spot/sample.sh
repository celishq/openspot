#!/bin/sh
printf 'frame=\ndetail=1h 24m left\nactive=true\nrecents=false\n\n'
printf 'button=open\ntitle=Select\n\n'
printf 'text=off\ntitle=Turn off\n\n'
printf 'text=1800\ntitle=30 minutes\n\ntext=7200\ntitle=2 hours\n\n'
printf 'text=custom\ntitle=Custom…\n\ntext=0\ntitle=Until turned off\n'
printf '\nswitch=display\ntitle=Keep the display on\ndetail=Off lets the screen lock\nicon=display\npin=bottom\nvalue=true\nclose=false\n'
printf '\nswitch=lid\ntitle=Work with the lid closed\ndetail=Can grow hot in a bag\nicon=laptopcomputer\npin=bottom\nvalue=false\nclose=false\n'
