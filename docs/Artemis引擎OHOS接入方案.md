# Artemis 引擎接入方案（artemis-compat → MermaidEmulator / HarmonyOS）

> 状态：v0.2（决策已确认，准备按 M0 开工）· 2026-09-26
> 参考仓库：`/Users/weiss/opencode/artemis-compat`（main @ `9f62262`，2026-09-22）
> 目标应用：MermaidEmulator（HarmonyOS Stage 模型 / ArkTS，targetSdk 26.0.0，phone / arm64）

## 1. 目标与范围

- 把 artemis-compat 的 Artemis 兼容运行时接入 MermaidEmulator，使「启动游戏」可以真正运行 Artemis 引擎的视觉小说。
- 一期范围：本地游戏目录 → 原生渲染（GLES2）+ 音频（OHAudio）+ 输入 + 存档 + `[dialog]` 命名输入框 + **过场视频（FFmpeg）**；覆盖手机竖屏/横屏的窗口与前后台生命周期。
- 非目标（一期不做）：PC/Windows 游戏、模拟器类内核、云存档、游戏资源二次分发、应用内调试日志面板。
- 合规：仓库不入库任何游戏资源与第三方闭源组件；游戏仅从用户授权目录只读访问。

## 2. artemis-compat 分析

### 2.1 分层与宿主契约

| 层 | 内容 | 与宿主关系 |
|---|---|---|
| `core/engine_context` | 唯一装配点：pack / ini / audio / compositor / lua / runner | 宿主持有 `EngineContext`，只经其访问器操作 |
| `script/` | Lua 5.1.5 嵌入、`e` 桥表、.iet 解释器、.asb runner、tag 派发 | 宿主每帧驱动 `RunEnterFrame` / `ExecuteLine` / 队列 |
| `render/` | GLES2 合成器、文本栅格化、过渡、E-mote | `Compositor::Update/Draw` 需要 GL 上下文 current |
| `audio/` | Vorbis 流 + 后端实现（OPENSL / OHAUDIO / NULL） | 后端按平台选择，宿主只做生命周期控制 |
| `pack/ config/ save/ input/ util/` | pf8 包、system.ini、BOW/ARCV 存档、输入状态、工具 | 纯 C++，无平台依赖 |

宿主契约（`docs/embedding.md`）：**窗口、GL 上下文、帧循环、输入、UI 由宿主负责**；引擎不创建窗口、不 swap、不 sleep。生命周期四段：

```text
EngineContext::Open(data_dir, os_id, key[, save_dir])   // 无 GL：pfs 链 + system.ini + audio + stage 尺寸
        │  （宿主建立 GL 上下文并 current）
        ├── Start(with_compositor=true)                  // compositor Init + Lua 会话
        ├── BootFramework(false)                         // first.iet → adv 框架（交互宿主让帧循环 drain）
        └── 每帧：输入入队 → RunEnterFrame → runner.ExecuteLine → drain 队列
                 → compositor.Update(nowMs) → Clear → compositor.Draw() → eglSwapBuffers → EndFrame
Shutdown()                                               // GL 仍 current 时调用
```

硬性规则：
- 所有可变引擎调用必须**串行化到宿主同一线程**；`EngineContext::Current()` 仅服务 JNI shim，不是并发 API。
- 窗口/GL 丢失后的重建顺序（对齐 `src/jni/native_activity.cpp:408-430`）：
  `Renderer 释放 → compositor.ReleaseGl() → ResetSession() → 新 surface 上重建 EGL → 重新 Start() + BootFramework()`。

### 2.2 OHOS 现状（上游已具备，可直接复用）

- **图形**：`cmake/ArtemisBackends.cmake` 在 OHOS 下 AUTO 选择 GLES（链接系统 `EGL` / `GLESv2`），`ARTC_HAS_GLES` 打开，compositor 走真实 GL 路径。
- **音频**：`src/platform/ohos/audio_ohos.cpp` 完整 OHAudio 后端（每语音一个 renderer，写入回调、音量/声像、欠载统计），CMake 在 OHOS 下替换 `audio.cpp` 并链接 `ohaudio`。
- **依赖**：Lua 5.1.5、stb 系列已内置；zlib 用 NDK sysroot；日志 `hilog_ndk.z`；Lua 的 `_FORTIFY_SOURCE` 兼容已处理（`CMakeLists.txt`）。
- **嵌入形态**：`add_subdirectory` + `artemis::core`（静态库、PIC），JNI/CLI/Cocoa 宿主在子工程下默认关闭（`tests/embedded_consumer` 已示范）。

