# MermaidEmulator 项目规范

## 页面结构

- 所有页面必须在顶部使用公共组件 `PageTopBar`，并显示当前页面的大标题。
- 顶部栏只放页面标题；不放副标题、操作按钮、状态徽标或其他内容。
- 页面顶部需遵循系统状态栏安全区，复用 `PageTopBar` 的安全区处理。
- 页面背景统一使用 `AppBackground`；底部主导航使用 HDS `HdsTabs` 与官方沉浸光感材质能力。
- 播放页 `pages/Player` 为原生渲染沉浸页：不使用 `PageTopBar`；进入时切换横屏（`window.Orientation.LANDSCAPE`）、全屏布局并隐藏系统栏，退出时还原竖屏与系统栏。
- 各引擎播放页的运行时游戏功能统一由三指点击唤出的侧边栏 `GameSidebar` 承载（虚拟按键与虚拟鼠标除外），功能项按引擎实际能力定制。

## 页面边距

- 页面内容左右边距统一为 `AppTheme.pagePadding`（16vp），所有页面保持一致，以游戏库页卡片边缘为基准。
- `PageTopBar` 与首个内容区块的间距统一为 `AppTheme.topBarGap`（14vp），以游戏库页为基准，其他页面不得使用不同数值。
- 列表行统一使用自绘 `SettingRow`（不用 HDS 卡片），左右边距由列表容器的 `AppTheme.pagePadding` 统一提供，行本身不再叠加；`PageTopBar`、按钮、空状态单独保留 16vp 边距。
- 弹窗（半模态面板）内列表同样遵循上述规则，操作按钮等非列表内容单独保留 16vp 边距。

## 半模态面板

- 统一使用 `bindSheet`：`detents: [SheetSize.MEDIUM, SheetSize.LARGE]`、`preferType: SheetType.BOTTOM`、保留拖拽条，使用系统默认背景材质，不额外设置标题以外的自定义样式。
- 面板不显示系统标题和关闭按钮：不传 `title`，并设置 `showClose: false`；仅通过拖拽条、下滑或点击遮罩关闭。
- 面板内容根容器上下边距统一为 20vp；列表左右边距由 `SettingRow` 所在列表容器的 `AppTheme.pagePadding` 提供。
- 面板内容高度设置为 `scrollSizeMode: ScrollSizeMode.CONTINUOUS`，展开/收起时列表区域跟手伸缩，底部主操作按钮固定贴住面板底部，不随面板浮动。
- 面板内管理列表使用 `SettingRow`，行内操作通过尾部 `BuilderParam`（suffix）传入；底部主操作按钮单独保留 16vp 左右边距。
- 行内操作使用纯文本（不加胶囊底色）；破坏性操作使用警示色文本，点击后必须通过系统 `showAlertDialog` 二次确认（取消在左，危险操作在右），确认后才执行。

## 组件视觉规范

- 页面及其组件、内容禁止添加阴影和描边；不要使用 `.shadow()`、`.border()` 或手绘描边来制造轮廓。
- 使用留白、色彩、圆角和官方材质区分层级，不通过阴影或描边强调容器。
- 所有组件图标统一使用主题色 `AppTheme.primary`；仅底部导航栏未选中态保留灰色。
- 所有组件禁用系统点击按压反馈（底部导航栏除外）：列表行使用自绘 `SettingRow`（HDS 卡片的按压效果无法通过公开 API 关闭），`Button` 使用 `.stateEffect(false)`，普通组件不加 `.clickEffect()`。

## 工程约定

- 使用 HarmonyOS Stage 模型与 ArkTS，工程通过 DevEco CLI 构建。
- 原生内核位于 `entry/src/main/cpp`（CMake + NAPI，模块名 `artemishost`）；引擎源码以 `third_party/artemis-compat` 子模块固定提交，本地联调可用 `-DARTC_SOURCE_DIR=<path>` 指向工作副本。
- Web 引擎（Tyrano）宿主位于 `pages/TyranoPlayer.ets`：ArkWeb + `onInterceptRequest` 提供 `http://127.0.0.1` 固定 origin 的本地资源服务（含 Range、入口注入），`javaScriptProxy`（`appJsInterface`）桥接存档；注入脚本在 `resources/rawfile/tyrano_hook.js`，存档沙箱在 `service/TyranoStore.ets`。
- HarmonyOS 原生 GL 必须链接 `GLESv3`（真实实现在 `/system/lib64/libGLESv3.so`，`libGLESv2.so` 仅是 `/system/lib64/ndk` 下的桩，直接调用为空操作），并通过 `ARTC_GLES_TARGET` 传给自研引擎。
- 页面间新增复用能力应优先抽取公共组件，避免重复实现页面标题栏和材质效果。
