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

TWEAK_NAME = VolumeMixer

VolumeMixer_FILES = Tweak.xm
VolumeMixer_CFLAGS = -fobjc-arc -Wno-error=unused-variable -Wno-error=unused-function -std=c++11

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 priconne" ||true
	install.exec "killall -9 GBA4iOS" ||true
	install.exec "killall -9 Sample" ||true
	install.exec "killall -9 ProductName" ||true
	install.exec "killall -9 NewHLDDZ" ||true
	install.exec "killall -9 fatego" ||true

ifdef SIMULATOR
include $(THEOS)/makefiles/locatesim.mk
BUNDLE_NAME = $(TWEAK_NAME)
PREF_FOLDER_NAME = $(shell echo $(BUNDLE_NAME) | tr A-Z a-z)
endif

ifneq (,$(filter x86_64 i386,$(ARCHS)))
setup:: clean all
	@rm -f /opt/simject/$(TWEAK_NAME).dylib
	@cp -v $(THEOS_OBJ_DIR)/$(TWEAK_NAME).dylib /opt/simject/$(TWEAK_NAME).dylib
	@codesign -f -s - /opt/simject/$(TWEAK_NAME).dylib
	@cp -v $(PWD)/$(TWEAK_NAME).plist /opt/simject
# 	sudo cp -v $(PWD)/$(PREF_FOLDER_NAME)/entry.plist $(PL_SIMULATOR_PLISTS_PATH)/$(BUNDLE_NAME).plist
# 	sudo cp -vR $(THEOS_OBJ_DIR)/$(BUNDLE_NAME).bundle $(PL_SIMULATOR_BUNDLES_PATH)/
# 	@sudo codesign -f -s - $(PL_SIMULATOR_BUNDLES_PATH)/$(BUNDLE_NAME).bundle/$(BUNDLE_NAME)
	@resim
endif
remove::
	@rm -f /opt/simject/$(TWEAK_NAME).dylib /opt/simject/$(TWEAK_NAME).plist
	sudo rm -r $(PL_SIMULATOR_BUNDLES_PATH)/$(BUNDLE_NAME).bundle
	sudo rm $(PL_SIMULATOR_PLISTS_PATH)/$(BUNDLE_NAME).plist
	@resim