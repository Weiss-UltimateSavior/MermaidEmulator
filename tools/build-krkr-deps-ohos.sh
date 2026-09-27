#!/usr/bin/env bash
# KiriKiri（krkrsdl3）OHOS 交叉编译依赖构建脚本
# 由 krkrsdl3_build/ohos/build-ohos.ps1 的 deps 段移植，macOS/Linux 可用。
# 产物：third_party/krkrsdl3-deps/install/<arch>/{lib,include}
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCH="${1:-arm64-v8a}"
BUILD_TYPE="${BUILD_TYPE:-Release}"

SDK_ROOT="${DEVECO_SDK_HOME:-/Applications/DevEco-Studio.app/Contents/sdk}"
NATIVE="$SDK_ROOT/default/openharmony/native"
CC="$NATIVE/llvm/bin/clang"
CXX="$NATIVE/llvm/bin/clang++"
AR="$NATIVE/llvm/bin/llvm-ar"
SYSROOT="$NATIVE/sysroot"
TOOLCHAIN="$NATIVE/build/cmake/ohos.toolchain.cmake"

DEPS_ROOT="$ROOT/third_party/krkrsdl3-deps"
SRC="$DEPS_ROOT/src"
INSTALL="$DEPS_ROOT/install/$ARCH"
JOBS="$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)"

case "$ARCH" in
  arm64-v8a) TRIPLE="aarch64-linux-ohos"; CLANG_PREFIX="aarch64-unknown-linux-ohos" ;;
  armeabi-v7a) TRIPLE="arm-linux-ohos"; CLANG_PREFIX="armv7-unknown-linux-ohos" ;;
  x86_64) TRIPLE="x86_64-linux-ohos"; CLANG_PREFIX="x86_64-unknown-linux-ohos" ;;
  *) echo "unsupported arch: $ARCH"; exit 1 ;;
esac

mkdir -p "$SRC" "$INSTALL/lib" "$INSTALL/include"

log() { echo "[krkr-deps] $*"; }

stamp() { echo "$INSTALL/.stamp_$1"; }
has_stamp() { [ -f "$(stamp "$1")" ]; }
mark() { date > "$(stamp "$1")"; }

clone() {
  local name="$1" url="$2" ref="$3"
  if [ ! -d "$SRC/$name" ]; then
    log "clone $name ($ref)"
    git clone -q --depth 1 --branch "$ref" "$url" "$SRC/$name" || {
      log "clone $name failed"; return 1;
    }
  fi
}

build_cmake() {
  local name="$1"; shift
  if has_stamp "$name"; then log "$name (cached)"; return 0; fi
  log "build $name"
  rm -rf "$SRC/$name/build"
  cmake -G Ninja \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DOHOS_ARCH="$ARCH" \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_INSTALL_PREFIX="$INSTALL" \
    -B "$SRC/$name/build" -S "$SRC/$name" "$@" > "$SRC/$name.cmake.log" 2>&1 || {
      log "$name cmake failed (see $SRC/$name.cmake.log)"; return 1;
    }
  cmake --build "$SRC/$name/build" --config "$BUILD_TYPE" --parallel "$JOBS" >> "$SRC/$name.cmake.log" 2>&1 || {
    log "$name build failed (see $SRC/$name.cmake.log)"; return 1;
  }
  cmake --install "$SRC/$name/build" --prefix "$INSTALL" >> "$SRC/$name.cmake.log" 2>&1 || {
    log "$name install failed"; return 1;
  }
  mark "$name"
}

# ---------------- zlib ----------------
clone zlib https://github.com/madler/zlib.git v1.3.1
build_cmake zlib || exit 1

# ---------------- libpng（OHOS ARM 关闭 NEON：调色板展开缺陷）----------------
clone libpng https://github.com/pnggroup/libpng.git v1.6.43
# genout 预处理钩子直接调用 CMAKE_C_COMPILER，需显式带 target/sysroot（否则用宿主头文件）
build_cmake libpng -DPNG_TESTS=OFF -DPNG_TOOLS=OFF -DPNG_SHARED=OFF -DPNG_STATIC=ON -DPNG_ARM_NEON=off \
  -DZLIB_INCLUDE_DIR="$INSTALL/include" -DZLIB_LIBRARY="$INSTALL/lib/libz.a" \
  -DCMAKE_C_FLAGS="--target=$TRIPLE --sysroot=$SYSROOT" || exit 1

# ---------------- libjpeg-turbo ----------------
clone libjpeg-turbo https://github.com/libjpeg-turbo/libjpeg-turbo.git 3.0.4
build_cmake libjpeg-turbo -DENABLE_SHARED=OFF -DENABLE_STATIC=ON -DWITH_TURBOJPEG=ON || exit 1

# ---------------- ogg / opus / vorbis ----------------
clone ogg https://github.com/xiph/ogg.git v1.3.5
build_cmake ogg || exit 1

clone opus https://github.com/xiph/opus.git v1.5.2
build_cmake opus || exit 1

clone vorbis https://github.com/xiph/vorbis.git v1.3.7
build_cmake vorbis -DOGG_INCLUDE_DIR="$INSTALL/include" -DOGG_LIBRARY="$INSTALL/lib/libogg.a" || exit 1

# ---------------- opusfile（无 CMake，手工编译）----------------
if has_stamp opusfile; then
  log "opusfile (cached)"
