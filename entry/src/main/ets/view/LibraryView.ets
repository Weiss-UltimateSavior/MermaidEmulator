import { picker } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { router } from '@kit.ArkUI';
import { AppTheme } from '../common/Theme';
import { Game } from '../model/Game';
import { GameFolderStore } from '../store/GameFolderStore';
import { GameCard } from '../components/GameCard';
import { EmptyState, PageTopBar } from '../components/CommonWidgets';
import { SettingRow } from '../components/SettingRow';

const DOMAIN: number = 0x4D45;
const TAG: string = 'LibraryView';

class GameActionItem {
  icon: Resource;
  label: string;
  key: string;

  constructor(icon: Resource, label: string, key: string) {
    this.icon = icon;
    this.label = label;
    this.key = key;
  }
}

@Component
export struct LibraryView {
  @StorageLink('games') games: Game[] = [];
  @State keyword: string = '';
  @State importing: boolean = false;
  @State showGameSheet: boolean = false;
  @State selectedGame: Game = Game.placeholder();
  private gameActions: GameActionItem[] = [
    new GameActionItem($r('sys.symbol.play_fill'), '启动游戏', 'launch'),
    new GameActionItem($r('sys.symbol.picture_and_pencil'), '修改封面', 'cover'),
    new GameActionItem($r('sys.symbol.gearshape'), '引擎设置', 'engine'),
    new GameActionItem($r('sys.symbol.rename'), '名称修改', 'rename'),
    new GameActionItem($r('sys.symbol.trash'), '删除游戏', 'delete')
  ];

  build() {
    Column({ space: AppTheme.topBarGap }) {
      PageTopBar({ title: '游戏仓库' })

      Search({ value: this.keyword })
        .height(50)
        .width('100%')
        .backgroundColor(AppTheme.surface)
        .textFont({ size: 16 })
        .fontColor(AppTheme.textPrimary)
        .searchIcon({ color: AppTheme.primary, size: 22 })
        .onChange((value: string) => {
          this.keyword = value;
        })

      if (this.filtered().length === 0) {
        if (this.games.length === 0) {
          Column() {
            Button(this.importing ? '正在扫描…' : '选择游戏文件夹')
              .fontSize(14)
              .fontColor(AppTheme.onPrimary)
              .backgroundColor(AppTheme.primary)
              .borderRadius(20)
              .height(40)
              .padding({ left: 22, right: 22 })
              .enabled(!this.importing)
              .stateEffect(false)
              .onClick(() => {
                this.pickFolder();
              })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          EmptyState({
            icon: $r('sys.symbol.magnifyingglass'),
            title: '没有找到匹配的游戏',
            desc: '换个关键词试试，或清空搜索条件。'
          }) {
            Button('清空搜索')
              .fontSize(14)
              .fontColor(AppTheme.textPrimary)
              .backgroundColor(AppTheme.surfaceAlt)
              .borderRadius(20)
              .height(40)
              .padding({ left: 22, right: 22 })
              .stateEffect(false)
              .onClick(() => {
                this.keyword = '';
              })
          }
        }
      } else {
        Grid() {
          ForEach(this.filtered(), (game: Game) => {
            GridItem() {
              GameCard({
                game: game,
                onTap: () => {
                  this.selectedGame = game;
                  this.showGameSheet = true;
                }
              })
            }
          }, (game: Game) => game.id)
        }
        .width('100%')
        .layoutWeight(1)
        .columnsTemplate('1fr 1fr')
        .columnsGap(12)
        .rowsGap(16)
        .scrollBar(BarState.Off)
        .contentEndOffset(84)
      }
    }
    .width('100%')
    .height('100%')
    .padding({
      left: AppTheme.pagePadding,
      right: AppTheme.pagePadding,
      top: 0
    })
    .bindSheet($$this.showGameSheet, this.gameActionSheet(), {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      preferType: SheetType.BOTTOM,
      dragBar: true,
      showClose: false,
      scrollSizeMode: ScrollSizeMode.CONTINUOUS
    })
  }

  @Builder
  gameActionSheet() {
    Column() {
      List({ space: 8 }) {
        ForEach(this.gameActions, (action: GameActionItem) => {
          ListItem() {
            SettingRow({
              icon: action.icon,
              title: action.label,
              radius: AppTheme.radiusM,
              onTap: () => {
                this.onGameAction(action.key);
              }
            })
          }
        }, (action: GameActionItem) => action.label)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: AppTheme.pagePadding, right: AppTheme.pagePadding })
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .padding({
      top: 20,
      bottom: 20
    })
  }

  private onGameAction(key: string): void {
    if (key === 'launch') {
      this.showGameSheet = false;
      AppStorage.setOrCreate<string>('playerGameId', this.selectedGame.id);
      router.pushUrl({ url: 'pages/Player' }).catch((err: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'open player failed: %{public}s', JSON.stringify(err));
      });
    }
  }

  private filtered(): Game[] {
    const keyword = this.keyword.trim().toLowerCase();
    const list = this.games.slice();
    list.sort((a: Game, b: Game) => b.importedAt - a.importedAt);
    if (keyword.length === 0) {
      return list;
    }
    return list.filter((game: Game) => game.title.toLowerCase().includes(keyword));
  }

  private async pickFolder(): Promise<void> {
    if (this.importing) {
      return;
    }
    this.importing = true;
    try {
      const context = this.getUIContext().getHostContext();
      if (context === undefined) {
        return;
      }
      const documentPicker = new picker.DocumentViewPicker(context);
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      options.selectMode = picker.DocumentSelectMode.FOLDER;
      const uris: string[] = await documentPicker.select(options);
      if (uris.length > 0) {
        const added = await GameFolderStore.addAndScan(uris[0]);
        const message = added > 0
          ? `扫描完成，添加了 ${added} 个游戏`
          : '文件夹已记录，没有发现新的游戏资源';
        this.getUIContext().getPromptAction().showToast({ message: message });
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'pick canceled or failed: %{public}s', JSON.stringify(err));
      this.getUIContext().getPromptAction().showToast({ message: '文件夹选择或扫描失败，请检查访问权限' });
    } finally {
      this.importing = false;
    }
  }
}
