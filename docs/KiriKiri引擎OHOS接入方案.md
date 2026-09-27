# KiriKiri 引擎接入方案（krkrsdl3 → MermaidEmulator / HarmonyOS）

> 状态：v0.2（决策已确认；M0 构建基线完成，待真机验证）· 2026-09-27
> 参考仓库：
> - 引擎核心：`krkrsdl3`（git submodule `third_party/krkrsdl3`，fork `Weiss-UltimateSavior/krkrsdl3` @ `c82b9a9`，
>   含本方案本地补丁）
> - 构建系统：`krkrsdl3_build`（源列表与依赖脚本参考；本地 `/Users/weiss/opencode/krkrsdl3_build`）
> 目标应用：MermaidEmulator（HarmonyOS Stage / ArkTS，targetSdk 26.0.0，arm64-v8a）

## 1. 目标与范围

- 把 krkrsdl3 的 KiriKiri（TJS2/KAG）运行时接入 MermaidEmulator，使引擎列表中的 `KiriKiri`（`kirikiri`，`.xp3` / `.ks`）由占位转为可运行，支持 `.xp3` 单包与含 `startup.tjs` 的目录。
- 一期范围（M0–M4）：
  - 原生渲染：XComponent(SURFACE) → EGL → OpenGL ES3（`GLRenderBackend`）；
  - 音频：OHAudio 后端（引擎已实现）；
  - 输入：触摸映射（1 指左键、2 指右键、拖动）+ **物理键盘 `sendKey` + IME `sendText` 回传**；
  - 存档：重定向到应用沙箱（游戏目录只读）；
  - 播放页：横屏全屏、三指侧边栏、返回游戏库、前后台生命周期；
  - 商店/列表接入：`GameFolderStore` 检测、`EngineRegistry` 状态、启动路由、包体评估。
- 非目标（一期不做）：
  - 系统输入框/文件选择器（`ohos_dialog.cpp` 桩保持）；
  - Vulkan 后端（OHOS 使用 GL 即可）；
  - 游戏资源下载/分发（仅访问用户授权目录）。
- 合规：仓库不入库游戏资源；krkrsdl3 采用 Kirikiri Z 许可（BSD 类，见 `LICENSE`），接入后在 `THIRD_PARTY_NOTICES` 记录来源与许可。

## 2. krkrsdl3 分析

### 2.1 分层与宿主契约

| 层 | 内容 | 与宿主关系 |
|---|---|---|
| `tjs2/` | TJS2 脚本内核（解释器）+ oniguruma 正则 | 随引擎编译，无平台依赖 |
| `core/archive` | XP3/归档、`TVPStorage` 虚拟文件系统、`savedata` 映射 | 由工程参数驱动（§4.8） |
| `core/main` | `TVPApplication`、`WindowManager`、事件队列、帧驱动 | 宿主提供 `Run()`/`RenderOnce` 循环 |
| `core/media` | 字体（FreeType）、图片（PNG/JPEG/WebP/TLG）、视频（FFmpeg）、音频解码 | 依赖第三方静态库 |
| `core/render` | `RenderBackend` 抽象（GL/SW/Vulkan）+ 合成器 + 2D 网格 | OHOS 固定 GLES3 后端 |
| `core/script` | TJS2 native 绑定（System/Window/Layer/Sound/KAGParser…） | 与 `environ` 平台函数对接 |
| `plugins/` | KAGParserEx/ExtKAGParser、Kirikiroid2（zip/7z/tar）、emoteplayer、psbfile、sqlite3、LayerEx*、extrans 等 | 全平台编译（D3D 插件实为后端抽象，无 D3D 头依赖） |
| `environ/` | 平台差异层；**OHOS 分支已存在**（见 2.2） | 宿主替换点 |

入口形态：CMake 产出共享库 `libkrkrsdl3.so`（`add_library(krkrsdl3 SHARED ...)`，ANDROID/OHOS 同构），通过 NAPI 模块 + 渲染线程驱动；引擎不依赖 SDL（`USE_SDL3=OFF` 时 OHOS 直接 `#include <GLES3/gl3.h>` 并链接 NDK `EGL/GLESv3`）。

### 2.2 OHOS 现状（上游已具备，可直接复用）

