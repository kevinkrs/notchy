.DEFAULT_GOAL := build
.PHONY: build test app install run clean

APP := build/Notchy.app
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

build:
	swift build

# Command Line Tools do not auto-discover the Swift Testing macro plugin.
# CLT layout first, Xcode.app layout second.
TESTING_PLUGIN := $(firstword $(wildcard $(shell xcode-select -p)/usr/lib/swift/host/plugins/testing $(shell xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins/testing))

test:
	swift test -Xswiftc -plugin-path -Xswiftc $(TESTING_PLUGIN)

app:
	scripts/build-app.sh

INSTALL_DIR ?= $(HOME)/Applications

install: app
	mkdir -p $(INSTALL_DIR)
	-$(LSREGISTER) -u $(APP)
	rm -rf $(INSTALL_DIR)/Notchy.app && cp -R $(APP) $(INSTALL_DIR)/
	$(LSREGISTER) -f $(INSTALL_DIR)/Notchy.app

run: app
	open $(APP)

clean:
	rm -rf .build build
