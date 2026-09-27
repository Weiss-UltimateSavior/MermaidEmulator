cmake_minimum_required(VERSION 3.16)
project(mermaid_host CXX C)

if(NOT DEFINED ARTC_SOURCE_DIR OR ARTC_SOURCE_DIR STREQUAL "")
  set(ARTC_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../third_party/artemis-compat")
endif()
if(NOT EXISTS "${ARTC_SOURCE_DIR}/CMakeLists.txt")
  message(FATAL_ERROR "artemis-compat 源码缺失: ${ARTC_SOURCE_DIR}；请先执行 git submodule update --init --recursive，或用 -DARTC_SOURCE_DIR=<path> 指向本地副本")
endif()

set(ARTC_BUILD_CLI OFF CACHE BOOL "" FORCE)
set(ARTC_BUILD_JNI OFF CACHE BOOL "" FORCE)
set(ARTC_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(ARTC_BUILD_MAC_HOST OFF CACHE BOOL "" FORCE)
set(ARTC_GRAPHICS_BACKEND GLES CACHE STRING "" FORCE)
set(ARTC_AUDIO_BACKEND OHAUDIO CACHE STRING "" FORCE)
set(ARTC_ENABLE_FFMPEG OFF CACHE BOOL "" FORCE)

# OpenHarmony 设备的真实 GLES 实现在 libGLESv3.so（/system/lib64）；
# libGLESv2.so 仅存在于 /system/lib64/ndk 且为桩实现，直接调用是空操作。
add_library(mermaid_gles INTERFACE)
target_link_libraries(mermaid_gles INTERFACE EGL GLESv3)
set(ARTC_GLES_TARGET mermaid_gles CACHE STRING "" FORCE)

add_subdirectory("${ARTC_SOURCE_DIR}" "${CMAKE_CURRENT_BINARY_DIR}/artemis-compat")

add_library(artemishost SHARED
  napi_init.cpp
  host/engine_host.cpp
  host/ohos_renderer.cpp
)

target_compile_features(artemishost PRIVATE cxx_std_17)
target_include_directories(artemishost PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(artemishost PRIVATE
  artemis::core
  mermaid_gles
  libace_napi.z.so
  libace_ndk.z.so
  libnative_window.so
  libhilog_ndk.z.so
)

option(MERMAID_ENABLE_KRKR "Build KiriKiri (krkrsdl3) engine" ON)
if(MERMAID_ENABLE_KRKR)
  add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/krkr" "${CMAKE_CURRENT_BINARY_DIR}/krkr")
endif()
