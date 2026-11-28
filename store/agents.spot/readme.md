Shows what Claude Code and Codex are doing: the usage limit of each, and each running session with the last thing you
asked it, whether it's working or waiting for you, and how full its context is. Press a session to bring its terminal to
the front, with its tmux pane. ⌘K starts a new Claude or Codex session, in a new tmux window when tmux runs, or in
Terminal.

Set the command you start each agent with in its Settings, such as `claude-personal`. It runs in your own shell, so an
alias works, and Agents reads the sessions of the config folder that the alias sets, such as
`CLAUDE_CONFIG_DIR=~/.claude-personal`.

It reads the session files that Claude Code and Codex keep on your Mac. Claude's limit comes from
`claude -p /usage`, which spends no tokens and runs at most every five minutes. It polls: while it shows, it reads the
sessions every 5 seconds. A spot that ships with Openspot reads only on an event.
