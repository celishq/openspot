#!/bin/sh
printf 'grid=look look look look\ngrid=key key key key\ngrid=make make make make\n\n'
printf 'choice=look\ntitle=Look\nvalue=colorful\n\n'
printf 'option=colorful\ntitle=Colorful\n\noption=gold\ntitle=Gold\n\noption=metallic\ntitle=Metallic\n\noption=hearts\ntitle=Hearts\n\n'
printf 'field=key\ntype=hotkey\ntitle=Shortcut\nvalue=option+c\n\n'
printf 'button=make\ntitle=Make your own with AI\nalign=center\nshortcut=cmd+n\n\n'
printf 'button=paste\ntitle=Paste a look from an AI chat\nshortcut=cmd+shift+v\n\n'
printf 'button=mine\ntitle=Show my looks in Finder\nshortcut=cmd+o\n'