### 2.3 缺口（本方案需补齐，均在宿主侧）

| 缺口 | 说明 | 归属 |
|---|---|---|
| OHOS 宿主层 | 上游只有 Android `src/jni/native_activity.cpp` 与 macOS `src/host/mac_main.mm`；无 XComponent/NAPI 宿主 | **MermaidEmulator 侧新增** |
| 表面实现 | `render/renderer.cpp` 仅 `__ANDROID__` 分支；OHOS 需宿主自研 EGL 表面（清屏/swap/viewport/坐标换算，语义对齐上游 Renderer） | **MermaidEmulator 侧新增** |
| [dialog] 文本输入 | 引擎对话框回调是同步的；需宿主桥接到 ArkTS 弹窗（或一期不设回调=取消请求） | M5 |
| 视频 | FFmpeg 一期关闭（`ARTC_ENABLE_FFMPEG=OFF`），movie 标签为桩 | M5/后续 |
| 按键映射 | 上游 Android 映射表可参考（tap=1、back=8、enter=13、方向 37/38/39/40、menu=93、音量 136/137） | M3 |

## 3. MermaidEmulator 现状

- 纯 ArkTS Stage 应用，**无原生模块**；`build-profile.json5` 无 `externalNativeOptions`。
- 引擎抽象已就绪但为空壳：`model/Engine.ets` / `engine/ArtemisEngine.ets` / `EngineRegistry`；进度项「NAPI 运行时桥接 / 资源解包与文件系统 / 渲染与音频管线」均为 0%。
- 已有可复用能力：游戏目录扫描 + URI 持久授权（`FILE_ACCESS_PERSIST`）、封面刮削（`service/`）、引擎列表与配置面板（KernelView）、游戏操作面板（启动游戏等占位项）。
- **缺播放页**：早期 `PlayerPage.ets` 已在重构中删除，需新建。

## 4. 集成总体设计

### 4.1 形态与依赖

- artemis-compat 以 **git submodule** 引入：`third_party/artemis-compat`，固定在 `9f62262`；本地联调用 CMake 缓存变量 `ARTC_SOURCE_DIR` 指向工作副本。
- entry 模块新增 CMake 原生工程，产出 NAPI 共享库 **`libartemishost.so`**（modname `artemishost`），随 HAP 打包为 `libs/arm64-v8a/`。
- 后端显式声明（生产缺依赖即构建失败，不允许静默降级）：
  `ARTC_GRAPHICS_BACKEND=GLES`、`ARTC_AUDIO_BACKEND=OHAUDIO`、`ARTC_ENABLE_FFMPEG=OFF`（一期）。

### 4.2 模块与职责

```text
ArkTS  pages/Player.ets（XComponent(SURFACE) + 返回/菜单浮层 + 生命周期）
  │  import artemishost from 'libartemishost.so'
  ▼
libartemishost.so（NAPI，仅入队/查询，不直接调引擎）
  ├── EngineHost      引擎线程、命令队列、生命周期状态机、日志回传
  ├── OhosRenderer    OHNativeWindow → EGL/GLES2 表面、viewport、Clear/Present、StageX/Y
  ├── InputBridge     XComponent 触摸/按键 → 引擎 key id / 拖拽序列
  └── artemis::core   EngineContext（pack/ini/script/audio/compositor）
```

### 4.3 生命周期时序

1. `PlayerPage.aboutToAppear` → `artemishost.start({ dataDir, saveDir, osId })`。
2. XComponent 触发 `OnSurfaceCreated(window)`；引擎线程执行
   `eglInit(window)` → `EngineContext::Open(dataDir, osId, {}, saveDir)` →
   `Start(true)` → `BootFramework(false)`（失败则回传错误并退出播放页）。
3. 帧循环（引擎线程，见 4.4）；输入事件经 NAPI 入队，帧内派发。
4. `OnSurfaceChanged/Destroyed` → 走 §2.1 的窗口重建顺序；期间输入暂停、UI 可显示“恢复中”。
5. 退出：`[exit]` 标签（`ConsumeExitRequest`）/ 返回键短按 UI 层 / 页面销毁 →
   置停止标志 → 引擎线程 `Shutdown()`（GL current）→ 释放 EGL、线程 join → NAPI 回传状态。
