.PHONY: verify test perf film shots eval-agent docs-images spots dev-state examples release release-build

verify:
	sh scripts/check-core.sh
	sh scripts/check-tests.sh
	sh scripts/check-comments.sh
	sh scripts/check-motion.sh
	cd app && xcodegen generate >/dev/null
	cd app && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Openspot.xcodeproj -scheme Openspot -destination 'platform=macOS' test

test:
	cd app && xcodegen generate >/dev/null
	cd app && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Openspot.xcodeproj -scheme Openspot -destination 'platform=macOS' -only-testing:OpenspotTests/$(T) test

perf:
	sh scripts/motion-perf.sh $(N)

film:
	sh scripts/motion-film.sh

shots:
	sh scripts/menu-shots.sh

eval-agent:
	sh scripts/agent-eval.sh $(N)

docs-images:
	cd app && xcodegen generate >/dev/null
	cd app && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Openspot.xcodeproj -scheme Openspot -destination 'platform=macOS' -derivedDataPath ../.temp/dd build >/dev/null
	sh scripts/docs-images.sh

spots:
	mkdir -p $(HOME)/.config/openspot
	ln -sfn $(CURDIR)/spots $(HOME)/.config/openspot/spots

dev-state:
	rm -rf .temp/openspot
	mkdir -p .temp/openspot/spots
	[ -n "$(EMPTY)" ] || cp -R spots/. .temp/openspot/spots/
	rm -rf .temp/openspot/spots/openspot.spot

examples:
	mkdir -p .temp/openspot/spots
	cp -R examples/. .temp/openspot/spots/

release:
	sh scripts/release.sh publish "$(V)"

release-build:
	sh scripts/release.sh build "$(V)"
