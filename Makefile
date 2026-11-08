.PHONY: verify test perf guide plugins dev-state release release-build

verify:
	sh scripts/check-core.sh
	sh scripts/check-tests.sh
	cd app && xcodegen generate >/dev/null
	cd app && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Openspot.xcodeproj -scheme Openspot -destination 'platform=macOS' test

test:
	cd app && xcodegen generate >/dev/null
	cd app && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Openspot.xcodeproj -scheme Openspot -destination 'platform=macOS' -only-testing:OpenspotTests/$(T) test

guide:
	sh scripts/guide.sh

perf:
	sh scripts/motion-perf.sh $(N)

plugins:
	mkdir -p $(HOME)/.config/openspot
	ln -sfn $(CURDIR)/plugins $(HOME)/.config/openspot/plugins

dev-state:
	rm -rf .temp/openspot
	mkdir -p .temp/openspot/plugins
	[ -n "$(EMPTY)" ] || cp -R plugins/. .temp/openspot/plugins/

release:
	sh scripts/release.sh publish "$(V)"

release-build:
	sh scripts/release.sh build "$(V)"
