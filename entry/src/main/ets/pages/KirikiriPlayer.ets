import { display, router, window } from '@kit.ArkUI';
import { fileIo } from '@kit.CoreFileKit';
import { inputMethod } from '@kit.IMEKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import krkr from 'libkrkrsdl3.so';
import { AppTheme } from '../common/Theme';
import { Game } from '../model/Game';
import { GameSidebar, GameSidebarItem } from '../components/GameSidebar';
import { LibraryStore } from '../store/LibraryStore';

const DOMAIN: number = 0x4D45;
const TAG: string = 'KirikiriPlayer';

const TOUCH_IDLE: number = 0;
const TOUCH_SINGLE: number = 1;
const TOUCH_MULTI: number = 2;

const VK_BACK: number = 8;
const VK_TAB: number = 9;
const VK_RETURN: number = 13;
const VK_SHIFT: number = 16;
const VK_CONTROL: number = 17;
const VK_MENU: number = 18;
const VK_ESCAPE: number = 27;
const VK_SPACE: number = 32;
const VK_LEFT: number = 37;
const VK_UP: number = 38;
const VK_RIGHT: number = 39;
const VK_DOWN: number = 40;

class FingerInfo {
  startX: number;
  startY: number;
  moved: boolean;

  constructor(x: number, y: number) {
    this.startX = x;
    this.startY = y;
    this.moved = false;
  }
}