6. 前后台：`onForeground/onBackground` → `pause()/resume()`（静音 + 暂停音频，见 4.7）。

### 4.4 线程模型

- 单引擎线程串行所有引擎可变调用（NAPI 调用只写命令队列，UI 线程不阻塞）。
- 输入：`mutex + deque<InputEvent>`；surface 生命周期用原子状态 + 条件变量唤醒；
  停止用 `std::atomic<bool>` + `join`。
- 帧循环与节流：优先 `eglSwapInterval(1)`（swap 阻塞到 vsync）；驱动拒绝时回退 16ms sleep（与上游一致，可用环境/参数强制 `ARTC_SWAP_INTERVAL=0` 语义）。

### 4.5 渲染

- EGL：`eglGetDisplay(EGL_DEFAULT_DISPLAY)` → `eglInitialize` → 配置 `EGL_OPENGL_ES2_BIT` →
  `eglCreateWindowSurface(..., OHNativeWindow*)` → `eglMakeCurrent`；`OHNativeWindow` 由
  `OnSurfaceCreated` 回调下发。
- 尺寸：`OH_NativeWindow_NativeWindowHandleOpt(window, GET_BUFFER_GEOMETRY, &w, &h)`。
- 清屏/呈现：`glClearColor(0,0,0,1)+glClear` / `eglSwapBuffers`（对齐 `render/renderer.cpp`）。
- viewport：与上游同公式（letterbox 适配 / `SIDECUT` 铺满裁剪），触摸坐标用同一 `StageX/StageY`。
- 重绘门控（可选，M5 性能）：`drawn_rev` + 动画/过渡/文本未决时才渲染，静态场景零绘制。

### 4.6 输入映射（首版）

| 事件 | 处理 |
|---|---|
| 单指按下/抬起 | `SetMousePoint(x,y)`；`PushKeyDown/Up(1)`；`SetTouchCount(1/0)`；抬起未拖动时 `ClickAt(x,y)`；移动超过 16px 触摸容差才进入拖拽（手指轻微抖动不吞掉点击） |
| 单指移动（按下中） | `DragMove(x,y)`（按下时若命中可拖拽层先 `BeginDrag`，抬起 `EndDrag`） |
| KEYCODE_BACK | 8（框架 MWOFF/EXIT；播放页 UI 可先拦返回键做菜单） |
| ENTER / DPAD_CENTER | 13 |
| DPAD_UP / DOWN / LEFT / RIGHT | 38 / 40 / 37 / 39 |
| 菜单键 | 93 |
| VOLUME_UP / DOWN | 137 / 136 |

映射表集中一处（`input_bridge`），后续按真机按键码补齐（`native_xcomponent_key_event.h`）。

### 4.7 音频

- 内核 OHAudio 后端直接可用（`AUDIOSTREAM_USAGE_GAME`，S16LE 立体声回调解码）。
- 宿主仅做生命周期：后台 `audio().StopAll/PauseAll`（具体方法名以 `audio.h` 为准）与恢复；
  与 Android JNI 桥的 `PauseAllInstance/ResumeAllInstance` 行为对齐。
- 音量设置项（`stg_volume`）后续接 `Audio` 主音量（M5）。

### 4.8 资源与存档路径

- `dataDir = Game.path`：用户目录（已通过 `FILE_ACCESS_PERSIST` 授权，只读）；
  目录内含 `root.pfs`/`*.pfs` 链或直接指向 `.pfs`。
- `saveDir = ${filesDir}/saves/${gameId}`：独立可写目录，与资源分离（`Open` 第四参数）。
- `osId`：一期 `windows`（与 mac 宿主一致，兼容性优先）；后续在引擎面板提供 `windows/android` 切换。
- 资源缺失/无权限：明确错误码 + Toast，不崩溃。

### 4.9 ArkTS 侧接口

`libartemishost.so` 对外 API（d.ts）：

```ts
export interface StartOptions { dataDir: string; saveDir: string; osId: string; }
export interface HostCallbacks { onState(state: number): void; onError(message: string): void; onLog(line: string): void; }
export const start: (options: StartOptions, callbacks: HostCallbacks) => void;
export const stop: () => void;
export const pause: () => void;
export const resume: () => void;
export const sendKey: (keyCode: number, down: boolean) => void;
export const resize: (width: number, height: number) => void;
```

- 新页面 `pages/Player.ets`（**路由页，决策已确认**；加入 `main_pages.json`）：`XComponent({ id, type: XComponentType.SURFACE, libraryname: 'artemishost' })` +
  返回/菜单浮层 + 加载/错误状态。
