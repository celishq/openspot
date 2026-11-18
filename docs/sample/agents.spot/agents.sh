#!/bin/sh
# title=Agents
# icon=sparkles
# on=panel.open
# view=card.swift
printf 'grid=items\ngrid.small=card\n\nview=card\nlimit1=claude|0.62|working\nlimit2=openai|0.28|waiting\n'
printf 'task1=waiting|Fix a flaky test|openai|website\ntask2=working|Rewrite the README|claude|openspot\ntask3=working|Add a pricing page for the new plans|claude|website\n\n'
printf 'repeat=items\n\n'
printf 'row=codex/702\ntitle=Fix a flaky test\ndetail=website · waits for you · 41%% context\n\n'
printf 'row=claude/611\ntitle=Rewrite the README\ndetail=openspot · working · 34%% context\n\n'
printf 'row=claude/4821\ntitle=Add a pricing page\ndetail=website · working · 12%% context\n'
