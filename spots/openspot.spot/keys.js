// title=Keys
// icon=keyboard
// detail=Give a spot and its commands their keys
// on=sheet.open
// uses=app,spots
// offers=none
// pages=spot:*
// edits=keys
const none = { text: "none", title: "No spot", detail: "Choose Keys… in the menu of a card" };

// The spot whose keys the sheet shows, from the page that Keys… pushed.
function target(env) {
  const page = env.OPENSPOT_PAGE || "";
  return page.startsWith("spot:") ? page.slice(5) : "";
}

// The blocks of `openspot spot list --frame` that describe one spot: its own, then each of its buttons.
function blocks(id) {
  const list = openspot.call(["spot", "list", "--frame"]);
  if (list.code !== 0) throw new Error("openspot spot list failed.");
  const all = list.stdout.split(/\n\s*\n/).map((text) => {
    const block = {};
    for (const line of text.split("\n")) {
      const at = line.indexOf("=");
      if (at > 0 && !(line.slice(0, at) in block)) block[line.slice(0, at)] = line.slice(at + 1);
    }
    return block;
  });
  const start = all.findIndex((block) => block.spot === id);
  if (start < 0) return null;
  const end = all.findIndex((block, index) => index > start && block.spot !== undefined);
  return all.slice(start, end < 0 ? all.length : end);
}

function row(id, title, icon, key) {
  return {
    row: id, title, detail: key ? undefined : "Press ⏎ to set", icon, type: "hotkey", shake: "true", close: "false",
    hides: key ? undefined : "clear", shortcut: key || "Record",
  };
}

function sheet(id) {
  const found = id && blocks(id);
  if (!found) return openspot.frame(none);
  const [spot, ...rest] = found;
  const buttons = rest.filter((block) => block.button !== undefined);
  const rows = [row("spot", "Open", spot.icon, spot.openKey)]
    .concat(buttons.map((button) => row(`key.${button.button}`, button.title || button.button, button.icon || spot.icon, button.key)))
    .concat(spot.float === "true" ? [row("float", "Float", spot.icon, spot.floatKey)] : []);
  return openspot.frame([
    { title: spot.name, detail: "Keys", recents: "false" },
    { button: "open", title: "Change", close: "false" },
    { button: "clear", title: "Remove", shortcut: "cmd+backspace" },
    ...rows,
  ]);
}

// The setting of the target that holds the key of a row, which is the row's id but for Open, since `open` is a call.
function setting(row) {
  if (row === "spot") return "open";
  if (row === "float" || (row && row.startsWith("key."))) return row;
  return null;
}

function main(args, env) {
  const [act, value] = args;
  const id = target(env);
  if (act === "read") return sheet(id);
  if (!id) return "";
  const key = act === "clear" ? setting(value) : setting(act);
  if (!key) throw new Error("Keys cannot do that.");
  const call = ["setting", "set", "--spot", id, key].concat(act === "clear" || !value ? [] : [value]);
  if (openspot.call(call).code !== 0) throw new Error(`openspot ${call.join(" ")} failed.`);
  return "";
}
