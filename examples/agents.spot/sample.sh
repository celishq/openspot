#!/bin/sh
printf 'frame=\nclass=gap-part card:relative\n\ncard=card\nclass=hidden card:flex absolute inset-0\nlimit1=claude|0.62|working\nlimit2=openai|0.28|waiting\n'
printf 'task1=waiting|Fix a flaky test|openai|website\ntask2=working|Rewrite the README|claude|openspot\ntask3=working|Add a pricing page|claude|website\n\n'
printf 'number=count\nclass=hidden bar:flex\nvalue=3\ntitle=Sessions\n\n'
printf 'items=items\nclass=card:hidden\n\n'
printf 'item=codex/702\nparent=items\ntitle=Fix a flaky test\ndetail=website · waits for you · 41%% context\n\n'
printf 'item=claude/611\nparent=items\ntitle=Rewrite the README\ndetail=openspot · working · 34%% context\n\n'
printf 'item=claude/4821\nparent=items\ntitle=Add a pricing page\ndetail=website · working · 12%% context\n'
