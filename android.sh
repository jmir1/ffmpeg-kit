#!/bin/bash

# LOAD INITIAL SETTINGS
export BASEDIR="$(pwd)"
export FFMPEG_KIT_BUILD_TYPE="android"
source "${BASEDIR}"/scripts/variable.sh
source "${BASEDIR}"/scripts/function-${FFMPEG_KIT_BUILD_TYPE}.sh

# SET DEFAULTS SETTINGS
enable_default_android_architectures
enable_main_build

# DOWNLOAD SDK & NDK FROM ANIYOMI-MPV-LIB
echo -n -e "\nDownloading aniyomi-mpv-lib dependencies"
git clone https://github.com/aniyomiorg/aniyomi-mpv-lib 1>>/dev/null 2>&1
cd aniyomi-mpv-lib/buildscripts || return 1
./download.sh 1>>/dev/null 2>&1

# ENABLE FFMPEG-KIT PROTOCOLS
cat ../../tools/protocols/libavformat_file.c >> deps/ffmpeg/libavformat/file.c
cat ../../tools/protocols/libavutil_file.h >> deps/ffmpeg/libavutil/file.h
cat ../../tools/protocols/libavutil_file.c >> deps/ffmpeg/libavutil/file.c
awk '{gsub(/ff_file_protocol;/,"ff_file_protocol;\nextern const URLProtocol ff_saf_protocol;")}1' deps/ffmpeg/libavformat/protocols.c > deps/ffmpeg/libavformat/protocols.c.tmp
cat deps/ffmpeg/libavformat/protocols.c.tmp > deps/ffmpeg/libavformat/protocols.c
echo -e "\nINFO: Enabled custom ffmpeg-kit protocols\n" 1>>"${BASEDIR}"/build.log 2>&1

# EXPORT BUILD TOOL LOCATIONS
export ANDROID_SDK_ROOT="$PWD/sdk/android-sdk-linux"
export ANDROID_NDK_ROOT="$PWD/sdk/android-ndk-r25c"

cd "$BASEDIR" || return 1

# DETECT ANDROID NDK VERSION
if [[ -z ${ANDROID_SDK_ROOT} ]]; then
  echo -e "\n(*) ANDROID_SDK_ROOT not defined\n"
  exit 1
fi

if [[ -z ${ANDROID_NDK_ROOT} ]]; then
  echo -e "\n(*) ANDROID_NDK_ROOT not defined\n"
  exit 1
fi

export DETECTED_NDK_VERSION=$(grep -Eo "Revision.*" "${ANDROID_NDK_ROOT}"/source.properties | sed 's/Revision//g;s/=//g;s/ //g')
echo -e "\nINFO: Using Android NDK v${DETECTED_NDK_VERSION} provided at ${ANDROID_NDK_ROOT}\n" 1>>"${BASEDIR}"/build.log 2>&1
echo -e "INFO: Build options: $*\n" 1>>"${BASEDIR}"/build.log 2>&1

# SET DEFAULT BUILD OPTIONS
export GPL_ENABLED="no"
DISPLAY_HELP=""
BUILD_FULL=""
BUILD_TYPE_ID=""
BUILD_VERSION=$(git describe --tags --always 2>>"${BASEDIR}"/build.log)

# PROCESS LTS BUILD OPTION FIRST AND SET BUILD TYPE: MAIN OR LTS
rm -f "${BASEDIR}"/android/ffmpeg-kit-android-lib/build.gradle 1>>"${BASEDIR}"/build.log 2>&1
cp "${BASEDIR}"/tools/android/build.gradle "${BASEDIR}"/android/ffmpeg-kit-android-lib/build.gradle 1>>"${BASEDIR}"/build.log 2>&1
for argument in "$@"; do
  if [[ "$argument" == "-l" ]] || [[ "$argument" == "--lts" ]]; then
    enable_lts_build
    BUILD_TYPE_ID+="LTS "
    rm -f "${BASEDIR}"/android/ffmpeg-kit-android-lib/build.gradle 1>>"${BASEDIR}"/build.log 2>&1
    cp "${BASEDIR}"/tools/android/build.lts.gradle "${BASEDIR}"/android/ffmpeg-kit-android-lib/build.gradle 1>>"${BASEDIR}"/build.log 2>&1
  fi