| 文件 | 职责 |
|---|---|
| `environ/ohos/ohos_entry.cpp` | NAPI 模块注册 + 渲染线程（EGL ES3、`KRKRSDL3::TVPRenderOnce`、`Application->Run()`）+ 平台窗口钩子（标题/全屏/IME/swap） |
| `environ/ohos/ohos_core.cpp` | rawfile 资源流（`NativeResourceManager`）、OS 名称、菜单/软件渲染/libpng NEON 桩 |
| `environ/ohos/ohos_file.cpp` | POSIX 文件流、目录遍历、拷贝/删除（musl） |
| `environ/ohos/ohos_audio.cpp` | OHAudio 渲染器 + 环形缓冲（引擎音频后端） |
| `environ/ohos/ohos_thread.cpp` | pthread 线程/互斥/事件 |
| `environ/ohos/ohos_utils.cpp` | `stat`、屏幕信息、时间、平台名 |
| `environ/ohos/ohos_input.cpp` / `ohos_dialog.cpp` | 输入框/消息框/文件选择器桩（日志） |

NAPI 接口（`krkrsdl3_build/ohos/entry/src/main/cpp/types/libkrkrsdl3/index.d.ts`）：
`initEngine(gamePath)`、`setResourceManager(resMgr)`、`setSurface(surfaceId)`、`shutdown()`、`sendMouseEvent(type, x, y, button)`、`registerCallbacks(titleCb, fullscreenCb, imeCb)`、`updateWindowSize(w, h)`。

ArkTS 参考实现（`krkrsdl3_build/ohos/entry/src/main/ets/pages/Index.ets`）已示范：
`XComponent(SURFACE, libraryname: 'krkrsdl3')` + `getXComponentSurfaceId()` → `setSurface`；`onAreaChange` → `updateWindowSize`（vp×density→px）；
触摸映射：单指=左键、双指=右键、拖动=移动、**3 指及以上直接清空跟踪**（与三指侧边栏不冲突）。

构建侧：`krkrsdl3_build/CMakeLists.txt` 有完整 `OHOS` 分支（源列表见 `cmake/cmake_*.txt`），链接 `EGL GLESv3 native_window hilog_ndk.z ace_napi.z ace_ndk.z ohaudio rawfile.z native_media_*`；`ohos/build-ohos.ps1` 负责交叉编译 13 个第三方依赖并打包 HAP。

### 2.3 缺口（接入必须补齐，均可在 fork / 宿主侧解决）

| 缺口 | 现状 | 影响 | 对策 |
|---|---|---|---|
| NAPI 模块名不一致 | `nm_modname = "krkrsdl3_napi"`，库名 `libkrkrsdl3.so` | `import krkr from 'libkrkrsdl3.so'` 可能加载失败 | 改为与库名一致（本项目 `artemishost` 是正确范式） |
| 渲染线程 `exit(0)` | `ohos_entry.cpp:99` | 退出播放页会杀掉整个 App 进程 | 改为线程正常返回 + 引擎可重启；`shutdown` 幂等 |
| surface 未就绪时 `join` 死等 | `while (!g_nativeWindow) usleep(16000)` | 快速返回会卡 UI | 等待循环加停止条件/超时 |
| 存档固定 `<游戏目录>/savedata/` | `core/utils/TVPSettings.cpp:262` | 本项目授权目录只读，存档失败 | NAPI `setSaveDir`，在 `TVPParseArguments` 后覆盖 `TVPDataPath/TVPNativeDataPath` 并建目录 |
| 屏幕信息硬编码 1280×720 | `ohos_utils.cpp` `tTVPScreen` | 全屏/缩放判断不准 | 用 `winWidth/winHeight`（`updateWindowSize`）回填 |
| 无键盘 / IME 半边桥 | `sendMouseEvent` only；IME 仅 `showTextInput` | 快捷键与游戏内取名不可用 | 一期补齐：引擎已有 `KRKR_Trig_KeyDown/Up`（VK）与 `KRKR_Trig_TextInput`（UTF-8），新增 NAPI `sendKey/sendText` + ArkTS 键盘/IME 浮层（§4.6） |
| 消息框/文件选择器为桩 | `ohos_dialog.cpp` | 少数游戏弹窗无 UI | 一期接受，日志可见 |
| 依赖构建脚本 Windows-only | `ohos/build-ohos.ps1`（PowerShell+MSYS2） | macOS 无法直接构建 | 移植为 bash/zsh（版本与 ffmpeg 参数已在脚本内固化） |
| OHOS 分支未实测编译 | 本机 `out/ohos` 不存在 | 可能暴露链接缺口 | M0 先在本机交叉编译 + 真机跑通 build 仓库 OHOS 工程 |

