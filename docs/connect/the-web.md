# Fetch from the web

You'll build Joke, which answers `joke` in the panel's search with a joke from the web.

## Make the spot

`joke.spot/spot.toml`:

```toml
title = "Joke"
icon = "face.smiling"
uses = ["network"]

[on]
search = "^joke$"
```

`joke.spot/joke.js`:

```text
export default {
  async search(_, env) {
    const answer = await env.fetch("https://official-joke-api.appspot.com/random_joke")
    if (!answer.ok) return { item: "joke", title: "No joke today" }
    const joke = await answer.json()
    return { item: "joke", title: joke.setup, detail: joke.punchline }
  },
}
```

Type `joke`. The row shows a joke once the web answers.

## How it works

`env.fetch(url, { method, headers, body })` takes the address and the options of the `fetch` of a browser, and gives
`ok`, `status`, `url`, `headers.get(name)`, `text()` and `json()`. It takes `http` and `https` addresses.

An answer holds 2 MB at most and comes within 30 seconds. Else the promise rejects with an error whose `cause` says
why: `offline`, `timeout`, `limit`, `refused` or `unavailable`. Show each as your own row, such as No exchange rates
when the Mac is offline.

A fetch that waits on the web lands after the key, so a search that needs the web on each key feels slow. Keep what
you fetch in [a cache](../remember/cache.md), and fetch it in the cache's filler.

A shell spot uses `curl`, and a Swift spot `URLSession`.

## Careful mode

`network` in `uses` tells people that your spot reaches the web. In Careful mode, a fetch of a spot without it fails
with `refused`.

## Next

- [Keep a copy that goes old](../remember/cache.md)
- [Use the Mac](the-mac.md)
