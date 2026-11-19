#!/bin/sh
printf 'frame=\ngrid=items\ngrid.small=card\ngrid.bar=count\n\nview=card\nlimit1=claude|0.62|working\nlimit2=openai|0.28|waiting\n'
printf 'task1=waiting|Fix a flaky test|openai|website\ntask2=working|Rewrite the README|claude|openspot\ntask3=working|Add a pricing page|claude|website\n\n'
printf 'number=count\nvalue=3\ntitle=Sessions\n\n'
printf 'repeat=items\n\n'
printf 'text=codex/702\ntitle=Fix a flaky test\ndetail=website · waits for you · 41%% context\n\n'
printf 'text=claude/611\ntitle=Rewrite the README\ndetail=openspot · working · 34%% context\n\n'
printf 'text=claude/4821\ntitle=Add a pricing page\ndetail=website · working · 12%% context\n'
