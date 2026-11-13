// title=Card actions
// icon=ellipsis.circle
// detail=Edit, share, delete or turn off a spot
// uses=spots
//
// button=edit
// title=Edit
// shortcut=cmd+e
// close=true
// offers=actions mine
//
// button=prompt
// title=Copy prompt for AI
// close=true
// offers=actions mine
//
// button=share
// title=Share
// shortcut=cmd+shift+c
// close=true
// offers=actions mine, core
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
function main(args) {
  const [act, id] = args;
  const call = act === "off" ? ["setting", "set", "--spot", id, "enabled", "false"] : ["spot", act, id];
  if (!["edit", "prompt", "share", "delete", "off"].includes(act)) return "";
  if (openspot.call(call).code !== 0) throw new Error(`openspot ${call.join(" ")} failed.`);
  return "";
}
