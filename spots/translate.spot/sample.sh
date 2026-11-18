#!/bin/sh
languages='\noption=en\ntitle=English\n\noption=fr\ntitle=French\n\noption=de\ntitle=German\n\noption=it\ntitle=Italian\n\noption=ja\ntitle=Japanese\n\noption=es\ntitle=Spanish\n\noption=uk\ntitle=Ukrainian\n'
printf 'frame=\ngrid=source source . .\ngrid=input input input input\ngrid=input input input swap\ngrid=- - - swap\n'
printf 'grid=target target . swap\ngrid=output output output output\ngrid=output output output copy\n\n'
printf "choice=source\nvalue=auto\n\noption=auto\ntitle=Auto (English)\n$languages\n"
printf 'field=input\nplaceholder=Type or paste text\nvalue=Good morning! Shall we meet for lunch at noon?\n\n'
printf "choice=target\nvalue=fr\n$languages\n"
printf 'field=output\nvalue=Bonjour ! On se retrouve pour déjeuner à midi ?\nplaceholder=Translation\nreadonly=true\n\n'
printf 'button=swap\nicon=arrow.up.arrow.down\nshortcut=cmd+shift+s\n\n'
printf 'button=copy\nalign=right\nlook=chip\ntitle=Copy\nshortcut=cmd+return\nclose=true\n'
