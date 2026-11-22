#!/bin/sh
languages='\noption=en\ntitle=English\n\noption=fr\ntitle=French\n\noption=de\ntitle=German\n\noption=it\ntitle=Italian\n\noption=ja\ntitle=Japanese\n\noption=es\ntitle=Spanish\n\noption=uk\ntitle=Ukrainian\n'
printf 'frame=\nclass=gap-part\n\n'
printf "choice=source\nvalue=auto\n\noption=auto\ntitle=Auto (English)\n$languages\n"
printf 'field=input\nclass=grow\ntype=multiline\nplaceholder=Type or paste text\nvalue=Good morning! Shall we meet for lunch at noon?\n\n'
printf 'box=middle\nclass=flex-row items-center gap-part\n\nbox=line\nparent=middle\nclass=grow h-px bg-tile\n\n'
printf 'button=swap\nparent=middle\nicon=arrow.up.arrow.down\nshortcut=cmd+shift+s\nclose=false\n\n'
printf "choice=target\nvalue=fr\n$languages\n"
printf 'box=result\nclass=relative grow\n\n'
printf 'field=output\nparent=result\nclass=absolute inset-0\ntype=multiline\nvalue=Bonjour ! On se retrouve pour déjeuner à midi ?\nplaceholder=Translation\nreadonly=true\n\n'
printf 'box=corner\nparent=result\nclass=absolute inset-0 justify-end items-end p-2\n\n'
printf 'button=copy\nparent=corner\nalign=right\nlook=chip\ntitle=Copy\nshortcut=cmd+return\n'
