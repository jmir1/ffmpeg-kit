MY_LOCAL_PATH := $(call my-dir)
$(call import-add-path, $(MY_LOCAL_PATH))

ifeq ("$(shell test -e $(MY_LOCAL_PATH)/../build/.lts && echo lts)","lts")
    MY_LTS_POSTFIX := -lts
else
    MY_LTS_POSTFIX :=
endif

MY_BUILD_DIR := android-$(TARGET_ARCH)$(MY_LTS_POSTFIX)

FFMPEG_INCLUDES := $(MY_LOCAL_PATH)/../../prebuilt/$(MY_BUILD_DIR)/ffmpeg/include

MY_ARM_MODE := arm
MY_ARM_NEON := false
LOCAL_PATH := $(MY_LOCAL_PATH)/../ffmpeg-kit-android-lib/src/main/cpp

# DEFINE ARCH FLAGS
ifeq ($(TARGET_ARCH_ABI), armeabi-v7a)
    MY_ARCH_FLAGS := ARM_V7A
    MY_ARM_NEON := true
endif
ifeq ($(TARGET_ARCH_ABI), arm64-v8a)
    MY_ARCH_FLAGS := ARM64_V8A
    MY_ARM_NEON := true
endif
ifeq ($(TARGET_ARCH_ABI), x86)
    MY_ARCH_FLAGS := X86
    MY_ARM_NEON := true
endif
ifeq ($(TARGET_ARCH_ABI), x86_64)
    MY_ARCH_FLAGS := X86_64
    MY_ARM_NEON := true
endif

include $(CLEAR_VARS)
LOCAL_ARM_MODE := $(MY_ARM_MODE)
LOCAL_MODULE := ffmpegkit_abidetect
LOCAL_SRC_FILES := ffmpegkit_abidetect.c
LOCAL_CFLAGS := -Wall -Wextra -Werror -Wno-unused-parameter -DFFMPEG_KIT_${MY_ARCH_FLAGS}
LOCAL_C_INCLUDES := $(FFMPEG_INCLUDES)
LOCAL_LDLIBS := -llog -lz -landroid
LOCAL_STATIC_LIBRARIES := cpu-features
LOCAL_ARM_NEON := ${MY_ARM_NEON}
include $(BUILD_SHARED_LIBRARY)

$(call import-module, cpu-features)

MY_SRC_FILES := ffmpegkit.c ffprobekit.c ffmpegkit_exception.c fftools_cmdutils.c fftools_ffmpeg.c fftools_ffprobe.c fftools_ffmpeg_mux.c fftools_ffmpeg_mux_init.c fftools_ffmpeg_demux.c fftools_ffmpeg_opt.c fftools_opt_common.c fftools_ffmpeg_hw.c fftools_ffmpeg_filter.c fftools_objpool.c fftools_sync_queue.c fftools_thread_queue.c

MY_CFLAGS := -Wall -Werror -Wno-unused-parameter -Wno-switch -Wno-sign-compare
MY_LDLIBS := -llog -lz -landroid

include $(CLEAR_VARS)
LOCAL_PATH := $(MY_LOCAL_PATH)/../ffmpeg-kit-android-lib/src/main/cpp
LOCAL_ARM_MODE := $(MY_ARM_MODE)
LOCAL_MODULE := ffmpegkit
LOCAL_SRC_FILES := $(MY_SRC_FILES)
LOCAL_CFLAGS := $(MY_CFLAGS)
LOCAL_LDLIBS := $(MY_LDLIBS)
LOCAL_SHARED_LIBRARIES := libavfilter libavformat libavcodec libavutil libswresample libavdevice libswscale c++_shared
LOCAL_ARM_NEON := ${MY_ARM_NEON}
include $(BUILD_SHARED_LIBRARY)

$(call import-module, ffmpeg)
