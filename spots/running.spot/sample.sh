#!/bin/sh
cat <<'EOF'
grid=spots
grid.small=top

text=top
title=Links
detail=412 ms CPU · 38 runs · 48 ms each

repeat=spots

row=links
title=Links
detail=412 ms CPU · 38 runs · 48 ms each
runs=38
cpu=0.412

row=emoji
title=Emojis & Symbols
detail=236 ms CPU · 21 runs · 31 ms each
runs=21
cpu=0.236

row=cpu
title=CPU
detail=181 ms CPU · 720 runs · 24 ms each
runs=720
cpu=0.181

row=apps
title=Apps
detail=94 ms CPU · 35 runs · 13 ms each
runs=35
cpu=0.094

row=translate
title=Translate
detail=61 ms CPU · 9 runs · 90 ms each
runs=9
cpu=0.061

row=battery
title=Battery
detail=22 ms CPU · 120 runs · 4 ms each
runs=120
cpu=0.022
EOF
