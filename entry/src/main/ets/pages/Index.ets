import { window } from '@kit.ArkUI';
import { HdsTabs, HdsTabsController, hdsMaterial } from '@kit.UIDesignKit';
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
import { AppBackground } from '../components/AppBackground';
import { GameDetailPage } from '../view/GameDetailPage';
import { KernelDetailPage } from '../view/KernelDetailPage';
import { PlayerPage } from '../view/PlayerPage';

const DOMAIN: number = 0x4D45;
const TAG: string = 'Index';

@Entry
@Component
struct Index {
  private pathStack: NavPathStack = new NavPathStack();
  private tabsController: HdsTabsController = new HdsTabsController();
  private mainWindow: window.Window | null = null;
  private avoidCallback: ((data: window.AvoidAreaOptions) => void) | null = null;
  @State currentTab: number = 0;
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
    const safeTop: number = this.getUIContext().px2vp(area.topRect.height);
    this.safeBottom = this.getUIContext().px2vp(area.bottomRect.height);
    AppStorage.setOrCreate<number>('safeTopVp', safeTop);
    AppStorage.setOrCreate<number>('safeBottomVp', this.safeBottom);
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
      Stack() {
        AppBackground()

        Column() {
          HdsTabs({ barPosition: BarPosition.End, index: this.currentTab, controller: this.tabsController }) {
          TabContent() {
            LibraryView({
              onOpenGame: (game: Game) => {
                this.openGame(game);
              }
            })
          }
          .tabBar(this.GlassTabItem(0, $r('sys.symbol.square_grid_2x2')))

          TabContent() {
            KernelView({
              onOpenKernel: (core: EngineCore) => {
                this.openKernel(core);
              }
            })
          }
          .tabBar(this.GlassTabItem(1, $r('sys.symbol.gamecontroller')))

          TabContent() {
            SettingsView()
          }
          .tabBar(this.GlassTabItem(2, $r('sys.symbol.gearshape')))
          }
          .vertical(false)
          .barPosition(BarPosition.End)
          .barOverlap(true)
          .scrollable(true)
          .animationDuration(240)
          .onChange((index: number) => {
            this.currentTab = index;
          })
          .barFloatingStyle({
            barWidth: {
              smallWidth: 310,
              mediumWidth: 380,
              largeWidth: 440
            },
            barSideMargin: 0,
            barBottomMargin: 14 + this.safeBottom,
            gradientMask: {
              maskColor: '#55CBD9F4',
              maskHeight: 92
            },
            lightColor: '#A6E9FF',
            systemMaterialEffect: {
              materialType: hdsMaterial.MaterialType.IMMERSIVE,
              materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
            }
          })
          .width('100%')
          .height('100%')
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    .hideTitleBar(true)
    .hideToolBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.PageMap)
    .backgroundColor('#CBD9F4')
  }

  @Builder
  GlassTabItem(index: number, icon: Resource) {
    Column() {
      SymbolGlyph(icon)
        .fontSize(24)
        .fontColor([this.currentTab === index ? AppTheme.primary : AppTheme.textSecondary])
    }
    .justifyContent(FlexAlign.Center)
    .height(48)
    .width('100%')
    .alignItems(HorizontalAlign.Center)
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