else
  clone opusfile https://github.com/xiph/opusfile.git v0.12
  log "build opusfile"
  ( cd "$SRC/opusfile" && \
    "$CC" --target="$TRIPLE" --sysroot="$SYSROOT" -fPIC -D__MUSL__ -O2 \
      -Iinclude -I"$INSTALL/include" -I"$INSTALL/include/opus" \
      -c src/opusfile.c src/stream.c src/http.c src/internal.c src/info.c src/wincerts.c > ../opusfile.log 2>&1 && \
    "$AR" rcs "$INSTALL/lib/libopusfile.a" ./*.o >> ../opusfile.log 2>&1 && \
    rm -f ./*.o && \
    cp include/opusfile.h "$INSTALL/include/" && \
    mkdir -p "$INSTALL/include/opus" && cp include/opusfile.h "$INSTALL/include/opus/" ) || {
      log "opusfile failed (see $SRC/opusfile.log)"; exit 1;
    }
  mark opusfile
fi

# ---------------- freetype ----------------
clone freetype https://github.com/freetype/freetype.git VER-2-13-2
build_cmake freetype -DFT_DISABLE_BZIP2=ON -DFT_DISABLE_HARFBUZZ=ON -DFT_DISABLE_BROTLI=ON \
  -DPNG_ROOT="$INSTALL" -DZLIB_ROOT="$INSTALL" || exit 1

# ---------------- libwebp ----------------
clone libwebp https://github.com/webmproject/libwebp.git v1.4.0
build_cmake libwebp || exit 1

# ---------------- oniguruma ----------------
clone oniguruma https://github.com/kkos/oniguruma.git v6.9.9
build_cmake oniguruma || exit 1

# ---------------- glm（header-only）----------------
if has_stamp glm; then
  log "glm (cached)"
else
  clone glm https://github.com/g-truc/glm.git 1.0.1
  mkdir -p "$INSTALL/include"
  cp -R "$SRC/glm/glm" "$INSTALL/include/glm"
  mark glm
fi

# ---------------- plutovg ----------------
clone plutovg https://github.com/sammycage/plutovg.git v0.0.6
build_cmake plutovg || exit 1

# ---------------- ffmpeg（n7.1，白名单解码器，禁用 asm）----------------
if has_stamp ffmpeg; then
  log "ffmpeg (cached)"
else
  clone ffmpeg https://github.com/FFmpeg/FFmpeg.git n7.1
  log "build ffmpeg (5-15 min)"
  FF_BUILD="$SRC/ffmpeg"
  FF_OUT="$DEPS_ROOT/build/$ARCH/ffmpeg_install"
  mkdir -p "$FF_OUT"
  TARGET_CC="$NATIVE/llvm/bin/${CLANG_PREFIX}-clang"
  TARGET_CXX="$NATIVE/llvm/bin/${CLANG_PREFIX}-clang++"
  HOST_CC="$(command -v cc || echo /usr/bin/clang)"
  (
    cd "$FF_BUILD" && \
    CFLAGS="-DOHOS_NDK -fPIC -D__MUSL__=1 -O3" \
    CXXFLAGS="-DOHOS_NDK -fPIC -D__MUSL__=1 -O3" \
    ./configure \
      --disable-neon --disable-asm --disable-x86asm \
      --enable-cross-compile --target-os=linux --arch=aarch64 \
      --cc="$TARGET_CC" --cxx="$TARGET_CXX" --ld="$TARGET_CC" \
      --host-cc="$HOST_CC" --host-ld="$HOST_CC" \
      --ar="$AR" --ranlib="$NATIVE/llvm/bin/llvm-ranlib" --strip="$NATIVE/llvm/bin/llvm-strip" \
      --nm="$NATIVE/llvm/bin/llvm-nm" \
      --sysroot="$SYSROOT" \
      --prefix="$FF_OUT" \
      --enable-static --disable-shared \
      --enable-pic --disable-doc --disable-htmlpages \
      --disable-autodetect \
      --disable-encoders --disable-muxers --disable-indevs --disable-outdevs \
      --disable-programs \
      --enable-protocols \
      --enable-avcodec --enable-avformat --enable-avutil \
      --enable-swresample --enable-swscale \
      --enable-decoder=h264,hevc,mpeg4,mpeg2video,mpeg1video,flv,vp8,vp9,mjpeg \
      --enable-decoder=aac,mp3,flac,vorbis,opus \
      --enable-decoder=pcm_s16le,pcm_f32le,pcm_s16be,pcm_u8 \
      --enable-demuxer=matroska,avi,mp4,mov,flv,mpegts,mpegps,ogg,wav,aac,mp3 \
      --enable-parser=h264,hevc,mpeg4video,mpegvideo,aac,mp3,flac,vorbis,opus \
      > "$DEPS_ROOT/ffmpeg.configure.log" 2>&1 && \
    make -j"$JOBS" > "$DEPS_ROOT/ffmpeg.make.log" 2>&1 && \
    make install > "$DEPS_ROOT/ffmpeg.install.log" 2>&1
  ) || {
    log "ffmpeg failed (see $DEPS_ROOT/ffmpeg.*.log)"; exit 1;
  }
  cp -f "$FF_OUT"/lib/*.a "$INSTALL/lib/" 2>/dev/null || true
  cp -Rf "$FF_OUT"/include/* "$INSTALL/include/" 2>/dev/null || true
  mark ffmpeg
fi

# ---------------- post-install ----------------
if [ -f "$INSTALL/include/plutovg/plutovg.h" ]; then
  cp -f "$INSTALL/include/plutovg/plutovg.h" "$INSTALL/include/"
fi
touch "$INSTALL/.stamp_done"
log "all deps ready: $INSTALL"