done

# PROCESS BUILD OPTIONS
while [ ! $# -eq 0 ]; do
  case $1 in
  -h | --help)
    DISPLAY_HELP="1"
    ;;
  -v | --version)
    display_version
    exit 0
    ;;
  --skip-*)
    SKIP_LIBRARY=$(echo $1 | sed -e 's/^--[A-Za-z]*-//g')

    skip_library "${SKIP_LIBRARY}"
    ;;
  --no-archive)
    NO_ARCHIVE="1"
    ;;
  --no-output-redirection)
    no_output_redirection
    ;;
  --no-workspace-cleanup-*)
    NO_WORKSPACE_CLEANUP_LIBRARY=$(echo $1 | sed -e 's/^--[A-Za-z]*-[A-Za-z]*-[A-Za-z]*-//g')

    no_workspace_cleanup_library "${NO_WORKSPACE_CLEANUP_LIBRARY}"
    ;;
  --no-link-time-optimization)
    no_link_time_optimization
    ;;
  -d | --debug)
    enable_debug
    ;;
  -s | --speed)
    optimize_for_speed
    ;;
  -l | --lts) ;;
  -f | --force)
    export BUILD_FORCE="1"
    ;;
  --reconf-*)
    CONF_LIBRARY=$(echo $1 | sed -e 's/^--[A-Za-z]*-//g')

    reconf_library "${CONF_LIBRARY}"
    ;;
  --rebuild-*)
    BUILD_LIBRARY=$(echo $1 | sed -e 's/^--[A-Za-z]*-//g')

    rebuild_library "${BUILD_LIBRARY}"
    ;;
  --redownload-*)
    DOWNLOAD_LIBRARY=$(echo $1 | sed -e 's/^--[A-Za-z]*-//g')

    redownload_library "${DOWNLOAD_LIBRARY}"
    ;;
  --full)
    BUILD_FULL="1"
    ;;
  --enable-gpl)
    export GPL_ENABLED="yes"
    ;;
  --enable-custom-library-*)
    CUSTOM_LIBRARY_OPTION_KEY=$(echo $1 | sed -e 's/^--enable-custom-//g;s/=.*$//g')
    CUSTOM_LIBRARY_OPTION_VALUE=$(echo $1 | sed -e 's/^--enable-custom-.*=//g')

    echo -e "INFO: Custom library options detected: ${CUSTOM_LIBRARY_OPTION_KEY} ${CUSTOM_LIBRARY_OPTION_VALUE}\n" 1>>"${BASEDIR}"/build.log 2>&1

    generate_custom_library_environment_variables "${CUSTOM_LIBRARY_OPTION_KEY}" "${CUSTOM_LIBRARY_OPTION_VALUE}"
    ;;
  --enable-*)
    ENABLED_LIBRARY=$(echo $1 | sed -e 's/^--[A-Za-z]*-//g')

    enable_library "${ENABLED_LIBRARY}"
    ;;
  --disable-lib-*)
    DISABLED_LIB=$(echo $1 | sed -e 's/^--[A-Za-z]*-[A-Za-z]*-//g')

    disabled_libraries+=("${DISABLED_LIB}")
    ;;
  --disable-*)
    DISABLED_ARCH=$(echo $1 | sed -e 's/^--[A-Za-z]*-//g')

    disable_arch "${DISABLED_ARCH}"
    ;;
  --api-level=*)
    API_LEVEL=$(echo $1 | sed -e 's/^--[A-Za-z]*-[A-Za-z]*=//g')

    export API=${API_LEVEL}
    ;;
  --no-ffmpeg-kit-protocols)
    export NO_FFMPEG_KIT_PROTOCOLS="1"
    ;;
  *)
    print_unknown_option "$1"
    ;;
  esac
  shift
done