## 3. MermaidEmulator 现状

- 引擎抽象与列表：`engine/EngineRegistry.ets` 已含占位 `new PlannedEngine('kirikiri', 'KiriKiri', …)`；`KernelView` 只展示 `READY` 引擎。
- 游戏库：`store/GameFolderStore.ets` 仅有 Artemis/Web 检测（`system.ini`、`index.html`、`rpg_core.js` 等），**无 `.xp3` 检测**；`store/LibraryStore.ets` 记录 `path/engineId/coverPath`。
- 播放页范式：`pages/Player.ets`（原生 XComponent + `libartemishost.so`）与 `pages/WebPlayer.ets`（ArkWeb）；公共三指侧边栏 `components/GameSidebar.ets`；返回键策略、横屏全屏、前后台均已实现。
- 原生范式：`entry/src/main/cpp/CMakeLists.txt` 以 `add_subdirectory(third_party/artemis-compat)` + NAPI 目标 `artemishost` 产出 `libartemishost.so`，链接 `EGL GLESv3 libace_napi.z.so libace_ndk.z.so libnative_window.so libhilog_ndk.z.so`。
- 引擎参数：全局/单游戏两级配置（`EngineSettingsPanel`）；KiriKiri 一期只有「屏幕方向 / 结束游戏」等通用项。

## 4. 集成总体设计

### 4.1 形态与依赖

- krkrsdl3 核心以 **git submodule** 引入：`third_party/krkrsdl3`（pin fork 提交；本地联调用 CMake 变量 `KRKR_SOURCE_DIR` 指向工作副本）。
- 第三方静态依赖（zlib/libpng/libjpeg-turbo/libwebp/freetype/oniguruma/ogg/opus/vorbis/opusfile/glm/plutovg/ffmpeg）由本仓库脚本交叉编译，产物放 `third_party/krkrsdl3-deps/install/arm64-v8a`（或构建缓存目录，脚本 + 版本清单入库、二进制不入库）。
- entry 原生工程新增目标 **`krkrsdl3`**（SHARED，`libkrkrsdl3.so`），NAPI 模块名与库名一致；`USE_SDL3=OFF`、`USE_RENDER_GL=ON`、`USE_RENDER_VK=OFF`、`USE_FFMPEG=ON`（体积敏感时可切换为 OFF + 视频桩）。
- 后端显式声明：OHOS 分支必须命中（`-DOHOS=TRUE -DUSE_SDL3=OFF`），缺依赖即编译失败，不允许静默降级。

### 4.2 模块与职责

```text
ArkTS  pages/KirikiriPlayer.ets（XComponent(SURFACE, libraryname:'krkrsdl3') + 三指侧边栏 + 生命周期）
  │  import krkr from 'libkrkrsdl3.so'
  ▼
libkrkrsdl3.so（NAPI）
  ├── ohos_entry（模块注册 / surfaceId→OHNativeWindow / 输入注入 / 回调线程安全封装）
  ├── 引擎渲染线程（EGL ES3 + GLRenderBackend + Application 帧循环）
  ├── environ/ohos（文件/音频/线程/对话框桩）
  └── core + plugins + tjs2（KAG/TJS2 全量运行时）
```

### 4.3 生命周期时序

1. 列表「启动游戏」→ `router.pushUrl('pages/KirikiriPlayer')`，`AppStorage` 传 `playerGameId`（与现有两页一致）。
2. 播放页 `aboutToAppear`：切横屏/全屏、隐藏系统栏；创建 XComponent；`krkr.registerCallbacks(…)`；`krkr.setResourceManager(ctx.resourceManager)`；`krkr.setSaveDir(saveDir)`；`krkr.initEngine(gamePath)`。
3. XComponent `onLoad` → `setSurface(surfaceId)`；`onAreaChange` → `updateWindowSize`。渲染线程在 surface 就绪后建 EGL、跑 `TVPParseArguments` → `Application->StartApplication()` → 帧循环。
4. 退出（侧边栏「结束游戏」/页面销毁）：`krkr.shutdown()` → 引擎线程 `OnExit` → EGL 释放 → 线程返回（**不 `exit(0)`**）→ NAPI 回传状态 → 页面返回游戏库；二次进入重新 `initEngine`。
5. 前后台：`onPageShow/onPageHide` → `krkr.resume()/pause()`（一期至少暂停/恢复音频与帧循环）。

