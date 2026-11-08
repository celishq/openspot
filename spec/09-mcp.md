# 09 MCP

`draft` · Needs 01 and 02.

An MCP server that talks over stdio can be a spot. Write an executable file that starts it, with `mcp=true` in its
header. This one needs Node.js:

```text
#!/bin/sh
# name=Files
# symbol=folder
# mcp=true
exec npx -y @modelcontextprotocol/server-filesystem "$HOME/Documents"
```

- Its sheet lists each tool as an action and each resource as a row. A tool with input asks for it in a form.
- A tool's text answer and a picked resource's text show as a toast.
- Each call starts the server, and the server ends after its answer. Openspot reads only the header in a scan.
- A tool called `read` or with a default id does not show.

## Rules

| ID | Rule |
|---|---|
| F10 | A script with `mcp=true` is an MCP server on stdio. Its tools are actions, and its resources are rows. A scan never starts it. |
