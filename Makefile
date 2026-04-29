PROJECT_DIR := src
PROJECT := $(PROJECT_DIR)/SkimDown.xcodeproj
SCHEME := SkimDown
DERIVED_DATA := build/DerivedData
DEBUG_APP := $(DERIVED_DATA)/Build/Products/Debug/SkimDown.app
RELEASE_APP := $(DERIVED_DATA)/Build/Products/Release/SkimDown.app
VERSION ?= 0.1.0
DMG_PATH := build/SkimDown-$(VERSION).dmg
NOTARY_ZIP := build/SkimDown-$(VERSION).zip
DESTINATION := platform=macOS

.PHONY: generate build test run launch-check release notarize dmg clean docs docs-build

generate:
	cd $(PROJECT_DIR) && xcodegen generate

build: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) build

test: generate
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA)

run: build
	open $(DEBUG_APP)
	osascript -e 'tell application id "dev.jp27.SkimDown" to activate'

launch-check: build
	sh scripts/launch-smoke-test.sh "$(DEBUG_APP)"

release: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) build

notarize: release
	@test -n "$(APPLE_ID)" || (echo "APPLE_ID is required" && exit 1)
	@test -n "$(APPLE_TEAM_ID)" || (echo "APPLE_TEAM_ID is required" && exit 1)
	@test -n "$(APPLE_APP_PASSWORD)" || (echo "APPLE_APP_PASSWORD is required" && exit 1)
	mkdir -p build
	ditto -c -k --keepParent "$(RELEASE_APP)" "$(NOTARY_ZIP)"
	xcrun notarytool submit "$(NOTARY_ZIP)" --apple-id "$(APPLE_ID)" --team-id "$(APPLE_TEAM_ID)" --password "$(APPLE_APP_PASSWORD)" --wait
	xcrun stapler staple "$(RELEASE_APP)"

dmg: release
	mkdir -p build
	rm -f "$(DMG_PATH)"
	hdiutil create -volname "SkimDown" -srcfolder "$(RELEASE_APP)" -ov -format UDZO "$(DMG_PATH)"

clean:
	rm -rf build "$(PROJECT)"

docs:
	npm --prefix docs install
	npm --prefix docs run docs:dev

docs-build:
	npm --prefix docs install
	npm --prefix docs run docs:build
