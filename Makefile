TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = SpringBoard

ARCHS = arm64
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TOOL_NAME = ExpenseTracker

ExpenseTracker_FILES = $(wildcard Source/*.m)
ExpenseTracker_CFLAGS = -fobjc-arc -Isource
ExpenseTracker_LDFLAGS = -lsqlite3
ExpenseTracker_CODESIGN_FLAGS = -Sentitlements/ExpenseTracker.entitlements

include $(THEOS)/makefiles/tool.mk

before-package::
	@echo "Packaging IPA..."
	@mkdir -p $(THEOS_STAGING_DIR)/Payload/ExpenseTracker.app
	@cp -r $(THEOS_STAGING_DIR)/usr/bin/ExpenseTracker $(THEOS_STAGING_DIR)/Payload/ExpenseTracker.app/ExpenseTracker
	@cp -r Resources/Info.plist $(THEOS_STAGING_DIR)/Payload/ExpenseTracker.app/
	@cp -r Resources/Assets.xcassets/AppIcon.appiconset $(THEOS_STAGING_DIR)/Payload/ExpenseTracker.app/
	@ldid -Sentitlements/ExpenseTracker.entitlements $(THEOS_STAGING_DIR)/Payload/ExpenseTracker.app/ExpenseTracker
	@echo "IPA ready at Payload/ExpenseTracker.app"