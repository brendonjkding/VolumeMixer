ifdef SIMULATOR
export TARGET = simulator:clang:latest:8.0
else
export TARGET = iphone:clang:latest:7.0
	ifeq ($(debug),0)
		export ARCHS = armv7 arm64 arm64e
	else
		export ARCHS = arm64 arm64e
	endif
endif

INSTALL_TARGET_PROCESSES = SpringBoard

TWEAK_NAME = VolumeMixer VolumeMixerSB

VolumeMixer_FILES = Tweak.xm VMHookInfo.mm VMHookAudioUnit.mm 
VolumeMixer_FILES += MRYIPC/MRYIPCCenter.m
VolumeMixer_CFLAGS = -fobjc-arc
VolumeMixer_LIBRARIES += dobby substrate
VolumeMixer_LOGOSFLAGS += -c generator=MobileSubstrate
VolumeMixer_EXTRA_FRAMEWORKS += Cephei

VolumeMixerSB_FILES = TweakSB.xm VMHUDView.m VMHUDWindow.m VMHUDRootViewController.m VMLAListener.m VMLAVolumeDownListener.m VMLAVolumeUpListener.m
VolumeMixerSB_FILES += MRYIPC/MRYIPCCenter.m
ifdef SIMULATOR
VolumeMixerSB_FILES += sim.x
endif
VolumeMixerSB_CFLAGS = -fobjc-arc 
VolumeMixerSB_LIBRARIES = substrate
VolumeMixerSB_EXTRA_FRAMEWORKS += Cephei

export ADDITIONAL_CFLAGS += -Wno-error=unused-variable -Wno-error=unused-function -Wno-error=unused-value -include Prefix.pch

SUBPROJECTS += volumemixerpref
SUBPROJECTS += ccvolumemixer

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
