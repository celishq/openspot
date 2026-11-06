.PHONY: verify test plugins

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
