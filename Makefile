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


TWEAK_NAME = VolumeMixer VolumeMixerSB

VolumeMixer_FILES = Tweak.xm VMHookInfo.mm VMHookAudioUnit.mm 
VolumeMixer_FILES += MRYIPC/MRYIPCCenter.m
VolumeMixer_CFLAGS = -fobjc-arc

ifdef SIMULATOR
VolumeMixer_LIBRARIES += substrate
endif

ifdef SIMULATOR
VolumeMixer_LOGOSFLAGS += -c generator=MobileSubstrate
endif

VolumeMixer_EXTRA_FRAMEWORKS += Cephei


VolumeMixerSB_FILES = TweakSB.xm VMHUDView.m VMHUDWindow.m VMHUDRootViewController.m VMLAListener.m
VolumeMixerSB_FILES += MRYIPC/MRYIPCCenter.m
ifneq ($(debug),0)
VolumeMixerSB_FILES += test.x
endif
ifdef SIMULATOR
VolumeMixerSB_FILES += sim.x
endif
VolumeMixerSB_CFLAGS = -fobjc-arc 
VolumeMixerSB_LIBRARIES = applist
ifdef SIMULATOR
VolumeMixerSB_LIBRARIES += substrate
endif
VolumeMixerSB_EXTRA_FRAMEWORKS += Cephei

ADDITIONAL_CFLAGS += -Wno-error=unused-variable -Wno-error=unused-function -Wno-error=unused-value -include Prefix.pch

SUBPROJECTS += volumemixerpref

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 SpringBoard" ||true


