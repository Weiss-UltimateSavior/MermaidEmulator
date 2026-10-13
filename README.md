# 美人鱼模拟器（MermaidEmulator）

HarmonyOS（鸿蒙）平台上的多引擎视觉小说模拟器。基于 Stage 模型与 ArkTS 构建，通过原生 C++ 内核（CMake + NAPI）接入多种游戏引擎，在手机上运行对应引擎制作的视觉小说游戏。

- 包名：`com.mermaid.emulator`
- 目标平台：HarmonyOS，targetSdk 26.0.0，arm64
- 构建方式：DevEco Studio / DevEco CLI（hvigor）

## 支持的引擎

| 引擎 | 技术路线 | 状态 |
|---|---|---|
| Artemis | 原生内核 `libartemishost.so`：GLES2 合成器 + OHAudio 音频 + FFmpeg 过场视频 | 已接入 |
| KiriKiri（TJS2 / KAG，`.xp3` / `.ks`） | krkrsdl3 内核 `libkrkrsdl3.so`：XComponent + EGL/GLES3 + OHAudio | 已接入 |
| Tyrano | ArkWeb + 本地资源服务（`onInterceptRequest`）+ JS 桥接存档 | 已接入 |
| RPG Maker MV / MZ | ArkWeb + 注入 Hook 脚本 + 虚拟鼠标 | 已接入 |

## 功能概览

- **游戏库管理**：扫描授权目录、封面刮削、显示名重命名、删除（仅移除记录，不删除磁盘文件）
- **两级引擎参数**：全局配置 + 单游戏覆盖（屏幕方向、画面比例、垂直同步等），共用 `EngineSettingsPanel`
- **沉浸播放页**：横屏全屏、隐藏系统栏、三指唤出游戏侧边栏、虚拟按键与虚拟鼠标
- **存档**：原生引擎存档重定向至应用沙箱；Web 引擎经 JS 桥接读写存档

## 工程结构

```
├── AppScope/                  应用级配置与资源
├── entry/
│   ├── src/main/ets/          ArkTS 前端
│   │   ├── pages/             主框架与三个引擎播放页
│   │   ├── view/              游戏库 / 引擎 / 设置三大视图
│   │   ├── components/        PageTopBar、GameCard、GameSidebar 等公共组件
│   │   ├── engine/            引擎注册表
│   │   ├── store/             游戏库 / 目录扫描 / 设置持久化
│   │   └── service/           封面刮削、Tyrano 存档沙箱
│   └── src/main/cpp/          原生层（CMake + NAPI）
│       ├── host/              Artemis 引擎宿主 + OHOS GL 渲染器
│       └── krkr/              krkrsdl3 构建脚本（core / environ / plugins / tjs2）
├── third_party/
│   ├── artemis-compat/        Artemis 兼容运行时（git submodule）
│   ├── krkrsdl3/              KiriKiri Z 运行时（git submodule）
│   └── krkrsdl3-deps/         FFmpeg 等依赖（本地构建，不入库）
├── tools/
│   ├── build-krkr-deps-ohos.sh  krkrsdl3 依赖一键构建
│   ├── apply_signing.py         签名配置注入
│   └── check-acl-consistency.py ACL 权限一致性检测
├── docs/                      Artemis / KiriKiri 引擎 OHOS 接入方案
└── AGENT.md                   项目 UI 与工程约定
```

## 构建

### 1. 准备子模块与依赖

```bash
git submodule update --init --recursive
bash tools/build-krkr-deps-ohos.sh   # 生成 third_party/krkrsdl3-deps（FFmpeg 等）
```

### 2. 配置签名

签名配置不入库。`build-profile.json5` 中保留 `/*SIGNING_CONFIGS*/ []` 占位标记，
将真实签名配置写入 `signing/local.json5`（该文件已被 .gitignore 排除），然后注入：

```bash
python3 tools/apply_signing.py
```

仓库的 pre-commit 钩子会阻止任何包含签名密钥的提交。

### 3. 构建安装包

```bash
hvigorw assembleHap --mode module -p module=entry@default -p product=default
```

## 文档

- [Artemis 引擎 OHOS 接入方案](docs/Artemis引擎OHOS接入方案.md)
- [KiriKiri 引擎 OHOS 接入方案](docs/KiriKiri引擎OHOS接入方案.md)

## 许可

本项目主仓库代码以 [GNU General Public License v2.0 或更高版本](LICENSE)（GPL-2.0-or-later）发布。

第三方组件保持各自许可：

- `third_party/artemis-compat`：GNU GPL v3（见子模块 `LICENSE`）
- `third_party/krkrsdl3`：Kirikiri Z 许可，BSD 类（见子模块 `LICENSE`）
- `third_party/krkrsdl3-deps`：FFmpeg 等，见各组件源码内许可声明

本项目不包含任何游戏资源；游戏仅访问用户授权目录。
