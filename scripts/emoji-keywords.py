import io
import json
import lzma
import shutil
import tarfile
import urllib.request
from pathlib import Path

VERSION = "49.0.0"
PACKAGES = {"annotations": "cldr-annotations-full", "annotationsDerived": "cldr-annotations-derived-full"}
LANGUAGES = [
    "ar", "az", "bn", "ca", "cs", "da", "de", "el", "en", "es", "et", "fi", "fil", "fr", "gu", "he", "hi", "hr", "hu",
    "hy", "id", "is", "it", "ja", "ka", "km", "kn", "ko", "lo", "lv", "ml", "mn", "mr", "ms", "my", "nl", "no", "pa",
    "pl", "pt", "ro", "ru", "sk", "sl", "sq", "sv", "ta", "te", "th", "tr", "uk", "ur", "uz", "vi", "yue", "zh",
    "zh-Hant",
]
DROPPED = {0xFE0E, 0xFE0F}
TONES = range(0x1F3FB, 0x1F400)
ROOT = Path(__file__).resolve().parent.parent
TEMP = ROOT / ".temp" / "cldr"
OUT = ROOT / "app" / "Keywords"


def download():
    shutil.rmtree(TEMP, ignore_errors=True)
    TEMP.mkdir(parents=True)
    for package in PACKAGES.values():
        url = f"https://registry.npmjs.org/{package}/-/{package}-{VERSION}.tgz"
        with urllib.request.urlopen(url) as answer:
            tarfile.open(fileobj=io.BytesIO(answer.read())).extractall(TEMP / package, filter="data")


def plain(glyph):
    return "".join(c for c in glyph if ord(c) not in DROPPED)


def keywords(language):
    found = {}
    for folder, package in PACKAGES.items():
        path = TEMP / package / "package" / folder / language / f"{folder}.json"
        if not path.exists():
            continue
        entries = json.loads(path.read_text())[folder]["annotations"]
        for glyph, entry in entries.items():
            if any(ord(c) in TONES for c in glyph) or "default" not in entry:
                continue
            found.setdefault(plain(glyph), entry["default"])
    return found


def main():
    download()
    shutil.rmtree(OUT, ignore_errors=True)
    OUT.mkdir(parents=True)
    for language in LANGUAGES:
        lines = [glyph + "\t" + "\t".join(words) for glyph, words in sorted(keywords(language).items())]
        text = ("\n".join(lines) + "\n").encode()
        (OUT / (language.replace("-", "_") + ".tsv.xz")).write_bytes(lzma.compress(text, preset=9 | lzma.PRESET_EXTREME))
    shutil.copy(TEMP / PACKAGES["annotations"] / "package" / "LICENSE", OUT / "LICENSE")


if __name__ == "__main__":
    main()