- 游戏操作面板「启动游戏」→ `router.pushUrl('pages/Player', { gameId })`；`aboutToDisappear` 调 `stop()`。
- 里程碑完成时同步更新 `engine/ArtemisEngine.ets` 的 `progress`（NAPI 桥接 / 资源解包 / 渲染音频）与 `status`。

## 5. 目录与文件规划

```text
third_party/artemis-compat/                 # git submodule（pin 9f62262）
entry/src/main/cpp/
  CMakeLists.txt                            # add_subdirectory(artemis) + NAPI 库
  napi_init.cpp                             # 模块注册、XComponent 回调注册、导出 API
  host/engine_host.{h,cpp}                  # 引擎线程/命令队列/生命周期
  host/ohos_renderer.{h,cpp}                # EGL/GLES2 表面与坐标映射
  host/input_bridge.{h,cpp}                 # 按键映射、触摸/拖拽状态机
  types/libartemishost/index.d.ts
  types/libartemishost/oh-package.json5
entry/src/main/ets/pages/Player.ets         # 播放页（XComponent）
entry/src/main/ets/service/EngineBridge.ets # NAPI 封装 + 状态回调
```

## 6. 构建接入

- `entry/build-profile.json5` 增加：

```json5
"buildOption": {
  "externalNativeOptions": {
    "path": "./src/main/cpp/CMakeLists.txt",
    "arguments": "-DARTC_BUILD_CLI=OFF -DARTC_BUILD_JNI=OFF -DARTC_BUILD_TESTS=OFF -DARTC_BUILD_MAC_HOST=OFF -DARTC_GRAPHICS_BACKEND=GLES -DARTC_AUDIO_BACKEND=OHAUDIO -DARTC_ENABLE_FFMPEG=OFF",
    "abiFilters": ["arm64-v8a"]
  }
}
```

- 权限：无需新增（游戏目录用已有 `FILE_ACCESS_PERSIST`；无网络需求）。
- 验收：`hvigorw assembleHap` 成功，产物内 `libs/arm64-v8a/libartemishost.so` 存在且可被
  `import ... from 'libartemishost.so'` 加载（模块 `Init` 日志）。

## 7. 阶段计划与验收

| 阶段 | 内容 | 验收 |
|---|---|---|
| **M0** 骨架 | submodule、CMake、NAPI 空模块、XComponent 加载 so | HAP 含 so；模块可 import；日志 Init |
| **M1** 无 GL 启动 | 引擎线程 + `Open()`（pfs 链/`system.ini`/stage 尺寸），日志回传 ArkTS | 真机日志显示包链与配置解析成功；错误路径可回传 |
| **M2** GL 首帧 | XComponent surface → EGL → 黑屏 Clear+Swap；viewport 正确；surface 重建不崩 | 屏上出现黑屏（非黑块花屏）；旋转/切后台恢复 |
| **M3** 脚本与输入 | `Start/BootFramework`、帧循环、文本/图层渲染、tap/拖拽/按键 | 真机运行实测游戏到标题/adv 文本，点击推进 |
| **M4** 音频与存档 | OHAudio 播放 BGM/SE/语音、前后台静音；save/load | 有声、音量正常；存档写入 `saveDir` 并可读回 |
| **M5** 完善 | `[dialog]` 命名输入框桥接、`[exit]` 返回游戏库、重绘门控、**过场视频（FFmpeg，见 §7.1）** | 退出/重进稳定；有视频的段落可播放；性能可接受 |

每阶段完成后同步：`ArtemisEngine.progress`、`AGENT.md` 入口约定（如新增播放页规范）。

### 7.1 FFmpeg（过场视频）专项

- 形态：与引擎相同的 OHOS arm64 静态库（`libavformat/libavcodec/libavutil/libswscale/libswresample`），
  由本仓库脚本可复现构建（源码不提交，脚本 + 校验和入库）。
- 构建：`tools/build-ffmpeg-ohos.sh` 使用 `$SDK/native/build/cmake/ohos.toolchain.cmake`，
  `--target-os=linux --arch=aarch64 --enable-cross-compile`，**默认 LGPL 配置**
  （不加 `--enable-gpl` / `--enable-nonfree`），关闭不需要的 program/doc/avdevice。
