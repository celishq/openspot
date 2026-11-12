.PHONY: verify test perf eval-agent docs-images plugins dev-state examples release release-build

verify:
	sh scripts/check-core.sh
	sh scripts/check-tests.sh
	cd app && xcodegen generate >/dev/null
	cd app && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Openspot.xcodeproj -scheme Openspot -destination 'platform=macOS' test

test:
	cd app && xcodegen generate >/dev/null
	cd app && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Openspot.xcodeproj -scheme Openspot -destination 'platform=macOS' -only-testing:OpenspotTests/$(T) test

perf:
	sh scripts/motion-perf.sh $(N)

eval-agent:
	sh scripts/agent-eval.sh $(N)

docs-images:
	cd app && xcodegen generate >/dev/null
	cd app && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Openspot.xcodeproj -scheme Openspot -destination 'platform=macOS' -derivedDataPath ../.temp/dd build >/dev/null
	sh scripts/docs-images.sh

plugins:
	mkdir -p $(HOME)/.config/openspot
	ln -sfn $(CURDIR)/plugins $(HOME)/.config/openspot/plugins

dev-state:
	rm -rf .temp/openspot
	mkdir -p .temp/openspot/plugins
	[ -n "$(EMPTY)" ] || cp -R plugins/. .temp/openspot/plugins/

examples:
	mkdir -p .temp/openspot/plugins
	cp -R examples/. .temp/openspot/plugins/

release:
	sh scripts/release.sh publish "$(V)"

release-build:
	sh scripts/release.sh build "$(V)"
