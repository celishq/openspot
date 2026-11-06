.PHONY: verify test plugins dev-state release release-build

verify:
	sh scripts/check-core.sh
	cd app && xcodegen generate >/dev/null
	cd app && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Openspot.xcodeproj -scheme Openspot -destination 'platform=macOS' test

test:
	cd app && xcodegen generate >/dev/null
	cd app && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Openspot.xcodeproj -scheme Openspot -destination 'platform=macOS' -only-testing:OpenspotTests/$(T) test

plugins:
	mkdir -p $(HOME)/.config/openspot
	ln -sfn $(CURDIR)/plugins $(HOME)/.config/openspot/plugins

dev-state:
	rm -rf .temp/openspot
	mkdir -p .temp/openspot
	cp -R plugins .temp/openspot/plugins

release:
	sh scripts/release.sh publish "$(V)"

release-build:
	sh scripts/release.sh build "$(V)"
