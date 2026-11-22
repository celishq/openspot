#!/bin/sh
languages='\noption=en\ntitle=English\n\noption=fr\ntitle=French\n\noption=de\ntitle=German\n\noption=it\ntitle=Italian\n\noption=ja\ntitle=Japanese\n\noption=es\ntitle=Spanish\n\noption=uk\ntitle=Ukrainian\n'
printf 'frame=\nclass=gap-part\n\n'
printf 'box=pair\nclass=relative grow gap-part\n\nbox=top\nparent=pair\nclass=grow gap-part\n\n'
printf "choice=source\nparent=top\nclass=self-start\nvalue=auto\n\noption=auto\ntitle=Auto (English)\n$languages\n"
printf 'box=text\nparent=top\nclass=relative grow\n\n'
printf 'field=input\nparent=text\nclass=absolute inset-0\ntype=multiline\nplaceholder=Type or paste text\nvalue=Good morning! Shall we meet for lunch at noon?\n\n'
printf 'box=seam\nparent=pair\nclass=absolute inset-0 justify-center items-end pr-2\n\n'
printf 'button=swap\nparent=seam\nclass=backdrop-blur rounded-full\nicon=arrow.up.arrow.down\nshortcut=cmd+shift+s\nclose=false\n\n'
printf 'box=bottom\nparent=pair\nclass=grow gap-part\n\n'
printf "choice=target\nparent=bottom\nclass=self-start\nvalue=fr\n$languages\n"
printf 'box=result\nparent=bottom\nclass=relative grow\n\n'
printf 'field=output\nparent=result\nclass=absolute inset-0\ntype=multiline\nvalue=Bonjour ! On se retrouve pour déjeuner à midi ?\nplaceholder=Translation\nreadonly=true\n\n'
printf 'box=corner\nparent=result\nclass=absolute inset-0 justify-end items-end p-2\n\n'
printf 'button=copy\nparent=corner\nalign=right\nlook=chip\ntitle=Copy\nshortcut=cmd+return\n'
