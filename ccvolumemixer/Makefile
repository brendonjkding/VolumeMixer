BUNDLE_NAME = CCVolumeMixer
CCVolumeMixer_BUNDLE_EXTENSION = bundle
CCVolumeMixer_FILES = CCVolumeMixer.m
CCVolumeMixer_CFLAGS = -fobjc-arc
CCVolumeMixer_PRIVATE_FRAMEWORKS = ControlCenterUIKit
CCVolumeMixer_INSTALL_PATH = /Library/ControlCenter/Bundles/

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)$(THEOS_PACKAGE_INSTALL_PREFIX)/Library/ControlCenter/Bundles/CCVolumeMixer.bundle/$(ECHO_END)
	$(ECHO_NOTHING)ln -s $(THEOS_PACKAGE_INSTALL_PREFIX)/Library/PreferenceBundles/volumemixer.bundle/icon@2x.png $(THEOS_STAGING_DIR)$(THEOS_PACKAGE_INSTALL_PREFIX)/Library/ControlCenter/Bundles/CCVolumeMixer.bundle/SettingsIcon@2x.png$(ECHO_END)
	$(ECHO_NOTHING)ln -s $(THEOS_PACKAGE_INSTALL_PREFIX)/Library/PreferenceBundles/volumemixer.bundle/icon@3x.png $(THEOS_STAGING_DIR)$(THEOS_PACKAGE_INSTALL_PREFIX)/Library/ControlCenter/Bundles/CCVolumeMixer.bundle/SettingsIcon@3x.png$(ECHO_END)