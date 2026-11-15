#!/bin/sh
. "$(dirname "$0")/checks.sh"
need app scripts
found=$(mktemp)
trap 'rm -f "$found"' EXIT
grep -rnoE --include='*.swift' '^[[:space:]]*(@[[:alnum:]_]+(\([^)]*\))?[[:space:]]+)*((public|private|fileprivate|internal|open|final|nonisolated|indirect)[[:space:]]+)*(class|struct|enum|protocol|actor|typealias)[[:space:]]+[A-Z][A-Za-z0-9]*(Manager|Handler|Controller|Provider|Renderer|Reader|Writer|Builder|Loader|Parser|Formatter|Generator|Coordinator|Helper|Runner|Starter|Chooser|Watcher|Observer|Listener|Scanner|Processor|Validator|Converter|Resolver|Monitor|Recorder|Presenter|Creator|Fetcher|Checker|Tracker|Sender|Receiver|Launcher|Updater|Installer|Downloader|Uploader|Exporter|Importer|Selector|Iterator|Executor|Dispatcher|Scheduler|Mapper|Wrapper|Adapter|Encoder|Decoder|Compiler|Picker|Finder|Collector|Counter|Driver)([^A-Za-z0-9]|$)' app scripts \
  | grep -v '/Openspot.xcodeproj/' \
  | sed -E 's/^([^:]*):[0-9]+:.*[[:space:]]([A-Z][A-Za-z0-9]*)[^A-Za-z0-9]?$/\1	\2/' >"$found"
compare names "$found" "A type is named for an agent; name it for what it is (see Writing in AGENTS.md):" || exit 1
echo "Names check passed."
