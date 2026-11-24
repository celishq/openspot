.PHONY: verify test perf film shots eval-agent eval-compare docs-images spots attachment-demo dev-state first-launch examples release release-build

TEST_LIMITS := -test-timeouts-enabled YES -default-test-execution-time-allowance 120 -maximum-test-execution-time-allowance 300

verify:
	sh scripts/check-core.sh
	sh scripts/check-tests.sh
	sh scripts/check-comments.sh
	sh scripts/check-motion.sh
	sh scripts/check-names.sh
	sh scripts/check-files.sh
	sh scripts/check-getters.sh
	sh scripts/check-spots.sh
	sh scripts/check-processes.sh
	sh scripts/check-glass.sh
	sh scripts/check-shapes.sh
	sh scripts/check-windows.sh
	sh scripts/check-tokens.sh
	sh scripts/check-tools.sh
	sh scripts/spot-tests.sh
	cd app && xcodegen generate >/dev/null
	cd app && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Openspot.xcodeproj -scheme Openspot -destination 'platform=macOS' $(TEST_LIMITS) test

test:
	cd app && xcodegen generate >/dev/null
	cd app && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Openspot.xcodeproj -scheme Openspot -destination 'platform=macOS' $(TEST_LIMITS) -only-testing:OpenspotTests/$(T) test

perf:
	sh scripts/motion-perf.sh $(N)

film:
	sh scripts/motion-film.sh

shots:
	sh scripts/menu-shots.sh

eval-agent:
	sh scripts/agent-eval.sh $(or $(LABEL),base) $(or $(N),3) $(TASKS)

eval-compare:
	python3 -I scripts/agent-eval/summary.py $(foreach l,$(LABELS),.temp/agent-eval/$(l)/runs.tsv)

docs-images:
	cd app && xcodegen generate >/dev/null
	cd app && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Openspot.xcodeproj -scheme Openspot -destination 'platform=macOS' -derivedDataPath ../.temp/dd build >/dev/null
	sh scripts/docs-images.sh

spots:
	[ ! -L $(HOME)/.config/openspot/spots ] || rm $(HOME)/.config/openspot/spots
	mkdir -p $(HOME)/.config/openspot/spots
	for spot in spots/*.spot; do [ "$$spot" = spots/openspot.spot ] || ln -sfn "$(CURDIR)/$$spot" $(HOME)/.config/openspot/spots/; done

attachment-demo:
	sh scripts/attachment-demo.sh

dev-state:
	rm -rf .temp/openspot
	mkdir -p .temp/openspot/spots
	[ -n "$(EMPTY)" ] || cp -R spots/. .temp/openspot/spots/
	rm -rf .temp/openspot/spots/openspot.spot

first-launch:
	pkill -f '/Debug/Openspot Nightly.app/Contents/MacOS/OpenspotNightly' || true
	$(MAKE) dev-state EMPTY=1

examples:
	mkdir -p .temp/openspot/spots
	cp -R examples/. .temp/openspot/spots/

release:
	sh scripts/release.sh publish "$(V)"

release-build:
	sh scripts/release.sh build "$(V)"
