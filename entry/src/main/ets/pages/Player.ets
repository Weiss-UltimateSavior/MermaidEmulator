import { router, window } from '@kit.ArkUI';
import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import artemisHost from 'libartemishost.so';
import { AppTheme } from '../common/Theme';
import { Game } from '../model/Game';
import { GameSidebar, GameSidebarItem } from '../components/GameSidebar';
import { LibraryStore } from '../store/LibraryStore';
import { SettingsStore } from '../store/SettingsStore';

const DOMAIN: number = 0x4D45;
const TAG: string = 'Player';

@Entry
@Component
struct Player {
  @State hostState: string = '正在启动内核…';
  @State sidebarVisible: boolean = false;
  private gameId: string = '';
  private timer: number = -1;
  private mainWindow: window.Window | null = null;
  private sidebarItems: GameSidebarItem[] = [
    new GameSidebarItem('menu', '游戏菜单', $r('sys.symbol.line_3_horizontal')),
    new GameSidebarItem('exit', '结束游戏', $r('sys.symbol.xmark'), true)
  ];

  aboutToAppear(): void {
    this.gameId = AppStorage.get<string>('playerGameId') ?? '';
    const game = LibraryStore.list().find((item: Game) => item.id === this.gameId);
    if (game === undefined) {
      this.hostState = '未找到游戏记录';
      return;
    }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.hostState = '无法获取应用上下文';
      return;
    }
    const config = SettingsStore.artemisConfig(game.id);
    this.setupGameWindow(context, config.orientation);
    const saveDir = `${context.filesDir}/saves/${game.id}`;
    try {
      if (!fileIo.accessSync(saveDir)) {
        fileIo.mkdirSync(saveDir, true);
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'create save dir failed: %{public}s', JSON.stringify(err));
    }
    const sidecut = config.scale === '铺满裁剪' ? 1 : (config.scale === '保持比例' ? 0 : -1);
    try {
      artemisHost.start({
        dataDir: game.path,
        saveDir: saveDir,
        osId: config.osId,
        sidecut: sidecut,
        vsync: config.vsync
      });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'start failed: %{public}s', JSON.stringify(err));
      this.hostState = '内核启动失败';
    }
    this.timer = setInterval(() => {
      this.refreshState();
    }, 300);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    artemisHost.stop();
    this.restoreAppWindow();
  }

  private setupGameWindow(context: Context, orientation: string): void {
    const preferred = orientation === '自动旋转'
      ? window.Orientation.AUTO_ROTATION_LANDSCAPE
      : window.Orientation.LANDSCAPE;
    window.getLastWindow(context).then((win: window.Window) => {
      this.mainWindow = win;
      win.setPreferredOrientation(preferred)
        .then(() => win.setWindowLayoutFullScreen(true))
        .then(() => win.setWindowSystemBarEnable([]))
        .catch((err: BusinessError) => {
          hilog.warn(DOMAIN, TAG, 'immersive landscape failed: %{public}s', JSON.stringify(err));
        });
    }).catch((err: BusinessError) => {
      hilog.warn(DOMAIN, TAG, 'get last window failed: %{public}s', JSON.stringify(err));
    });
  }

  private restoreAppWindow(): void {
    const win = this.mainWindow;
    if (win === null) {
      return;
    }
    this.mainWindow = null;
    win.setPreferredOrientation(window.Orientation.PORTRAIT)
      .then(() => win.setWindowSystemBarEnable(['status', 'navigation']))
      .catch((err: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'restore window failed: %{public}s', JSON.stringify(err));
      });
  }

  onPageHide(): void {
    artemisHost.pause();
  }

  onPageShow(): void {
    artemisHost.resume();
  }

  onBackPress(): boolean {
    if (this.sidebarVisible) {
      this.sidebarVisible = false;
      return true;
    }
    artemisHost.sendKey(8, true);
    artemisHost.sendKey(8, false);
    return true;
  }

  private handleSidebarAction(key: string): void {
    this.sidebarVisible = false;
    if (key === 'menu') {
      artemisHost.sendKey(93, true);
      artemisHost.sendKey(93, false);
      return;
    }
    if (key === 'exit') {
      this.getUIContext().showAlertDialog({
        title: '结束游戏',
        message: '未保存的游戏进度将会丢失，确定结束吗？',
        autoCancel: true,
        primaryButton: {
          value: '取消',
          action: () => {
          }
        },
        secondaryButton: {
          value: '结束',
          fontColor: AppTheme.danger,
          action: () => {
            router.back();
          }
        }
      });
    }
  }

  private refreshState(): void {
    const state = artemisHost.state();
    if (state === 0) {
      this.hostState = '正在启动内核…';
    } else if (state === 1) {
      this.hostState = '正在读取游戏资源…';
    } else if (state === 2) {
      this.hostState = '';
    } else if (state === 3) {
      this.hostState = '';
    } else if (state === 4) {
      this.hostState = '内核启动失败，请检查游戏目录与日志';
    } else if (state === 5) {
      this.hostState = '';
      router.back();
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      XComponent({
        id: 'artemis_surface',
        type: XComponentType.SURFACE,
        libraryname: 'artemishost'
      })
        .width('100%')
        .height('100%')

      if (this.sidebarVisible) {
        GameSidebar({
          items: this.sidebarItems,
          onClose: () => {
            this.sidebarVisible = false;
          },
          onAction: (key: string) => {
            this.handleSidebarAction(key);
          }
        })
      }

      if (this.hostState.length > 0) {
        Column() {
          Text(this.hostState)
            .fontSize(13)
            .fontColor(AppTheme.onPrimary)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .parallelGesture(
      TapGesture({ count: 1, fingers: 3 })
        .onAction(() => {
          this.sidebarVisible = !this.sidebarVisible;
        })
    )
  }
}
