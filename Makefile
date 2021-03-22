ifdef SIMULATOR
TARGET = simulator:clang:11.2:8.0
ARCHS = x86_64
else
TARGET = iphone:clang:11.2:7.0
	ifeq ($(debug),0)
		ARCHS= armv7 arm64 arm64e
	else
		ARCHS= arm64 arm64e
	endif
endif


TWEAK_NAME = VolumeMixer

VolumeMixer_FILES = Tweak.xm VMHUDView.m VMHUDWindow.m VMHUDRootViewController.m VMLAListener.m VMHookInfo.mm VMHookAudioUnit.mm 
VolumeMixer_FILES += MRYIPC/MRYIPCCenter.m
ifneq ($(debug),0)
VolumeMixer_FILES += test.x
endif
ifdef SIMULATOR
VolumeMixer_FILES += sim.x
endif

VolumeMixer_CFLAGS = -fobjc-arc -Wno-error=unused-variable -Wno-error=unused-function -Wno-error=unused-value -include Prefix.pch

VolumeMixer_LIBRARIES = applist
ifdef SIMULATOR
VolumeMixer_LIBRARIES += substrate
endif

ifdef SIMULATOR
VolumeMixer_LOGOSFLAGS += -c generator=MobileSubstrate
endif

SUBPROJECTS += volumemixerpref

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 priconne" ||true
	install.exec "killall -9 GBA4iOS" ||true
# 	install.exec "killall -9 Sample" ||true
# 	install.exec "killall -9 NewHLDDZ" ||true
# 	install.exec "killall -9 fatego" ||true
	install.exec "killall -9 Preferences" ||true
	install.exec "killall -9 neteasemusic" ||true
# 	install.exec "killall -9 QQMusic" ||true
	install.exec "killall -9 MobileSafari" ||true
	install.exec "sbreload" ||true


