cmake_minimum_required(VERSION 3.16)

# KiriKiri（krkrsdl3）OHOS 目标：libkrkrsdl3.so
# 源列表来自 krkrsdl3_build/cmake/*.txt，已参数化到 ${KRKR_SOURCE_DIR}

if(NOT DEFINED KRKR_SOURCE_DIR OR KRKR_SOURCE_DIR STREQUAL "")
  set(KRKR_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../third_party/krkrsdl3")
endif()
if(NOT EXISTS "${KRKR_SOURCE_DIR}/core/main/TVPApplication.cpp")
  message(FATAL_ERROR "krkrsdl3 源码缺失: ${KRKR_SOURCE_DIR}")
endif()

if(NOT DEFINED OHOS_ARCH OR OHOS_ARCH STREQUAL "")
  set(OHOS_ARCH arm64-v8a)
endif()
if(NOT DEFINED KRKR_DEPS_DIR OR KRKR_DEPS_DIR STREQUAL "")
  set(KRKR_DEPS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../third_party/krkrsdl3-deps/install/${OHOS_ARCH}")
endif()
if(NOT EXISTS "${KRKR_DEPS_DIR}/lib/libavcodec.a")
  message(FATAL_ERROR "KiriKiri 依赖缺失: ${KRKR_DEPS_DIR}；请先运行 tools/build-krkr-deps-ohos.sh")
endif()

set(OHOS TRUE)
set(USE_SDL3 OFF)
set(USE_FFMPEG ON)
set(USE_RENDER_GL ON)
set(USE_RENDER_VK OFF)

include(${CMAKE_CURRENT_SOURCE_DIR}/krkr_core.cmake)
include(${CMAKE_CURRENT_SOURCE_DIR}/krkr_environ.cmake)
include(${CMAKE_CURRENT_SOURCE_DIR}/krkr_plugins.cmake)
include(${CMAKE_CURRENT_SOURCE_DIR}/krkr_tjs2.cmake)

set(KRKRSDL_SRC
  ${KRKRSDL_CORE_SRC}
  ${KRKRSDL_ENVIRON_SRC}
  ${KRKRSDL_PLUGINS_SRC}
  ${KRKRSDL_TJS2_SRC}
  ${KRKRSDL_CORE_FFMPEG_SRC}
  ${KRKRSDL_CORE_OPENGL_SRC}
)

add_library(krkrsdl3 SHARED ${KRKRSDL_SRC})
target_compile_features(krkrsdl3 PRIVATE cxx_std_17)
target_compile_definitions(krkrsdl3 PRIVATE
  _KRKRSDL3_OHOS=1
  _KRKRSDL3_GLES=1
  _KRKRSDL3_USE_OPENGL=1
  _KRKRSDL3_USE_FFMPEG=1
)
# 软件渲染为标量 C（tvpgl），Debug 默认 -O0 会慢 5~10 倍；
# Debug 下强制 -O2（保留 -g），Release 走默认优化
target_compile_options(krkrsdl3 PRIVATE
  -fPIC
  -Wno-deprecated-declarations
  $<$<CONFIG:Debug>:-O2>
)
set_target_properties(krkrsdl3 PROPERTIES POSITION_INDEPENDENT_CODE ON)

target_include_directories(krkrsdl3 PRIVATE
  ${KRKR_SOURCE_DIR}/core/archive
  ${KRKR_SOURCE_DIR}/core/main
  ${KRKR_SOURCE_DIR}/core/media/font
  ${KRKR_SOURCE_DIR}/core/media/image
  ${KRKR_SOURCE_DIR}/core/media/movie
  ${KRKR_SOURCE_DIR}/core/media/sound
  ${KRKR_SOURCE_DIR}/core/msg
  ${KRKR_SOURCE_DIR}/core/render
  ${KRKR_SOURCE_DIR}/core/script
  ${KRKR_SOURCE_DIR}/core/utils
  ${KRKR_SOURCE_DIR}/core/utils/math
  ${KRKR_SOURCE_DIR}/environ
  ${KRKR_SOURCE_DIR}/plugins
  ${KRKR_SOURCE_DIR}/tjs2
  ${KRKR_DEPS_DIR}/include
  ${KRKR_DEPS_DIR}/include/freetype2
  ${KRKR_DEPS_DIR}/include/opus
)

target_link_libraries(krkrsdl3 PRIVATE
  EGL GLESv3 native_window
  hilog_ndk.z ace_napi.z ace_ndk.z ohaudio rawfile.z
  ${KRKR_DEPS_DIR}/lib/libavcodec.a
  ${KRKR_DEPS_DIR}/lib/libavformat.a
  ${KRKR_DEPS_DIR}/lib/libavutil.a
  ${KRKR_DEPS_DIR}/lib/libswresample.a
  ${KRKR_DEPS_DIR}/lib/libswscale.a
  ${KRKR_DEPS_DIR}/lib/libfreetype.a
  ${KRKR_DEPS_DIR}/lib/libpng16.a
  ${KRKR_DEPS_DIR}/lib/libz.a
  ${KRKR_DEPS_DIR}/lib/libjpeg.a
  ${KRKR_DEPS_DIR}/lib/libturbojpeg.a
  ${KRKR_DEPS_DIR}/lib/libwebp.a
  ${KRKR_DEPS_DIR}/lib/libwebpdemux.a
  ${KRKR_DEPS_DIR}/lib/libwebpdecoder.a
  ${KRKR_DEPS_DIR}/lib/libwebpmux.a
  ${KRKR_DEPS_DIR}/lib/libsharpyuv.a
  ${KRKR_DEPS_DIR}/lib/libonig.a
  ${KRKR_DEPS_DIR}/lib/libvorbis.a
  ${KRKR_DEPS_DIR}/lib/libvorbisfile.a
  ${KRKR_DEPS_DIR}/lib/libvorbisenc.a
  ${KRKR_DEPS_DIR}/lib/libogg.a
  ${KRKR_DEPS_DIR}/lib/libopus.a
  ${KRKR_DEPS_DIR}/lib/libopusfile.a
  ${KRKR_DEPS_DIR}/lib/libplutovg.a
)
