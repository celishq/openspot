// Reads a page that is already open in one of the person's browsers, for a shop that hides its pages from programs.
// Run: osascript -l JavaScript tab.js <link> <file> [whole]
// It looks only at browsers that already run, and only at a tab whose link is the same, with no query.
// It prints a first line, "html <browser>", then the HTML of the page. A Chromium browser that does not let Apple Events
// run JavaScript saves the page to the file instead, which it writes a moment later, and prints "file <browser>". It saves
// the HTML that the shop sent, or with "whole" the page as it shows, with a folder of its parts, which is slower. A
// browser that gives neither prints "title <browser>" and a <title> alone. It prints nothing when no open tab has the link.
const browsers = [
  ['com.google.Chrome', 'chrome'], ['company.thebrowser.Browser', 'chrome'], ['com.brave.Browser', 'chrome'],
  ['com.microsoft.edgemac', 'chrome'], ['com.vivaldi.Vivaldi', 'chrome'], ['com.operasoftware.Opera', 'chrome'],
  ['org.chromium.Chromium', 'chrome'], ['com.google.Chrome.canary', 'chrome'],
  ['com.apple.Safari', 'safari'], ['com.apple.SafariTechnologyPreview', 'safari'],
];
const page = 'document.documentElement.outerHTML';

function bare(link) {
  return String(link || '').replace(/^[a-z]+:\/\//i, '').replace(/^www\./i, '').replace(/[?#].*$/, '').replace(/\/+$/, '').toLowerCase();
}

function escaped(text) {
  return String(text || '').replace(/&/g, '&amp;').replace(/</g, '&lt;');
}

function run(args) {
  const want = bare(args[0]);
  const file = args[1];
  const whole = args[2] === 'whole';
  if (!want) return '';
  for (const [id, kind] of browsers) {
    let app;
    try {
      app = Application(id);
      if (!app.running()) continue;
    } catch (e) {
      continue;
    }
    let name = id;
    try { name = app.name(); } catch (e) {}
    let windows = [];
    try { windows = app.windows(); } catch (e) { continue; }
    for (const window of windows) {
      let tabs = [];
      try { tabs = window.tabs(); } catch (e) { continue; }
      for (const tab of tabs) {
        let link = '';
        try { link = tab.url(); } catch (e) { continue; }
        if (bare(link) !== want) continue;
        if (kind === 'safari') {
          try {
            const source = tab.source();
            if (source) return 'html ' + name + '\n' + source;
          } catch (e) {}
        }
        try {
          const html = kind === 'safari' ? app.doJavaScript(page, { in: tab }) : app.execute(tab, { javascript: page });
          if (html) return 'html ' + name + '\n' + html;
        } catch (e) {}
        if (kind === 'chrome' && file) {
          try {
            app.save(tab, { in: Path(file), as: whole ? 'complete html' : 'only html' });
            return 'file ' + name;
          } catch (e) {}
        }
        let title = '';
        try { title = kind === 'safari' ? tab.name() : tab.title(); } catch (e) {}
        return 'title ' + name + '\n<title>' + escaped(title) + '</title>';
      }
    }
  }
  return '';
}
