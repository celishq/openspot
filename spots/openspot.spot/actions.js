// title=Card actions
// icon=ellipsis.circle
// detail=Share, set, edit, change the icon of, delete or turn off a spot
// uses=spots
//
// button=share
// title=Share
// shortcut=cmd+shift+c
// close=true
// offers=actions mine, core
//
// button=settings
// title=Settings
// shortcut=cmd+return
// offers=actions
//
// button=edit
// title=Edit
// shortcut=cmd+e
// offers=actions mine, core
//
// button=icon
// title=Change Icon
// offers=actions
//
// button=icon.draw
// title=Draw…
//
// button=icon.file
// title=Choose File…
//
// button=icon.reset
// title=Reset Icon
// when=hasIcon
//
// button=delete
// title=Delete
// shortcut=cmd+backspace
// offers=actions mine
//
// button=off
// title=Turn off
// shortcut=cmd+backspace
// close=true
// offers=actions core
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