- 接入：CMake 传入 `FFMPEG_FOUND=TRUE`、`FFMPEG_INCLUDE_DIRS`、`FFMPEG_LIBRARIES`，
  并把 `ARTC_ENABLE_FFMPEG` 由 OFF 切 ON；引擎 `video_decoder.cpp` 自动走真实解码。
- 许可：仅 LGPL 组件；`THIRD_PARTY_NOTICES` 追加 FFmpeg 来源与许可；如后续需要
  GPL 编码器/过滤器需单独评估，不在本方案内。
- 验收：含视频的段落可播放/跳过；无视频路径行为与桩一致。

## 8. 风险与对策

| 风险 | 影响 | 对策 |
|---|---|---|
| GL 上下文/窗口重建时序 | 黑屏、崩溃 | 严格按 `ReleaseGl → ResetSession → 重建 EGL → Start/Boot` 顺序；真机覆盖后台/分屏/旋转 |
| 用户目录权限失效（重启后） | 打不开游戏 | 已有 `persistPermission/activatePermission`；启动前 `activate` 校验并给出重新授权引导 |
| NDK/SDK 版本差异（本机 SDK 26 / 上游 SDK20 基线） | 编译失败或运行异常 | 固定 `ohos.toolchain.cmake`；先跑通 `tests/embedded_consumer` 的 OHOS 交叉编译作为基线 |
| FFmpeg 交叉编译/许可 | 视频不播或合规问题 | 一期纳入：脚本化 LGPL 构建（§7.1），产物与校验和留档；构建失败时按可配置项回退到视频桩并明确提示 |
| 性能/发热 | 掉帧 | swap 阻塞 vsync + 重绘门控；避免脚本/纹理无效重建 |
| 上游漂移 | 集成破坏 | submodule pin + `ARTC_SOURCE_DIR` 本地联调；不改上游语义 |
| 行为保持红线 | 兼容性回归 | 不改引擎判定顺序/语义；如需上游改动，按上游 AGENT 规范小提交并附合成测试 |
| 合规 | 法律风险 | 仓库不含游戏资源/闭源组件；测试游戏仅本地、合法持有 |

补充（JIT 核查结论）：**全链路不涉及 JIT/动态代码生成**——脚本层为上游客化的
Lua 5.1.5 纯解释器（无 LuaJIT、无字节码转机器码路径），引擎与宿主均为 C++17 AOT
编译并随 HAP 签名打包；源码中无 `PROT_EXEC`/`mprotect` 等可执行内存操作，唯一
`dlopen` 位于 Lua `loadlib.c`（`LUA_DL_DLOPEN` 未启用，`package.loadlib` 不可用）。
与 HarmonyOS NEXT 对第三方应用禁止 JIT 的限制天然兼容，性能依赖解释器 + 原生 C++。

## 9. 验证计划

- 构建：`hvigorw assembleHap`（含 native）+ 可选 CMake 独立配置（`build-ohos`）跑 `ctest`
  （仅宿主回归，验证我们未破坏上游；不改上游则天然通过）。
- 静态检查：`readelf -d` / `nm -D` 检查 `libartemishost.so` 导出与依赖（EGL/GLES/ohaudio/hilog/z）。
- 真机冒烟（自有合法游戏）：启动 → 标题 → 存档 → 读档 → 音频 → 后台/恢复 → 退出 → 重进。
- 异常路径：游戏目录无权限、pfs 缺失、surface 秒毁重建、低内存。
- 记录：每阶段在本文档追加「验证记录」（设备型号、SDK 版本、结果、未验证项）。

### 验证记录

**M0（2026-09-26，真机 4EE9K25515004640，SDK 26）**

- 子模块已 pin `9f62262`；`entry/src/main/cpp` 以 CMake 全量编译 artemis-compat
  （产出 `libartemis_core.a` / `liblua51.a`，OHOS GLES + OHAUDIO 后端配置生效）。
- HAP 内含 `libs/arm64-v8a/libartemishost.so`（含 `libc++_shared.so`）。
- 真机日志（hilog `ArtemisHost`）：路由进入播放页 → `xcomponent callbacks registered` →
  `start dataDir=... osId=windows` → `surface created 2776x1224`；返回 → `stop` → `surface destroyed`。
- 未验证/待办：引擎实例尚未创建（M1）；Surface 尺寸按 buffer 朝向返回（M2 用
  `OnSurfaceChanged` 回调或 `eglQuerySurface` 校正视口）。