### 4.4 线程模型

- 引擎可变调用串行在渲染线程；NAPI 只做入队/赋值（`g_running`/`g_nativeWindow` 原子化）。
- 首版沿用上游实现（ArkTS 主线程直接调 `KRKR_Trig_MouseDown/Up/Move`），M2 若发现竞态改为 `InputEvent` 队列 + 渲染线程 drain。
- `shutdown`：置停止标志 → 唤醒 surface 等待 → `pthread_join`（带超时保护，避免死锁）→ 清空回调（threadsafe function release）。

### 4.5 渲染

- EGL：`eglGetDisplay(EGL_DEFAULT_DISPLAY)` → 配置含 `EGL_OPENGL_ES3_BIT` + `EGL_ALPHA_SIZE=8`（本项目 Artemis 已验证该配置在 OHOS 可用，可复用三档回退思路）→ `eglCreateWindowSurface(OHNativeWindow)` → `eglMakeCurrent`。
- 呈现：`GLRenderBackend` 内部 `eglSwapBuffers`（`TVPSwapBuffersBackend`）。
- 尺寸：`updateWindowSize(px)` → `TVPGetWindowSize`；`tTVPScreen` 补丁同步（§2.3）。
- surface 变化：尺寸变化仅 `updateWindowSize`；surface 销毁重建走「释放 EGL surface → 用新 window 重建 → 保留引擎会话」；应用重启（进程存活）时走完整 shutdown/init。
- 性能：`eglSwapInterval`；后续可按需启用引擎侧重绘门控。

### 4.6 输入映射（首版）

| 事件 | 映射 |
|---|---|
| 单指按下/抬起 | 左键 down/up（`sendMouseEvent(0/1,x,y,1)`），抬起未拖动即点击 |
| 单指移动 | 鼠标移动（`type=2`） |
| 双指点按 | 右键（KAG 菜单/跳过菜单，`button=2`）——与上游 Index.ets 一致 |
| 三指点击 | **不发给引擎**，ArkUI `TapGesture({fingers:3})` 唤出 `GameSidebar` |
| 物理键盘 | `.onKeyEvent` → ArkUI `KeyCode` 映射 Windows VK → `sendKey(vk, down)`（`TVPConvertKeyCodeToVKCode` OHOS 为恒等，直接传 VK） |
| IME 文本 | 引擎 `TVPShowIME` 回调 → ArkTS 浮层 `TextInput`；提交文本 `sendText(utf8)`（引擎 `KRKR_Trig_TextInput`），退格/回车走 `sendKey(VK_BACK/VK_RETURN)` |
| 返回键 | 优先关侧边栏；未开时可选：合成右键打开游戏菜单 / 返回确认 |

### 4.7 音频

- 引擎 `ohos_audio.cpp` 已实现 OHAudio 渲染器（`AUDIOSTREAM_USAGE_GAME`、S16LE 立体声、环形缓冲）；宿主只需生命周期（前台 resume / 后台 pause，必要时清空缓冲避免爆音）。
- 应用级音量（`stg_volume`）一期不接；引擎内音量由游戏设置控制。

### 4.8 资源与存档路径

- `dataDir = Game.path`：用户授权目录（`FILE_ACCESS_PERSIST` 只读激活），传入 `initEngine` 的 `gamePath`（`data.xp3` 或游戏目录）。
- `saveDir = ${filesDir}/krkr_saves/${gameId}`：宿主创建；新增 NAPI `setSaveDir(path)`，渲染线程在 `TVPParseArguments` 后把 `TVPDataPath/TVPNativeDataPath` 覆盖为 `file://<saveDir>/savedata/` 与本机路径，并 `TVPSetLogLocation` 指回沙箱；游戏仍从授权目录读取资源。
- 目录检测：`GameFolderStore.detectEngine` 增加 `*.xp3`（顶层 `data.xp3` 优先）或含 `startup.tjs` 的目录 → `kirikiri`；`normalizeGameDir` 处理 `data.xp3` 作为入口文件时取父目录。

