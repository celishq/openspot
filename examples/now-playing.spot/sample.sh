#!/bin/sh
printf 'frame=\nclass=gap-part large:flex-row\n\n'
printf 'picture=cover\nclass=large:w-1/2 large:aspect-square\nicon=music.note\n\n'
printf 'box=side\nclass=gap-part large:grow\n\ntext=song\nparent=side\nclass=bar:flex\ntitle=Midnight Drive\ndetail=Neon Coast\n\n'
printf 'number=time\nparent=side\nmax=1\nchart=bar\ndisplay=1:42\nvalue=0.42\n\n'
printf 'box=controls\nparent=side\nclass=gap-part large:flex-row large:justify-between\n\nbutton=prev\nparent=controls\ntitle=Previous\nicon=backward.fill\nlook=bare\nclose=false\n\n'
printf 'button=play\nparent=controls\ntitle=Pause\nicon=pause.fill\nlook=bare\nclose=false\n\n'
printf 'button=next\nparent=controls\ntitle=Next\nicon=forward.fill\nlook=bare\nclose=false\n'
