#!/bin/sh
printf 'detail=1h 24m left\nactive=true\nrecents=false\n\n'
printf 'button=open\ntitle=Select\n\n'
printf 'row=off\ntitle=Turn off\n\n'
printf 'row=1800\ntitle=30 minutes\n\nrow=3600\ntitle=1 hour\n\nrow=7200\ntitle=2 hours\n\n'
printf 'row=14400\ntitle=4 hours\n\nrow=28800\ntitle=8 hours\n\nrow=0\ntitle=Until turned off\n'
printf '\nrow=display\ntitle=Keep the display on\ndetail=Off lets the screen sleep and lock\ntype=toggle\nvalue=true\nclose=false\n'
printf '\nrow=lid\ntitle=Work with the lid closed\ndetail=Keeps working when closed\ntype=toggle\nvalue=false\nclose=false\n'
