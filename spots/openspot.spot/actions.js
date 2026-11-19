const calls = {
  settings: (id) => ["spot", "settings", id],
  edit: (id) => ["spot", "edit", id],
  share: (id) => ["spot", "share", id],
  delete: (id) => ["spot", "delete", id],
  off: (id) => ["setting", "set", "--spot", id, "enabled", "false"],
  "icon.draw": (id) => ["spot", "run", "openspot/icon", "draw", id],
  "icon.file": (id) => ["spot", "run", "openspot/icon", "file", id],
  "icon.reset": (id) => ["spot", "run", "openspot/icon", "reset", id],
};

function main(args) {
  const [act, id] = args;
  if (!calls[act]) return "";
  const call = calls[act](id);
  if (openspot.call(call).code !== 0) throw new Error(`openspot ${call.join(" ")} failed.`);
  return "";
}

function hasIcon(id) {
  return openspot.call(["setting", "get", "--spot", id, "icon"]).stdout.trim() !== "";
}
