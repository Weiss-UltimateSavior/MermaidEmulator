import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppTheme } from '../common/Theme';
import { Game } from '../model/Game';
import { EngineCore } from '../model/Engine';
import { LibraryStore } from '../store/LibraryStore';
import { SettingsStore } from '../store/SettingsStore';
import { LibraryView } from '../view/LibraryView';
import { KernelView } from '../view/KernelView';
import { SettingsView } from '../view/SettingsView';
import { GameDetailPage } from '../view/GameDetailPage';
import { KernelDetailPage } from '../view/KernelDetailPage';
import { PlayerPage } from '../view/PlayerPage';

const DOMAIN: number = 0x4D45;
const TAG: string = 'Index';

@Entry
@Component
struct Index {
  private pathStack: NavPathStack = new NavPathStack();
  private tabsController: TabsController = new TabsController();
  private mainWindow: window.Window | null = null;
  private avoidCallback: ((data: window.AvoidAreaOptions) => void) | null = null;
  @State currentTab: number = 0;
  @State barWidth: number = 0;
  @State safeBottom: number = 0;

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      LibraryStore.init(context);
      SettingsStore.init(context);
    }
    this.setupSafeArea();
  }

  aboutToDisappear(): void {
    if (this.mainWindow !== null && this.avoidCallback !== null) {
      this.mainWindow.off('avoidAreaChange', this.avoidCallback);
      this.avoidCallback = null;
    }
  }

  private setupSafeArea(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    window.getLastWindow(context).then((win: window.Window) => {
      this.mainWindow = win;
      this.refreshSafeArea(win);
      this.avoidCallback = (data: window.AvoidAreaOptions) => {
        this.refreshSafeArea(win);
      };
      win.on('avoidAreaChange', this.avoidCallback);
    }).catch((err: BusinessError) => {
      hilog.warn(DOMAIN, TAG, 'get last window failed: %{public}s', JSON.stringify(err));
    });
  }

  private refreshSafeArea(win: window.Window): void {
    const area = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
    this.safeBottom = this.getUIContext().px2vp(area.bottomRect.height);
  }

  @Builder
  PageMap(name: string) {
    if (name === 'GameDetail') {
      GameDetailPage()
    } else if (name === 'KernelDetail') {
      KernelDetailPage()
    } else if (name === 'Player') {
      PlayerPage()
    }
  }

  build() {
    Navigation(this.pathStack) {
      Stack({ alignContent: Alignment.Bottom }) {
        Tabs({ barPosition: BarPosition.End, index: this.currentTab, controller: this.tabsController }) {
          TabContent() {
            LibraryView({
              onOpenGame: (game: Game) => {
                this.openGame(game);
              }
            })
          }

          TabContent() {
            KernelView({
              onOpenKernel: (core: EngineCore) => {
                this.openKernel(core);
              }
            })
          }

          TabContent() {
            SettingsView()
          }
        }
        .barHeight(0)
        .scrollable(true)
        .animationDuration(240)
        .onChange((index: number) => {
          this.currentTab = index;
        })
        .width('100%')
        .height('100%')

        this.GlassTabBar()
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .hideToolBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.PageMap)
    .backgroundColor(AppTheme.bg)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  @Builder
  GlassTabBar() {
    Column() {
      Stack({ alignContent: Alignment.Start }) {
        Column()
          .width(this.barWidth > 0 ? this.barWidth / 3 - 12 : 0)
          .height(46)
          .borderRadius(23)
          .backgroundColor('#2EFFFFFF')
          .border({ width: 1, color: '#40FFFFFF' })
          .margin({ left: 6 })
          .offset({ x: this.currentTab * (this.barWidth / 3) })
          .animation({ duration: 280, curve: Curve.FastOutSlowIn })

        Row() {
          this.GlassTabItem(0, $r('sys.symbol.square_grid_2x2'), '游戏库')
          this.GlassTabItem(1, $r('sys.symbol.gamecontroller'), '内核')
          this.GlassTabItem(2, $r('sys.symbol.gearshape'), '设置')
        }
        .width('100%')
        .height(58)
      }
      .width('100%')
      .height(58)
      .borderRadius(29)
      .backgroundColor('#1AFFFFFF')
      .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK, {
        colorMode: ThemeColorMode.DARK,
        adaptiveColor: AdaptiveColor.DEFAULT,
        scale: 1.0
      })
      .border({ width: 1, color: '#33FFFFFF' })
      .shadow({ radius: 22, color: '#8C000000', offsetX: 0, offsetY: 8 })
      .clip(true)
      .onAreaChange((oldValue: Area, newValue: Area) => {
        this.barWidth = newValue.width as number;
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 14 + this.safeBottom })
    .hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder
  GlassTabItem(index: number, icon: Resource, label: string) {
    Column({ space: 3 }) {
      SymbolGlyph(icon)
        .fontSize(21)
        .fontColor([this.currentTab === index ? AppTheme.primary : AppTheme.textTertiary])
      Text(label)
        .fontSize(10)
        .fontColor(this.currentTab === index ? AppTheme.primary : AppTheme.textTertiary)
    }
    .justifyContent(FlexAlign.Center)
    .height(58)
    .layoutWeight(1)
    .onClick(() => {
      this.currentTab = index;
      this.tabsController.changeIndex(index);
    })
  }

  private openGame(game: Game): void {
    this.pathStack.pushPath(new NavPathInfo('GameDetail', game));
  }

  private openKernel(core: EngineCore): void {
    this.pathStack.pushPath(new NavPathInfo('KernelDetail', core.id));
  }
}