### 4.9 ArkTS 侧接口（d.ts 扩展）

```ts
export const initEngine: (gamePath: string) => boolean;
export const setSaveDir: (path: string) => void;          // 新增
export const setResourceManager: (resMgr: object) => boolean;
export const setSurface: (surfaceId: string) => boolean;
export const sendMouseEvent: (type: number, x: number, y: number, button: number) => void;
export const sendKey: (vk: number, down: boolean) => void; // 新增（Windows VK）
export const sendText: (text: string) => void;             // 新增（UTF-8，IME 提交）
export const registerCallbacks: (
  titleCb: (title: string) => void,
  fullscreenCb: (full: boolean) => void,
  imeCb: (show: boolean, x: number, y: number, w: number, h: number) => void
) => void;
export const updateWindowSize: (width: number, height: number) => void;
export const pause: () => void;                            // 新增
export const resume: () => void;                           // 新增
export const shutdown: () => void;                         // 幂等、可重启
```

播放页与侧边栏：
- `pages/KirikiriPlayer.ets` 对齐 `Player.ets` 规范（横屏、沉浸、返回键策略），新增 `main_pages.json` 注册；
- 侧边栏（`GameSidebar`）一期功能：`游戏菜单`（合成右键）、`游戏存档`/`游戏读档`（调 KAG 菜单后由玩家操作）、`结束游戏`（确认框）；
- `LibraryView`：`kirikiri` 加入原生引擎路由（非 Web）；`EngineRegistry` 把 `kirikiri` 置 `READY`、`runtime='krkrsdl3'`。

## 5. 目录与文件规划

```text
third_party/krkrsdl3/                        # git submodule（pin fork 提交）
third_party/krkrsdl3-deps/                   # 依赖构建产物（脚本+清单入库，二进制不入库）
tools/build-krkr-deps-ohos.sh                # macOS/Linux 依赖交叉编译脚本（移植自 build-ohos.ps1）
entry/src/main/cpp/
  CMakeLists.txt                             # add_subdirectory(krkrsdl3 适配层) + artemishost 保持不变
  krkr/CMakeLists.txt                        # OHOS 源列表（复用 krkrsdl3_build/cmake/*.txt 或上游 CMake）
entry/src/main/cpp/types/libkrkrsdl3/
  index.d.ts / oh-package.json5              # NAPI 类型
entry/src/main/ets/pages/KirikiriPlayer.ets  # 播放页（NAPI 封装 + 触摸/侧边栏/生命周期）
entry/src/main/ets/engine/KirikiriEngine.ets # 引擎信息（READY、progress、描述）
```

## 6. 构建接入

> 决策：**直接在本项目 entry 内联编译**（不走独立 `krkrsdl3_build/ohos` 工程）；依赖由开发者本地生成到 `third_party/krkrsdl3-deps`（二进制不入库）；FFmpeg 一期开启。

1. **依赖（一次性）**：`tools/build-krkr-deps-ohos.sh`（由 `build-ohos.ps1` deps 段移植）：
   - 工具链：`$DEVECO_SDK_HOME/default/openharmony/native/build/cmake/ohos.toolchain.cmake`、`-DOHOS_ARCH=arm64-v8a`、Ninja；
   - 组件与版本：zlib 1.3.1、libpng 1.6.43（`PNG_ARM_NEON=off`，OHOS ARM 调色板扩展缺陷）、libjpeg-turbo 3.0.4、ogg 1.3.5、opus 1.5.2、vorbis 1.3.7、opusfile 0.12（无 CMake，手工 clang 编译）、freetype 2.13.2、libwebp 1.4.0、oniguruma 6.9.9、glm 1.0.1、plutovg 0.0.6、ffmpeg n7.1（白名单解码器，参数照抄脚本）；
   - 产物：`third_party/krkrsdl3-deps/install/arm64-v8a/{lib,include}`，每个依赖带 `.stamp_*` 防重跑（源码克隆在 `src/`）。
