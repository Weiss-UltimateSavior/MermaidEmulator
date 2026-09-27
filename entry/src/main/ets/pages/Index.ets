import { window } from '@kit.ArkUI';
import { HdsTabs, HdsTabsController, hdsMaterial } from '@kit.UIDesignKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppTheme } from '../common/Theme';
import { GameFolderStore } from '../store/GameFolderStore';
import { LibraryStore } from '../store/LibraryStore';
import { SettingsStore } from '../store/SettingsStore';
import { LibraryView } from '../view/LibraryView';
import { KernelView } from '../view/KernelView';
import { SettingsView } from '../view/SettingsView';
import { AppBackground } from '../components/AppBackground';
import { GlassTabItem } from '../components/GlassTabItem';

const DOMAIN: number = 0x4D45;
const TAG: string = 'Index';

@Entry
@Component
struct Index {
  private tabsController: HdsTabsController = new HdsTabsController();
  private mainWindow: window.Window | null = null;
  private avoidCallback: ((data: window.AvoidAreaOptions) => void) | null = null;
  @State selectedTab: number = 0;
  @State safeBottom: number = 0;
  @StorageLink('themePrimary') themePrimary: string = AppTheme.primaryDefault;

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      LibraryStore.init(context);
      SettingsStore.init(context);
      GameFolderStore.activateAll(LibraryStore.folders()).catch((err: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'activate folders failed: %{public}s', JSON.stringify(err));
      });
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

  build() {
    Stack() {
      AppBackground()

      // 不传 index：避免组件重建/属性变化时按 index 回跳（ArkUI 规定改 index 无动画，
      // 且本运行时不支持 $$ 双向绑定）；当前页由 TabsController 管理，底栏高亮用 selectedTab
      HdsTabs({ barPosition: BarPosition.End, controller: this.tabsController }) {
        TabContent() {
          LibraryView()
        }
        .tabBar(this.bottomTab(0, $r('app.media.nav_game'), '游戏'))

        TabContent() {
          KernelView()
        }
        .tabBar(this.bottomTab(1, $r('app.media.nav_engine'), '引擎'))

        TabContent() {
          SettingsView()
        }
        .tabBar(this.bottomTab(2, $r('app.media.nav_settings'), '设置'))
      }
      .vertical(false)
      .barPosition(BarPosition.End)
      .barOverlap(true)
      .scrollable(true)
      .animationDuration(240)
      // 底栏高亮统一用 selectedTab 驱动（onSelected 在切换动画开始时触发，
      // onChange 兜底）：点击高亮在 switchTab 里立即更新，滑动由这两个回调同步
      .onSelected((index: number) => {
        this.selectedTab = index;
      })
      .onChange((index: number) => {
        this.selectedTab = index;
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
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .backgroundColor('#CBD9F4')
  }

  private switchTab(index: number): void {
    if (index === this.selectedTab) {
      return;
    }
    // 立即高亮；切换动画只经 TabsController.changeIndex（与滑动共用同一套
    // 左右平移动画）。直接改 index 会按 ArkUI 规则“无动画”瞬切，故不可先改。
    this.selectedTab = index;
    this.tabsController.changeIndex(index);
  }

  @Builder
  bottomTab(index: number, icon: Resource, label: string) {
    GlassTabItem({
      index: index,
      icon: icon,
      label: label,
      selected: this.selectedTab === index,
      onSelect: (target: number) => {
        this.switchTab(target);
      }
    })
  }

}
