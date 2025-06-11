DART_SOURCES := $(shell find lib -name '*.dart')
PUBSPEC_FILES := pubspec.yaml pubspec.lock
.PHONY: build

MAC_APP_DIR := build/macos/Build/Products/Release/bespoke.app
MAC_APP_BINARY := build/macos/Build/Products/Release/bespoke.app/Contents/MacOS/bespoke

build: $(MAC_APP_BINARY)

$(MAC_APP_DIR) $(MAC_APP_BINARY) &: $(DART_SOURCES) $(PUBSPEC_FILES)
	fvm flutter build macos
