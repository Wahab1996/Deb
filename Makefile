ARCHS = arm64
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = PurchaseStateInspector

PurchaseStateInspector_FILES = $(wildcard Sources/*.m)
PurchaseStateInspector_FRAMEWORKS = UIKit Foundation
PurchaseStateInspector_LIBRARIES = sqlite3
PurchaseStateInspector_CFLAGS = -fobjc-arc
PurchaseStateInspector_CODESIGN_FLAGS = -SPurchaseStateInspector.entitlements

include $(THEOS_MAKE_PATH)/application.mk
