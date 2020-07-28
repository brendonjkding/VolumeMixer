ifdef SIMULATOR
TARGET = simulator:clang:11.2:9.0
ARCHS = x86_64
else
TARGET = iphone:clang:11.2:9.0
	ifeq ($(debug),0)
		ARCHS= arm64 arm64e
	else
		ARCHS= arm64 
	endif
endif
include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = volumemixer

volumemixer_FILES = VMPrefRootListController.m BDInfoListController.m VMAPPListController.m
volumemixer_INSTALL_PATH = /Library/PreferenceBundles
volumemixer_FRAMEWORKS = UIKit
volumemixer_PRIVATE_FRAMEWORKS = Preferences
volumemixer_CFLAGS = -fobjc-arc -Wno-error=unused-variable -Wno-error=unused-function
ifdef SIMULATOR
volumemixer_LIBRARIES = applist-sim
else
volumemixer_LIBRARIES = applist
endif

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/volumemixer.plist$(ECHO_END)
