function hasIcon(id) {
  return openspot.call(["setting", "get", "--spot", id, "icon"]).stdout.trim() !== "";
}

export default {
  async share({ item }, env) {
    await env.spot.share(item);
  },
  async settings({ item }, env) {
    await env.spot.settings(item);
  },
  async edit({ item }, env) {
    await env.spot.edit(item);
  },
  async delete({ item }, env) {
    await env.spot.delete(item);
  },
  async off({ item }) {
    const call = ["setting", "set", "--spot", item, "enabled", "false"];
    if (openspot.call(call).code !== 0) throw new Error(`openspot ${call.join(" ")} failed.`);
  },
  async "icon.draw"({ item }, env) {
    await env.spot.run("openspot/icon", "draw", [`spot=${item}`]);
  },
  async "icon.file"({ item }, env) {
    await env.spot.run("openspot/icon", "file", [`spot=${item}`]);
  },
  async "icon.reset"({ item }, env) {
    await env.spot.run("openspot/icon", "reset", [`spot=${item}`]);
  },
};
