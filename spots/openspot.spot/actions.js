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
  async off({ item }, env) {
    await env.setting.set("enabled", "false", { spot: item });
  },
  async "icon.draw"({ item }, env) {
    await env.icon.draw({ spot: item });
  },
  async "icon.file"({ item }, env) {
    await env.icon.file({ spot: item });
  },
  async "icon.reset"({ item }, env) {
    await env.icon.reset({ spot: item });
  },
};
