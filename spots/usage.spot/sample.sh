#!/bin/sh
cat <<'EOF'
frame=
class=gap-part
recents=false

chart=chart
class=h-44 card:hidden

items=spots
class=card:hidden

text=top
class=hidden card:flex
title=Shortcuts
detail=1.4 s CPU a day

box=used
parent=spots
title=Used · last 14 days

number=apps
parent=used
title=Apps
detail=13.1 a day · 1.2 s CPU
route=spot:apps
value=9
value=14
value=11
value=12
value=16
value=13
value=10
value=15
value=12
value=17
value=14
value=11
value=16
value=13
acts=13.07
cpu=1.229
state=used

number=links
parent=used
title=Links
detail=4.8 a day · 343 ms CPU
route=spot:links
value=-
value=-
value=-
value=4
value=6
value=3
value=5
value=4
value=3
value=2
value=3
value=2
value=1
value=2
acts=4.82
cpu=0.343
state=used

box=failing
parent=spots
title=Failing

number=paste
parent=failing
title=Paste screenshot
detail=4 of 19 failed · stopped with an error
route=spot:paste
tone=bad
value=0
value=1
value=2
value=0
value=3
value=1
value=0
value=2
value=4
value=1
value=0
value=2
value=3
value=1
acts=1.36
cpu=0.221
state=bad

box=slow
parent=spots
title=Slow to answer

number=shortcuts
parent=slow
title=Shortcuts
detail=95 in 100 answer within 1.6 s · half within 400 ms
route=spot:shortcuts
tone=warn
value=2
value=1
value=3
value=2
value=0
value=1
value=2
value=3
value=1
value=2
value=2
value=1
value=0
value=2
acts=1.57
cpu=1.421
state=warn

box=unused
parent=spots
title=Unused for 14 days

number=devices
parent=unused
title=Devices
detail=1.1 s CPU a day, 857 ms while hidden
route=spot:devices
value=0
value=0
value=0
value=0
value=0
value=0
value=0
value=0
value=0
value=0
value=0
value=0
value=0
value=0
acts=0.00
cpu=1.093
state=unused

EOF
