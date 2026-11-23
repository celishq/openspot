openspot.value = function value(key, text) {
  const read = (one) => one.replace(/\\(n|\\)/g, (_, kind) => kind === "n" ? "\n" : "\\")
  return String(text || "").split("\n").filter((line) => line.startsWith(key + "=")).map((line) => read(line.slice(key.length + 1))).join("\n")
}
openspot.handle = function handle(handlers, name, input, env, done) {
  const fail = (error) => done(false, error && error.message !== undefined ? String(error.message) : String(error))
  let result
  try { result = handlers[name](input, env) } catch (error) { return fail(error) }
  Promise.resolve(result).then((value) => done(true, openspot.answer(value)), fail)
}
openspot.answer = function answer(value) {
  const frame = (value) => {
    if (Array.isArray(value)) return value.map(frame).join("\n")
    const write = (one) => String(one).replace(/\\/g, "\\\\").replace(/\n/g, "\\n")
    let text = ""
    for (const [key, each] of Object.entries(value || {})) {
      if (each === undefined || each === null) continue
      for (const one of Array.isArray(each) ? each : [each]) text += `${key}=${write(one)}\n`
    }
    return text
  }
  if (value === undefined || value === null) return ""
  if (typeof value === "string") return value
  if (typeof value === "boolean") return value ? "true" : ""
  if (Array.isArray(value)) return frame(value)
  const out = {}
  for (const [key, each] of Object.entries(value)) out["out." + key] = each
  return frame(out)
}
openspot.env = function env(call, spec, bindings, settings) {
  const failure = (argv, answer) => new Error(answer.errors || `openspot ${argv.join(" ")} exited ${answer.code}.`)
  const run = async (argv) => {
    const answer = await openspot.ask(call, argv)
    if (answer.code !== 0) throw failure(argv, answer)
    return answer
  }
  const listed = (value) => (Array.isArray(value) ? value : [value]).filter((one) => one !== undefined && one !== null)
  const pairs = (values) => Object.entries(values || {}).flatMap(([key, each]) => listed(each).map((one) => `${key}=${one}`))
  const words = (slots, args) => {
    const argv = []
    const options = args[slots.filter((slot) => !slot.option).length] || {}
    let index = 0
    for (const slot of slots) {
      const value = slot.option ? options[slot.key] : args[index++]
      if (value === undefined || value === null || (slot.option && value === false)) continue
      if (slot.kind === "flag") argv.push(slot.option)
      else if (slot.option) for (const one of listed(value)) argv.push(slot.option, String(one))
      else if (slot.kind === "pairs") argv.push(...pairs(value))
      else argv.push(...listed(value).map(String))
    }
    return argv
  }
  const env = { settings }
  for (const [noun, verbs] of Object.entries(spec)) {
    const command = (verb) => async (...args) => (await run([...verb.words, ...words(verb.slots, args)])).output.replace(/\n$/, "")
    env[noun] = verbs[""] ? command(verbs[""]) : {}
    for (const [method, verb] of Object.entries(verbs)) {
      if (method !== "") env[noun][method] = command(verb)
    }
  }
  const now = (argv, input) => {
    const answer = openspot.call(argv, input)
    if (answer.code !== 0) throw new Error(`openspot ${argv.join(" ")} exited ${answer.code}.`)
    return answer.stdout
  }
  env.cache = {
    get: (name) => {
      const value = now(["cache", "get", name])
      const age = now(["cache", "age", name])
      return age === "" ? null : { value, age: Number(age) }
    },
    set: (name, value) => { now(["cache", "set", name], String(value)) },
  }
  env.emit = async (event, values) => { await run(["emit", event, ...pairs(values)]) }
  env.open = async (spot) => { await run(["spot", "open", spot]) }
  for (const name of bindings) {
    env[name] = new Proxy({}, {
      get: (_, action) => typeof action !== "string" || action === "then" ? undefined : async (inputs) => {
        const argv = ["run", `${name}.${action}`, ...pairs(inputs)]
        const answer = await openspot.ask(call, argv)
        if (answer.code === 4) return null
        if (answer.code !== 0) throw failure(argv, answer)
        return answer.values
      },
    })
  }
  return env
}