# SET API LEVEL IN build.gradle
${SED_INLINE} "s/minSdkVersion .*/minSdkVersion ${API}/g" "${BASEDIR}"/android/ffmpeg-kit-android-lib/build.gradle 1>>"${BASEDIR}"/build.log 2>&1
${SED_INLINE} "s/versionCode ..0/versionCode ${API}0/g" "${BASEDIR}"/android/ffmpeg-kit-android-lib/build.gradle 1>>"${BASEDIR}"/build.log 2>&1

echo -e "\nBuilding ffmpeg-kit ${BUILD_TYPE_ID}library for Android\n"
echo -e -n "INFO: Building ffmpeg-kit ${BUILD_VERSION} ${BUILD_TYPE_ID}library for Android: " 1>>"${BASEDIR}"/build.log 2>&1
echo -e "$(date)\n" 1>>"${BASEDIR}"/build.log 2>&1

# DOWNLOAD LIBRARY SOURCES
downloaded_library_sources "${ENABLED_LIBRARIES[@]}"

# SAVE ORIGINAL API LEVEL = NECESSARY TO BUILD 64bit ARCHITECTURES
export ORIGINAL_API=${API}
export SKIP_ffmpeg=1

# BUILD ENABLED LIBRARIES ON ENABLED ARCHITECTURES
for run_arch in {0..12}; do
  if [[ ${ENABLED_ARCHITECTURES[$run_arch]} -eq 1 ]]; then
    if [[ (${run_arch} -eq ${ARCH_ARM64_V8A} || ${run_arch} -eq ${ARCH_X86_64}) && ${ORIGINAL_API} -lt 21 ]]; then

      # 64 bit ABIs supported after API 21
      export API=21
    else
      export API=${ORIGINAL_API}
    fi

    export ARCH=$(get_arch_name $run_arch)
    export TOOLCHAIN=$(get_toolchain)
    export TOOLCHAIN_ARCH=$(get_toolchain_arch)

    # EXECUTE MAIN BUILD SCRIPT
    . "${BASEDIR}"/scripts/main-android.sh "${ENABLED_LIBRARIES[@]}" || exit 1

    # CLEAR FLAGS
    for library in {0..61}; do
      library_name=$(get_library_name ${library})
      unset "$(echo "OK_${library_name}" | sed "s/\-/\_/g")"
      unset "$(echo "DEPENDENCY_REBUILT_${library_name}" | sed "s/\-/\_/g")"
    done
  fi
done

# GET BACK THE ORIGINAL API LEVEL
export API=${ORIGINAL_API}

# SET ARCHITECTURES TO BUILD
rm -f "${BASEDIR}"/android/build/.armv7 1>>"${BASEDIR}"/build.log 2>&1
rm -f "${BASEDIR}"/android/build/.armv7neon 1>>"${BASEDIR}"/build.log 2>&1
rm -f "${BASEDIR}"/android/build/.lts 1>>"${BASEDIR}"/build.log 2>&1
ANDROID_ARCHITECTURES=""
ANIYOMI_ARCHITECTURES=""
if [[ ${ENABLED_ARCHITECTURES[ARCH_ARM_V7A]} -eq 1 ]] || [[ ${ENABLED_ARCHITECTURES[ARCH_ARM_V7A_NEON]} -eq 1 ]]; then
  ANDROID_ARCHITECTURES+="$(get_android_arch 0) "
  ANIYOMI_ARCHITECTURES+="1 "
fi
if [[ ${ENABLED_ARCHITECTURES[ARCH_ARM_V7A]} -eq 1 ]]; then
  mkdir -p "${BASEDIR}"/android/build 1>>"${BASEDIR}"/build.log 2>&1
  create_file "${BASEDIR}"/android/build/.armv7
fi
if [[ ${ENABLED_ARCHITECTURES[ARCH_ARM_V7A_NEON]} -eq 1 ]]; then
  mkdir -p "${BASEDIR}"/android/build 1>>"${BASEDIR}"/build.log 2>&1
  create_file "${BASEDIR}"/android/build/.armv7neon
fi
if [[ ${ENABLED_ARCHITECTURES[ARCH_ARM64_V8A]} -eq 1 ]]; then
  ANDROID_ARCHITECTURES+="$(get_android_arch 2) "
  ANIYOMI_ARCHITECTURES+="2 "
