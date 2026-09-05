ARCHS = arm64
TARGET = iphone:clang:15.6:15.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = JBToolbox

JBToolbox_FILES = \
	Sources/main.m \
	Sources/AppDelegate.m \
	Sources/RootTabBarController.m \
	Sources/OverviewViewController.m \
	Sources/ProcessesViewController.m \
	Sources/ActionsViewController.m \
	Sources/SystemInfo.m \
	Sources/CommandRunner.m

JBToolbox_FRAMEWORKS = UIKit Foundation
JBToolbox_CFLAGS = -fobjc-arc -Wall -Wextra
JBToolbox_CODESIGN_FLAGS = -SJBToolbox.entitlements
JBToolbox_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/application.mk

after-install::
	install.exec "uicache -p $(THEOS_PACKAGE_INSTALL_PREFIX)/Applications/JBToolbox.app || true"