@Entry
@Component
struct KirikiriPlayer {
  @State hostState: string = '正在启动 KiriKiri…';
  @State sidebarVisible: boolean = false;
  @State imeVisible: boolean = false;
  @State imeText: string = '';
  private xComponentController: XComponentController = new XComponentController();
  private gameId: string = '';
  private gamePath: string = '';
  private saveDir: string = '';
  private mainWindow: window.Window | null = null;
  private engineInited: boolean = false;
  private density: number = 1;
  private winWidthPx: number = 0;
  private winHeightPx: number = 0;
  private touchState: number = TOUCH_IDLE;
  private activeFingers: Map<number, FingerInfo> = new Map();
  private sidebarItems: GameSidebarItem[] = [
    new GameSidebarItem('menu', '游戏菜单', $r('sys.symbol.line_3_horizontal')),
    new GameSidebarItem('save', '游戏存档', $r('sys.symbol.archivebox')),
    new GameSidebarItem('load', '游戏读档', $r('sys.symbol.square_and_arrow_down')),
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
    try {
      this.density = display.getDefaultDisplaySync().densityPixels;
    } catch (err) {
      this.density = 1;
    }
    this.gamePath = KirikiriPlayer.resolveGamePath(game.path);
    this.saveDir = `${context.filesDir}/krkr_saves/${game.id}`;
    try {
      if (!fileIo.accessSync(this.saveDir)) {
        fileIo.mkdirSync(this.saveDir, true);
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'create save dir failed: %{public}s', JSON.stringify(err));
    }
    this.setupGameWindow(context);
    this.setupCallbacks(context);
    try {
      krkr.setSaveDir(this.saveDir);
      krkr.setResourceManager(context.resourceManager);
      this.engineInited = krkr.initEngine(this.gamePath);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'initEngine failed: %{public}s', JSON.stringify(err));
      this.hostState = 'KiriKiri 内核启动失败';
      return;
    }
    this.hostState = '';
  }

  aboutToDisappear(): void {
    this.shutdownEngine();
    this.restoreAppWindow();
  }

  onPageShow(): void {
    if (this.engineInited) {
      krkr.resume();
    }
  }

  onPageHide(): void {
    if (this.engineInited) {
      krkr.pause();
    }
  }

  onBackPress(): boolean {
    if (this.sidebarVisible) {
      this.sidebarVisible = false;
      return true;
    }
    if (this.imeVisible) {
      this.imeVisible = false;
      return true;
    }
    return true;
  }

  private static resolveGamePath(dir: string): string {
    const direct = `${dir}/data.xp3`;
    try {
      if (fileIo.accessSync(direct)) {
        return direct;
      }
    } catch (err) {
    }
    try {
      const names = fileIo.listFileSync(dir);
      for (const name of names) {
        if (name.toLowerCase().endsWith('.xp3')) {
          return `${dir}/${name}`;
        }
      }
    } catch (err) {
    }
    return dir;
  }

  private setupGameWindow(context: Context): void {
    window.getLastWindow(context).then((win: window.Window) => {
      this.mainWindow = win;
      win.setPreferredOrientation(window.Orientation.LANDSCAPE)
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

  private setupCallbacks(context: Context): void {
    krkr.registerCallbacks(
      (title: string): void => {
        window.getLastWindow(context).then((win: window.Window) => {
          win.setWindowTitle(title).catch((err: BusinessError) => {
            hilog.warn(DOMAIN, TAG, 'set title failed: %{public}s', JSON.stringify(err));
          });
        }).catch((err: BusinessError) => {
          hilog.warn(DOMAIN, TAG, 'get window for title failed: %{public}s', JSON.stringify(err));
        });
      },
      (full: boolean): void => {
        hilog.info(DOMAIN, TAG, 'fullscreen request: %{public}s', `${full}`);
      },
      (show: boolean, x: number, y: number, w: number, h: number): void => {
        this.imeVisible = show;
        if (!show) {
          this.imeText = '';
          return;
        }
        const controller = inputMethod.getController();
        try {
          controller.showTextInput();
        } catch (err) {
          hilog.warn(DOMAIN, TAG, 'showTextInput failed: %{public}s', JSON.stringify(err));
        }
        hilog.info(DOMAIN, TAG, 'ime show at %{public}d,%{public}d %{public}dx%{public}d', x, y, w, h);
      }
    );
  }

  private shutdownEngine(): void {
    if (!this.engineInited) {
      return;
    }
    this.engineInited = false;
    try {
      krkr.shutdown();
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'shutdown failed: %{public}s', JSON.stringify(err));
    }
  }

  private sendTouch(type: number, xVP: number, yVP: number, button: number): void {
    if (!this.engineInited) {
      return;
    }
    const x = Math.round(xVP * this.density);
    const y = Math.round(yVP * this.density);
    try {
      krkr.sendMouseEvent(type, x, y, button);
    } catch (err) {
    }
  }

  private openGameMenu(): void {
    const cx = Math.max(1, Math.round(this.winWidthPx / 2));
    const cy = Math.max(1, Math.round(this.winHeightPx / 2));
    this.sendTouch(0, cx / this.density, cy / this.density, 2);
    this.sendTouch(1, cx / this.density, cy / this.density, 2);
  }

  private handleSidebarAction(key: string): void {
    this.sidebarVisible = false;
    if (key === 'menu') {
      this.openGameMenu();
      return;
    }
    if (key === 'save' || key === 'load') {
      this.openGameMenu();
      this.getUIContext().getPromptAction().showToast({ message: '请在游戏菜单中选择存档或读档' });
      return;
    }
    if (key === 'exit') {
      this.confirmExit();
    }
  }

  private confirmExit(): void {
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
          this.shutdownEngine();
          router.back();
        }
      }
    });
  }

  private commitImeText(): void {
    const text = this.imeText;
    this.imeText = '';
    if (text.length === 0) {
      return;
    }
    try {
      krkr.sendText(text);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'sendText failed: %{public}s', JSON.stringify(err));
    }
  }

  private static keyCodeToVk(keyCode: number): number {
    if (keyCode >= 2000 && keyCode <= 2009) {
      return 48 + (keyCode - 2000);
    }
    if (keyCode >= 2017 && keyCode <= 2042) {
      return 65 + (keyCode - 2017);
    }
    if (keyCode >= 2090 && keyCode <= 2101) {
      return 112 + (keyCode - 2090);
    }
    if (keyCode === 2012) {
      return VK_UP;
    }
    if (keyCode === 2013) {
      return VK_DOWN;
    }
    if (keyCode === 2014) {
      return VK_LEFT;
    }
    if (keyCode === 2015) {
      return VK_RIGHT;
    }
    if (keyCode === 2016 || keyCode === 2054) {
      return VK_RETURN;
    }
    if (keyCode === 2045 || keyCode === 2046) {
      return VK_MENU;
    }
    if (keyCode === 2047 || keyCode === 2048) {
      return VK_SHIFT;
    }
    if (keyCode === 2072 || keyCode === 2073) {
      return VK_CONTROL;
    }
    if (keyCode === 2049) {
      return VK_TAB;
    }
    if (keyCode === 2050) {
      return VK_SPACE;
    }
    if (keyCode === 2055) {
      return VK_BACK;
    }
    if (keyCode === 2070) {
      return VK_ESCAPE;
    }
    return 0;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      XComponent({
        id: 'krkr_surface',
        type: XComponentType.SURFACE,
        libraryname: 'krkrsdl3',
        controller: this.xComponentController
      })
        .width('100%')
        .height('100%')
        .onLoad(() => {
          try {
            krkr.setSurface(this.xComponentController.getXComponentSurfaceId());
          } catch (err) {
            hilog.error(DOMAIN, TAG, 'setSurface failed: %{public}s', JSON.stringify(err));
          }
        })
        .onAreaChange((oldArea: Area, newArea: Area) => {
          const widthVP = Number(newArea.width);
          const heightVP = Number(newArea.height);
          const widthPx = Math.round(widthVP * this.density);
          const heightPx = Math.round(heightVP * this.density);
          if (widthPx > 0 && heightPx > 0) {
            this.winWidthPx = widthPx;
            this.winHeightPx = heightPx;
            try {
              krkr.updateWindowSize(widthPx, heightPx);
            } catch (err) {
            }
          }
        })

      if (this.imeVisible) {
        this.imeOverlay()
      }

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
    .onTouch((event: TouchEvent) => {
      this.onGameTouch(event);
    })
    .onKeyEvent((event: KeyEvent) => {
      if (this.imeVisible || !this.engineInited) {
        return;
      }
      const vk = KirikiriPlayer.keyCodeToVk(event.keyCode);
      if (vk === 0) {
        return;
      }
      try {
        if (event.type === KeyType.Down) {
          krkr.sendKey(vk, true);
        } else if (event.type === KeyType.Up) {
          krkr.sendKey(vk, false);
        }
      } catch (err) {
      }
    })
    .parallelGesture(
      TapGesture({ count: 1, fingers: 3 })
        .onAction(() => {
          this.sidebarVisible = !this.sidebarVisible;
        })
    )
  }

  private onGameTouch(event: TouchEvent): void {
    if (this.sidebarVisible) {
      return;
    }
    if (event.type === TouchType.Down) {
      for (const ct of event.changedTouches) {
        this.activeFingers.set(ct.id, new FingerInfo(ct.x, ct.y));
      }
      const count = this.activeFingers.size;
      if (count === 1) {
        this.touchState = TOUCH_SINGLE;
      } else if (count >= 2) {
        this.touchState = TOUCH_MULTI;
      }
      if (count >= 3) {
        this.activeFingers.clear();
        this.touchState = TOUCH_IDLE;
      }
      return;
    }
    if (event.type === TouchType.Up) {
      const savedState = this.touchState;
      let lastFinger: FingerInfo | undefined = undefined;
      let lastX = 0;
      let lastY = 0;
      for (const ct of event.changedTouches) {
        if (this.activeFingers.size === 1) {
          lastFinger = this.activeFingers.get(ct.id);
          lastX = ct.x;
          lastY = ct.y;
        }
        this.activeFingers.delete(ct.id);
      }
      if (lastFinger !== undefined) {
        const button = savedState === TOUCH_MULTI ? 2 : 1;
        if (!lastFinger.moved) {
          this.sendTouch(0, lastX, lastY, button);
        }
        this.sendTouch(1, lastX, lastY, button);
        this.touchState = TOUCH_IDLE;
      }
      return;
    }
    if (event.type === TouchType.Move) {
      if (this.touchState === TOUCH_SINGLE && this.activeFingers.size === 1) {
        const t = event.touches[0];
        const finger = this.activeFingers.get(t.id);
        if (finger !== undefined) {
          const dx = t.x - finger.startX;
          const dy = t.y - finger.startY;
          if (dx * dx + dy * dy > 64) {
            finger.moved = true;
          }
          this.sendTouch(2, t.x, t.y, 0);
        }
      }
    }
  }

  @Builder
  imeOverlay() {
    Column() {
      Row({ space: 8 }) {
        TextInput({ text: this.imeText })
          .layoutWeight(1)
          .height(40)
          .fontSize(15)
          .fontColor(AppTheme.textPrimary)
          .caretColor(AppTheme.primary())
          .backgroundColor('#F2FFFFFF')
          .borderRadius(8)
          .onChange((value: string) => {
            this.imeText = value;
          })
          .onSubmit(() => {
            this.commitImeText();
          })

        Text('退格')
          .fontSize(14)
          .fontColor(AppTheme.onPrimary)
          .padding({ left: 10, right: 10, top: 10, bottom: 10 })
          .onClick(() => {
            this.imeText = '';
            try {
              krkr.sendKey(VK_BACK, true);
              krkr.sendKey(VK_BACK, false);
            } catch (err) {
            }
          })

        Text('完成')
          .fontSize(14)
          .fontColor(AppTheme.onPrimary)
          .padding({ left: 10, right: 10, top: 10, bottom: 10 })
          .onClick(() => {
            this.commitImeText();
            this.imeVisible = false;
          })
      }
      .width('100%')
      .padding(10)
      .backgroundColor('#CC000000')
      .borderRadius(12)

      Text('输入完成后点「完成」提交给游戏')
        .fontSize(11)
        .fontColor(AppTheme.textTertiary)
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 4 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.End)
    .padding({ left: 12, right: 12, bottom: 16 })
  }
}