2. **引擎目标**：entry CMake 增加 `krkrsdl3` SHARED 目标（源列表来自构建仓库 `cmake/cmake_*.txt`，路径变量化为 `${KRKR_SOURCE_DIR}`），`target_link_libraries` 用依赖产物 + `EGL GLESv3 native_window hilog_ndk.z ace_napi.z ace_ndk.z ohaudio rawfile.z`；`target_compile_definitions(_KRKRSDL3_OHOS=1 _KRKRSDL3_GLES=1 _KRKRSDL3_USE_OPENGL=1 _KRKRSDL3_USE_FFMPEG=1)`；缺依赖时 `FATAL_ERROR` 并提示先跑依赖脚本。
3. **entry/build-profile.json5**：保留现有 `externalNativeOptions`（同一 CMake 工程内新增目标，无需新增配置；如拆分子目录需同步 `abiFilters: ["arm64-v8a"]`）。
4. **fork 最小补丁（建议按上游规范小提交）**：
   - `environ/ohos/ohos_entry.cpp`：`nm_modname` 改库名；移除 `exit(0)`；surface 等待加停止条件；新增 `setSaveDir/pause/resume`，`shutdown` 幂等 + 超时；回调释放；
   - `environ/ohos/ohos_utils.cpp`：`tTVPScreen` 用实际窗口尺寸；
   - `core/utils/TVPSettings.cpp`：不直接改（由宿主在 `TVPParseArguments` 后覆盖路径，改动面最小）；若必须改，抽 `TVPSetSaveDataPath()` 供宿主调用。
5. **包体**：Android arm64 实测 `libkrkrsdl3.so`（含 FFmpeg，stripped）25–27MB；当前 HAP 6.2MB，接入后预计 30–40MB；体积敏感时先 `USE_FFMPEG=OFF`（无过场视频）。

## 7. 阶段计划与验收

| 阶段 | 内容 | 验收 |
|---|---|---|
| **M0** 构建基线 | macOS 依赖脚本移植；build 仓库 OHOS 工程在真机跑通（`initEngine`+surface+首帧） | HAP 安装启动，日志出现 EGL ready / Engine startup；崩溃路径可控 |
| **M1** 首帧与解析 | 引擎读入测试 `.xp3`（合法持有），到标题/首段文字；`tvpgl`/字体/图片加载正常 | 真机画面到标题；无花屏/黑块；日志无 GL 错误 |
| **M2** 输入与音频 | 触摸推进、双指右键、拖动；OHAudio BGM/SE/语音；窗口尺寸/横屏正确 | 点击可推进对话；有声；旋转/分屏不崩 |
| **M3** 存档与生命周期 | `setSaveDir` 沙箱存档/读档；`shutdown` 后返回游戏库并可再次启动；前后台 pause/resume | 存档文件落盘 `filesDir/krkr_saves/<id>/savedata/`；退出重进稳定；后台恢复有声画 |
| **M4** 项目集成 | submodule + entry CMake + `KirikiriPlayer` 页 + 引擎检测/READY/路由 + 侧边栏功能 + **物理键盘 `sendKey` / IME `sendText` 桥接** + 包体报告 | 「启动游戏」全链路可用；键盘/取名输入可用；引擎页显示 KiriKiri READY；`AGENT.md`/文档同步 |

每阶段同步：`KirikiriEngine.progress`、`docs` 验证记录、必要时更新 `AGENT.md`（播放页/引擎约定）。

## 8. 风险与对策

| 风险 | 影响 | 对策 |
|---|---|---|
| OHOS 分支从未实际编译 | 链接缺口/编译错误集中爆发 | M0 先在 build 仓库独立工程交叉编译 + 真机跑通，再接入本项目 |
| 依赖脚本平台差异（Windows→macOS） | 无法构建依赖 | 固化版本/参数移植为 bash；必要时在 Windows/CI 产出依赖包并校验和留档 |
| `exit(0)`/全局态导致不可重启 | 退出播放页杀进程 | fork 补丁 + M3 专项验证「退出→重进→换游戏」 |
| 授权目录只读 | 存档/日志写入失败 | `setSaveDir` 沙箱重定向（§4.8），与 artemis 的 `saveDir` 方案一致 |
| 无键盘/IME 半桥 | 个别游戏取名/快捷键不可用 | 一期接受并记录；M4 评估 `sendKey` 与 `inputMethod` 回传 |
| FFmpeg 体积 | HAP 增大 ~20MB+ | 一期可 `USE_FFMPEG=OFF`；开启时仅白名单解码器 |
| 性能/发热 | 掉帧 | `eglSwapInterval` + 引擎重绘门控；避免每帧全量纹理上传 |
| 上游漂移 | 集成破坏 | submodule pin + `KRKR_SOURCE_DIR` 本地联调；补丁尽量上层小提交 |
| JIT 合规 | 无法上架 | 已核查：`tjs2/core` 无 `PROT_EXEC`/`mprotect`/JIT 代码（TJS2 为纯解释器）；sqlite3 的 `dlopen` 扩展加载路径不启用；结论：符合 HarmonyOS 无 JIT 限制 |
| 合规 | 法律风险 | 不入库游戏资源；Kirikiri Z 许可与 FFmpeg（LGPL 配置）记入 `THIRD_PARTY_NOTICES` |

