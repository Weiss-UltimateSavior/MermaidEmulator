import { router, window } from '@kit.ArkUI';
import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import artemisHost from 'libartemishost.so';
import { AppTheme } from '../common/Theme';
import { Game } from '../model/Game';
import { LibraryStore } from '../store/LibraryStore';

const DOMAIN: number = 0x4D45;
const TAG: string = 'Player';

@Entry
@Component
struct Player {
  @StorageLink('safeTopVp') safeTop: number = 0;
  @State gameTitle: string = '';
  @State hostState: string = '正在启动内核…';
  @State controlsVisible: boolean = false;
  private gameId: string = '';
  private timer: number = -1;
  private mainWindow: window.Window | null = null;
  private hideControlsTimer: number = -1;

  aboutToAppear(): void {
    this.gameId = AppStorage.get<string>('playerGameId') ?? '';
    const game = LibraryStore.list().find((item: Game) => item.id === this.gameId);
    if (game === undefined) {
      this.hostState = '未找到游戏记录';
      return;
    }
    this.gameTitle = game.title;
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.hostState = '无法获取应用上下文';
      return;
    }
    this.setupGameWindow(context);
    const saveDir = `${context.filesDir}/saves/${game.id}`;
    try {
      if (!fileIo.accessSync(saveDir)) {
        fileIo.mkdirSync(saveDir, true);
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'create save dir failed: %{public}s', JSON.stringify(err));
    }
    const osId = AppStorage.get<string>('stg_engineOs') ?? 'windows';
    const scale = AppStorage.get<string>('stg_engineScale') ?? '跟随游戏';
    const sidecut = scale === '铺满裁剪' ? 1 : (scale === '保持比例' ? 0 : -1);
    const vsync = AppStorage.get<boolean>('stg_engineVsync') ?? true;
    try {
      artemisHost.start({
        dataDir: game.path,
        saveDir: saveDir,
        osId: osId,
        sidecut: sidecut,
        vsync: vsync
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
    if (this.hideControlsTimer >= 0) {
      clearTimeout(this.hideControlsTimer);
      this.hideControlsTimer = -1;
    }
    artemisHost.stop();
    this.restoreAppWindow();
  }

  private setupGameWindow(context: Context): void {
    const orientation = AppStorage.get<string>('stg_engineOrientation') ?? '固定横屏';
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
    artemisHost.sendKey(8, true);
    artemisHost.sendKey(8, false);
    return true;
  }

  private toggleControls(): void {
    this.controlsVisible = !this.controlsVisible;
    if (this.hideControlsTimer >= 0) {
      clearTimeout(this.hideControlsTimer);
      this.hideControlsTimer = -1;
    }
    if (this.controlsVisible) {
      this.hideControlsTimer = setTimeout(() => {
        this.controlsVisible = false;
        this.hideControlsTimer = -1;
      }, 4000);
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

      Column() {
        if (this.controlsVisible) {
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(22)
              .fontColor([AppTheme.onPrimary])
              .padding({ left: 4, right: 8, top: 6, bottom: 6 })
              .onClick(() => {
                router.back();
              })
            Text(this.gameTitle)
              .fontSize(16)
              .fontColor(AppTheme.onPrimary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            Text('收起')
              .fontSize(13)
              .fontColor(AppTheme.onPrimary)
              .padding({ left: 10, right: 4, top: 6, bottom: 6 })
              .onClick(() => {
                this.toggleControls();
              })
          }
          .width('100%')
          .padding({
            left: 12,
            right: 12,
            top: 10,
            bottom: 10
          })
          .backgroundColor('#66000000')
        } else {
          Stack() {
            SymbolGlyph($r('sys.symbol.line_3_horizontal'))
              .fontSize(18)
              .fontColor([AppTheme.onPrimary])
          }
          .width(38)
          .height(38)
          .borderRadius(19)
          .backgroundColor('#4D000000')
          .onClick(() => {
            this.toggleControls();
          })
        }
      }
      .width('100%')
      .padding({
        left: 12,
        right: 12,
        top: this.safeTop + 8
      })
      .alignItems(HorizontalAlign.Start)

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
  }
}