**M1–M4（2026-09-26，真机 4EE9K25515004640，SDK 26，实测游戏《灵感满溢的甜蜜创想凸》）**

- M1：引擎线程 + 命令队列落地；`EngineContext::Open` 成功解析用户目录
  （`/storage/Users/currentUser/galgame/.../root.pfs`，stage 1280x720，OHAudio 就绪），
  错误路径（假路径）可回传为 UI 状态。
- M2：EGL 初始化成功（横屏全屏 `egl ready 2776x1224`，`gl=OpenGL ES 3.2 · Maleoon 920C`），
  viewport letterbox 正确（`2176x1224 at 300,0`）；播放页进入时切横屏 + 隐藏系统栏
  （`setPreferredOrientation(LANDSCAPE)`、`setWindowLayoutFullScreen(true)`、
  `setWindowSystemBarEnable([])`），退出还原竖屏与系统栏。
  Surface 尺寸变化（旋转）走 `UpdateSurface`（先销毁旧 surface 再新建，保留 GL 上下文与
  游戏会话，不重启）；窗口销毁/新建才走 `ReleaseGl → ResetSession → 重新 Start/Boot`。
- M3：帧循环 + 输入就绪；实测脚本推进（`trans/wait/call/lyc/lyprop/asb jump`），
  `draw[301]: drawn=3` 真实图层绘制；点击/拖拽/按键映射（tap=1、back=8、方向 36-40、menu=93）。
- M4：OHAudio 播放语音/SE（`audio: play track:2 [2ch 48000Hz]`，欠载 0）；
  存档目录 `filesDir/saves/<gameId>` 在启动前由宿主创建（`fileIo.mkdirSync`，
  引擎 `WriteSaveFile` 不建目录），读档/存档交互待人工验证。
- 输入修复：真实手指点击会带 MOVE 抖动，原先会触发拖拽判定而丢失点击；
  现在 16px 触摸容差内的移动不进入拖拽，抬手仍派发 `ClickAt`（实测抖动点击有 tap、
  大幅滑动无 tap）。
- 兼容修复（上游子模块本地补丁，待提上游后 bump pin）：点击落到「非事件注册图层」
  时引擎只调用游戏的 `onpush` 处理器、不释放内核 clickwait（`@`/`p`/`clickwait`，
  实测 `waiting=1 accept=1` 一直挂起 → 对话无法推进）。在 `DispatchClick` 的
  回落分支追加 `AdvanceByInput()`（内部有 `wait_accept_input_`/单帧去重保护），
  先补完打字机文本、再释放等待。
- 存档验证：`filesDir/saves/<gameId>/` 下已产生 `save0001.dat` + `save0001.png`
  与 `system.dat`（真机确认存档落盘）；播放页启动前创建目录的修复有效。
- 待解决（该游戏 ADV 推进，继续排查中）：点击后脚本 runner 执行到块尾后
  `halted=1 queued=0`，框架侧应在块耗尽时 `scriptMainAdd` 里
  `e:tag{"jump", file="system/script.asb", label="click"}` 续链，但未发生 →
  无新一行文本。怀疑与该游戏「存档/读档后块位置（`scr.ip`/`ast`）恢复」或
  ADV 主循环握手相关；下一步对比全新开始 vs 继续游戏两条路径定位。

**关键平台结论（已写入工程约定）**

1. HarmonyOS 设备的真实 GLES 实现在 `/system/lib64/libGLESv3.so`；`libGLESv2.so`
   只存在于 `/system/lib64/ndk/` 且为桩实现（直接调用全部空操作，`glGetString` 返回
   空、FBO 状态为 0）。原生模块必须链接 `GLESv3`，并通过 `ARTC_GLES_TARGET`
   让引擎一同链接。
2. 本机 EGL 选择最小配置会 `EGL_BAD_MATCH(12297)`；含 `EGL_ALPHA_SIZE=8` 的配置
   可用，宿主已实现三档配置回退。
3. 视频仍为桩（FFmpeg 未接入，M5）；`[dialog]` 输入桥未接（M5）。

## 10. 决策记录（2026-09-26 已确认）

1. `osId`：**一期固定 `windows`**。
2. 过场视频：**一期纳入 FFmpeg**（§7.1）。
3. 播放页：**路由页**（`pages/Player.ets`）。
4. `[dialog]` 命名输入框：**一期要做**（同步回调 → ArkTS 弹窗的桥接方案在 M5 实现）。
5. 应用内调试日志面板：**不做**。