## 9. 验证计划

- 构建：`tools/build-krkr-deps-ohos.sh` 可重复产出依赖；`hvigorw assembleHap` 包含 `libs/arm64-v8a/libkrkrsdl3.so`；
- 静态检查：`readelf -d` / `nm -D` 检查导出（NAPI `Init`）与依赖（EGL/GLES3/ohaudio/rawfile/hilog）；
- 真机冒烟（自有合法游戏）：启动 → 标题 → 点击推进 → 存档 → 读档 → 音频 → 后台/恢复 → 侧边栏 → 退出 → 重进；
- 异常路径：`.xp3` 缺失/损坏、目录无权限、surface 秒毁重建、低内存、重复 `initEngine`；
- 记录：每阶段在本文档追加「验证记录」（设备型号、SDK 版本、结果、未验证项）。

### 验证记录

**M0（2026-09-27，macOS / Apple Silicon，DevEco SDK 26，cmake 4.3.4 + ninja 1.13.2）**

- 依赖：`tools/build-krkr-deps-ohos.sh` 一次性交叉编译 13 个组件成功
  （`third_party/krkrsdl3-deps/install/arm64-v8a`，163MB，`src/` 为克隆缓存；均已 gitignore）。
  过程中两处平台修正：libpng 的 `genout` 宿主预处理需显式传 `--target/--sysroot`；ffmpeg 的 target clang
  使用 `aarch64-unknown-linux-ohos-clang` 包装器。
- 内联构建：`hvigorw assembleHap` 成功，产出 `libs/arm64-v8a/libkrkrsdl3.so`
  （未裁剪 118MB，HAP 内 31MB）与既有 `libartemishost.so`；HAP 44MB（接入前 6.2MB）。
  依赖引用（DT_NEEDED）：EGL / GLESv3 / native_window / hilog_ndk.z / ace_napi.z / ace_ndk.z /
  ohaudio / rawfile.z / libc++_shared。
- 引擎资源：`Res/DroidSansFallback.ttf`（7MB）已随 rawfile 打包（引擎默认字体走 `GetResourceStream`）。
- fork 本地补丁（子模块 `third_party/krkrsdl3` 工作区，待推送 fork 后 bump pin）：
  `ohos_entry.cpp`（`nm_modname→krkrsdl3`、移除 `exit(0)`、surface 等待可中断、`setSaveDir`
  存档/日志沙箱重定向、`pause/resume`、`sendKey/sendText`、TSFN 释放与标题字符串生命周期）、
  `ohos_utils.cpp`（`tTVPScreen` 使用实际窗口尺寸）。
- 未验证（待真机）：首帧渲染、音频、触摸/键盘/IME、存档落盘、退出后重进与换游戏、
  surface 销毁重建、包体与性能。

## 10. 决策记录（2026-09-27 已确认）

1. 构建形态：**直接在本项目 entry 内联编译**（不先走独立 OHOS 工程验证；真机验证与项目接入合并推进）。
2. 依赖形态：`third_party/krkrsdl3-deps` 产物**随开发者本地生成，不入库**（脚本 + 版本清单入库）。
3. FFmpeg：**一期开启**（约 +20MB，过场视频可用）。
4. 侧边栏功能项：`游戏菜单 / 游戏存档 / 游戏读档 / 结束游戏`（维持四项，不增减）。
5. 播放页：路由页 **`pages/KirikiriPlayer.ets`**（与 `Player.ets` 一致）。
6. 键盘/IME：**一期必须**（`sendKey` + `sendText` + ArkTS 输入浮层，随 M4 落地）。
