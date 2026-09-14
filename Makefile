SHELL := /bin/zsh
CLANG := xcrun clang
BUILD_DIR := .build/local
APP_BUNDLE := dist/LinkRouter.app
ICON_GENERATOR := $(BUILD_DIR)/GenerateIconset
ICONSET_DIR := $(BUILD_DIR)/AppIcon.iconset
APP_ICON := $(BUILD_DIR)/AppIcon.icns
VERSION := $(shell plutil -extract CFBundleShortVersionString raw Packaging/Info.plist)
INSTALLER := dist/LinkRouter-$(VERSION).dmg
INSTALLER_STAGING := $(BUILD_DIR)/installer
COMMON_FLAGS := -fobjc-arc -fmodules -fmodules-cache-path=$(BUILD_DIR)/ModuleCache -fobjc-weak -mmacosx-version-min=13.0 -Wall -Wextra -Werror -I Sources/Core -I Sources/App
CORE_SOURCES := $(wildcard Sources/Core/*.m)
APP_SOURCES := $(wildcard Sources/App/*.m)
APP_LIBRARY_SOURCES := $(filter-out Sources/App/main.m,$(APP_SOURCES))
APP_FRAMEWORKS := -framework Cocoa -framework UniformTypeIdentifiers -framework ServiceManagement
TEST_BINARIES := $(BUILD_DIR)/LRConfigurationTests $(BUILD_DIR)/LRRouterTests $(BUILD_DIR)/LRLaunchPlanTests $(BUILD_DIR)/LRConfigStoreTests $(BUILD_DIR)/LRIntegrationTests $(BUILD_DIR)/LRLaunchLifecycleTests $(BUILD_DIR)/LRAppDelegateTests $(BUILD_DIR)/LRIconFactoryTests

.PHONY: all build test test-config test-router test-launch-plan test-store test-integration test-launch-lifecycle test-app-delegate test-icon icon app installer verify verify-bundle verify-installer run clean

all: test app

verify: test verify-bundle

build: $(BUILD_DIR)/LinkRouter

test: $(TEST_BINARIES)
	$(BUILD_DIR)/LRConfigurationTests
	$(BUILD_DIR)/LRRouterTests
	$(BUILD_DIR)/LRLaunchPlanTests
	$(BUILD_DIR)/LRConfigStoreTests
	$(BUILD_DIR)/LRIntegrationTests
	$(BUILD_DIR)/LRLaunchLifecycleTests
	$(BUILD_DIR)/LRAppDelegateTests
	$(BUILD_DIR)/LRIconFactoryTests

test-config: $(BUILD_DIR)/LRConfigurationTests
	$(BUILD_DIR)/LRConfigurationTests

test-router: $(BUILD_DIR)/LRRouterTests
	$(BUILD_DIR)/LRRouterTests

test-launch-plan: $(BUILD_DIR)/LRLaunchPlanTests
	$(BUILD_DIR)/LRLaunchPlanTests

test-store: $(BUILD_DIR)/LRConfigStoreTests
	$(BUILD_DIR)/LRConfigStoreTests

test-integration: $(BUILD_DIR)/LRIntegrationTests
	$(BUILD_DIR)/LRIntegrationTests

test-launch-lifecycle: $(BUILD_DIR)/LRLaunchLifecycleTests
	$(BUILD_DIR)/LRLaunchLifecycleTests

test-app-delegate: $(BUILD_DIR)/LRAppDelegateTests
	$(BUILD_DIR)/LRAppDelegateTests

test-icon: $(BUILD_DIR)/LRIconFactoryTests
	$(BUILD_DIR)/LRIconFactoryTests

icon: $(APP_ICON)

app: build Packaging/Info.plist $(APP_ICON)
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/LinkRouter $(APP_BUNDLE)/Contents/MacOS/LinkRouter
	cp $(APP_ICON) $(APP_BUNDLE)/Contents/Resources/AppIcon.icns
	cp Packaging/Info.plist $(APP_BUNDLE)/Contents/Info.plist
	plutil -lint $(APP_BUNDLE)/Contents/Info.plist
	codesign --force --sign - --timestamp=none $(APP_BUNDLE)

installer: app
	rm -rf $(INSTALLER_STAGING)
	mkdir -p $(INSTALLER_STAGING) dist
	ditto $(APP_BUNDLE) $(INSTALLER_STAGING)/LinkRouter.app
	ln -s /Applications $(INSTALLER_STAGING)/Applications
	hdiutil create -volname LinkRouter -srcfolder $(INSTALLER_STAGING) -ov -format UDZO $(INSTALLER)

verify-bundle: app
	test "$$(plutil -extract LSUIElement raw $(APP_BUNDLE)/Contents/Info.plist)" = "true"
	test "$$(plutil -extract CFBundleURLTypes.0.CFBundleURLSchemes.0 raw $(APP_BUNDLE)/Contents/Info.plist)" = "http"
	test "$$(plutil -extract CFBundleURLTypes.0.CFBundleURLSchemes.1 raw $(APP_BUNDLE)/Contents/Info.plist)" = "https"
	test "$$(plutil -extract CFBundleURLTypes.1.CFBundleURLSchemes.0 raw $(APP_BUNDLE)/Contents/Info.plist)" = "file"
	test "$$(plutil -extract CFBundleDocumentTypes.0.LSItemContentTypes.0 raw $(APP_BUNDLE)/Contents/Info.plist)" = "public.html"
	test "$$(plutil -extract CFBundleIconFile raw $(APP_BUNDLE)/Contents/Info.plist)" = "AppIcon.icns"
	test -f $(APP_BUNDLE)/Contents/Resources/AppIcon.icns
	test ! -e $(APP_BUNDLE)/Contents/Resources/Settings.html
	codesign --verify --deep --strict --verbose=2 $(APP_BUNDLE)

verify-installer: installer
	Scripts/verify-installer.sh $(INSTALLER)

run: app
	open $(APP_BUNDLE)

$(BUILD_DIR)/LRIntegrationTests: Examples/config.json

$(BUILD_DIR)/%Tests: Tests/%Tests.m Tests/LRTestSupport.h $(CORE_SOURCES)
	mkdir -p $(BUILD_DIR)
	$(CLANG) $(COMMON_FLAGS) $< $(CORE_SOURCES) -framework Foundation -o $@

$(BUILD_DIR)/LRAppDelegateTests: Tests/LRAppDelegateTests.m Tests/LRTestSupport.h $(APP_LIBRARY_SOURCES) $(CORE_SOURCES)
	mkdir -p $(BUILD_DIR)
	$(CLANG) $(COMMON_FLAGS) $< $(APP_LIBRARY_SOURCES) $(CORE_SOURCES) $(APP_FRAMEWORKS) -o $@

$(BUILD_DIR)/LRLaunchLifecycleTests: Tests/LRLaunchLifecycleTests.m Tests/LRTestSupport.h $(APP_LIBRARY_SOURCES) $(CORE_SOURCES)
	mkdir -p $(BUILD_DIR)
	$(CLANG) $(COMMON_FLAGS) $< $(APP_LIBRARY_SOURCES) $(CORE_SOURCES) $(APP_FRAMEWORKS) -o $@

$(BUILD_DIR)/LRIconFactoryTests: Tests/LRIconFactoryTests.m Tests/LRTestSupport.h Sources/App/LRIconFactory.m Sources/App/LRIconFactory.h
	mkdir -p $(BUILD_DIR)
	$(CLANG) $(COMMON_FLAGS) $< Sources/App/LRIconFactory.m -framework Cocoa -o $@

$(ICON_GENERATOR): Tools/GenerateIconset.m Sources/App/LRIconFactory.m Sources/App/LRIconFactory.h
	mkdir -p $(BUILD_DIR)
	$(CLANG) $(COMMON_FLAGS) Tools/GenerateIconset.m Sources/App/LRIconFactory.m -framework Cocoa -o $@

$(APP_ICON): $(ICON_GENERATOR)
	rm -rf $(ICONSET_DIR)
	mkdir -p $(ICONSET_DIR)
	$(ICON_GENERATOR) $(ICONSET_DIR)
	iconutil -c icns $(ICONSET_DIR) -o $(APP_ICON)

$(BUILD_DIR)/LinkRouter: $(APP_SOURCES) $(CORE_SOURCES)
	mkdir -p $(BUILD_DIR)
	$(CLANG) $(COMMON_FLAGS) $(APP_SOURCES) $(CORE_SOURCES) $(APP_FRAMEWORKS) -o $@

clean:
	rm -rf $(BUILD_DIR) $(APP_BUNDLE)
	rm -f $(INSTALLER)