fi
if [[ ${ENABLED_ARCHITECTURES[ARCH_X86]} -eq 1 ]]; then
  ANDROID_ARCHITECTURES+="$(get_android_arch 3) "
  ANIYOMI_ARCHITECTURES+="3 "
fi
if [[ ${ENABLED_ARCHITECTURES[ARCH_X86_64]} -eq 1 ]]; then
  ANDROID_ARCHITECTURES+="$(get_android_arch 4) "
  ANIYOMI_ARCHITECTURES+="4 "
fi
if [[ ! -z ${FFMPEG_KIT_LTS_BUILD} ]]; then
  mkdir -p "${BASEDIR}"/android/build 1>>"${BASEDIR}"/build.log 2>&1
  create_file "${BASEDIR}"/android/build/.lts
  LTSPOSTFIX="-lts"
fi

# BUILD FFMPEG-KIT
if [[ -n ${ANDROID_ARCHITECTURES} ]]; then

  echo -n -e "\naniyomi-mpv-lib: "

  # BUILD FFMPEG FROM ANIYOMI-MPV-LIB
  cd aniyomi-mpv-lib/buildscripts || return 1
  for i in $ANIYOMI_ARCHITECTURES; do
    aniyomiarch=$(get_aniyomi_arch "$i")
    androidarch=$(get_android_arch "$i")
    prebuiltarch=$(get_prebuilt_arch "$i")
    includearch=$(get_include_arch "$i")
    archsuffix=$(get_arch_suffix "$i")
    prebuilt_dir="$BASEDIR/prebuilt/android-$prebuiltarch$LTSPOSTFIX/ffmpeg"

    echo -n -e "\nBuilding ffmpeg for $androidarch"

    ./buildall.sh --arch "$aniyomiarch" ffmpeg 1>>"${BASEDIR}"/build.log 2>&1

    echo -n -e "\nCopying generated files to $prebuilt_dir"
    mkdir -p "$prebuilt_dir"
    cp -r "prefix/$aniyomiarch/lib" "$prebuilt_dir/"
    cp -r "prefix/$aniyomiarch/include" "$prebuilt_dir/"
    mkdir -p "$prebuilt_dir/include/libavutil/x86"
    mkdir -p "$prebuilt_dir/include/libavutil/arm"
    mkdir -p "$prebuilt_dir/include/libavutil/aarch64"
    mkdir -p "$prebuilt_dir/include/libavcodec/x86"
    mkdir -p "$prebuilt_dir/include/libavcodec/arm"
    cp deps/ffmpeg/_build$archsuffix/config.h "$prebuilt_dir/include/"
    cp deps/ffmpeg/libavcodec/mathops.h "$prebuilt_dir/include/libavcodec/"
    cp deps/ffmpeg/libavcodec/x86/mathops.h "$prebuilt_dir/include/libavcodec/x86/"
    cp deps/ffmpeg/libavcodec/arm/mathops.h "$prebuilt_dir/include/libavcodec/arm/"
    cp deps/ffmpeg/libavformat/avio.h "$prebuilt_dir/include/libavformat/"
    cp deps/ffmpeg/libavformat/network.h "$prebuilt_dir/include/libavformat/"
    cp deps/ffmpeg/libavformat/os_support.h "$prebuilt_dir/include/libavformat/"
    cp deps/ffmpeg/libavformat/url.h "$prebuilt_dir/include/libavformat/"
    cp deps/ffmpeg/libavutil/bprint.h "$prebuilt_dir/include/libavutil/"
    cp deps/ffmpeg/libavutil/getenv_utf8.h "$prebuilt_dir/include/libavutil/"
    cp deps/ffmpeg/libavutil/attributes_internal.h "$prebuilt_dir/include/libavutil/"
    cp deps/ffmpeg/libavutil/internal.h "$prebuilt_dir/include/libavutil/"
    cp deps/ffmpeg/libavutil/libm.h "$prebuilt_dir/include/libavutil/"
    cp deps/ffmpeg/libavutil/reverse.h "$prebuilt_dir/include/libavutil/"
    cp deps/ffmpeg/libavutil/thread.h "$prebuilt_dir/include/libavutil/"
    cp deps/ffmpeg/libavutil/timer.h "$prebuilt_dir/include/libavutil/"
    cp deps/ffmpeg/libavutil/x86/asm.h "$prebuilt_dir/include/libavutil/x86/"
    cp deps/ffmpeg/libavutil/x86/timer.h "$prebuilt_dir/include/libavutil/x86/"
    cp deps/ffmpeg/libavutil/arm/timer.h "$prebuilt_dir/include/libavutil/arm/"
    cp deps/ffmpeg/libavutil/aarch64/timer.h "$prebuilt_dir/include/libavutil/aarch64/"
    cp deps/ffmpeg/libavutil/x86/emms.h "$prebuilt_dir/include/libavutil/x86/"
    cp deps/ffmpeg/libavcodec/mathops.h "$prebuilt_dir/include/libavcodec/"
    mkdir -p "$prebuilt_dir/cpu-features"
  done
  cd ../..

  echo -n -e "\nffmpeg-kit: "

  # CREATE Application.mk FILE BEFORE STARTING THE NATIVE BUILD
  build_application_mk

  # CLEAR OLD NATIVE LIBRARIES
  rm -rf "${BASEDIR}"/android/libs 1>>"${BASEDIR}"/build.log 2>&1
  rm -rf "${BASEDIR}"/android/obj 1>>"${BASEDIR}"/build.log 2>&1

  cd "${BASEDIR}"/android 1>>"${BASEDIR}"/build.log 2>&1 || exit 1

  # BUILD NATIVE LIBRARY
  if [[ ${SKIP_ffmpeg_kit} -ne 1 ]]; then
    if [ "$(is_darwin_arm64)" == "1" ]; then
       arch -x86_64 "${ANDROID_NDK_ROOT}"/ndk-build -B 1>>"${BASEDIR}"/build.log 2>&1
    else
      "${ANDROID_NDK_ROOT}"/ndk-build -B 1>>"${BASEDIR}"/build.log 2>&1
    fi

    if [ $? -eq 0 ]; then
      echo "ok"
    else
      echo "failed"
      exit 1
    fi
  else
    echo "skipped"
  fi

  echo -e -n "\n"

  # DO NOT BUILD ANDROID ARCHIVE
  if [[ ${NO_ARCHIVE} -ne 1 ]]; then

    echo -e -n "\nCreating Android archive under prebuilt: "

    unset ANDROID_SDK_ROOT 
    # BUILD ANDROID ARCHIVE
    rm -f "${BASEDIR}"/android/ffmpeg-kit-android-lib/build/outputs/aar/ffmpeg-kit-release.aar 1>>"${BASEDIR}"/build.log 2>&1
    ./gradlew ffmpeg-kit-android-lib:clean ffmpeg-kit-android-lib:assembleRelease ffmpeg-kit-android-lib:testReleaseUnitTest 1>>"${BASEDIR}"/build.log 2>&1
    if [ $? -ne 0 ]; then
      echo -e "failed\n"
      exit 1
    fi

    # COPY ANDROID ARCHIVE TO PREBUILT DIRECTORY
    FFMPEG_KIT_AAR="${BASEDIR}/prebuilt/$(get_aar_directory)/ffmpeg-kit"
    rm -rf "${FFMPEG_KIT_AAR}" 1>>"${BASEDIR}"/build.log 2>&1
    mkdir -p "${FFMPEG_KIT_AAR}" 1>>"${BASEDIR}"/build.log 2>&1
    cp "${BASEDIR}"/android/ffmpeg-kit-android-lib/build/outputs/aar/ffmpeg-kit-release.aar "${FFMPEG_KIT_AAR}"/ffmpeg-kit.aar 1>>"${BASEDIR}"/build.log 2>&1
    if [ $? -ne 0 ]; then
      echo -e "failed\n"
      exit 1
    fi

    echo -e "INFO: Created ffmpeg-kit Android archive successfully.\n" 1>>"${BASEDIR}"/build.log 2>&1
    echo -e "ok\n"
  else
    echo -e "INFO: Skipped creating Android archive.\n" 1>>"${BASEDIR}"/build.log 2>&1
  fi
fi
