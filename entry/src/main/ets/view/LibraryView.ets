import { picker } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { router } from '@kit.ArkUI';
import { AppTheme } from '../common/Theme';
import { Game } from '../model/Game';
import { GameFolderStore } from '../store/GameFolderStore';
import { LibraryStore } from '../store/LibraryStore';
import { SettingsStore } from '../store/SettingsStore';
import { GameCard } from '../components/GameCard';
import { EmptyState, PageTopBar } from '../components/CommonWidgets';
import { EngineSettingsPanel } from '../components/EngineSettingsPanel';
import { RenameDialog } from '../components/RenameDialog';
import { SettingRow } from '../components/SettingRow';

const DOMAIN: number = 0x4D45;
const TAG: string = 'LibraryView';

class GameActionItem {
  icon: Resource;
  image: Resource | null;
  label: string;
  key: string;

  constructor(icon: Resource, label: string, key: string, image: Resource | null = null) {
    this.icon = icon;
    this.image = image;
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
  @State sheetMode: string = 'actions';
  @State renameText: string = '';
  @StorageLink('themePrimary') themePrimary: string = AppTheme.primaryDefault;
  private renameDialog: CustomDialogController = new CustomDialogController({
    builder: RenameDialog({
      name: $renameText,
      onConfirm: (name: string) => {
        return this.applyRename(name);
      }
    }),
    autoCancel: true,
    customStyle: true,
    alignment: DialogAlignment.Center
  });
  @State selectedGame: Game = Game.placeholder();
  private gameActions: GameActionItem[] = [
    new GameActionItem($r('sys.symbol.play_fill'), '启动游戏', 'launch'),
    new GameActionItem($r('sys.symbol.picture_and_pencil'), '修改封面', 'cover',
      $r('app.media.setting_scraper')),
    new GameActionItem($r('sys.symbol.gearshape'), '引擎设置', 'engine',
      $r('app.media.action_engine')),
    new GameActionItem($r('sys.symbol.rename'), '名称修改', 'rename',
      $r('app.media.action_rename')),
    new GameActionItem($r('sys.symbol.trash'), '删除游戏', 'delete',
      $r('app.media.action_delete'))
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
        .searchIcon({ color: this.themePrimary, size: 22 })
        .onChange((value: string) => {
          this.keyword = value;
        })

      if (this.filtered().length === 0) {
        if (this.games.length === 0) {
          Column() {
            Button(this.importing ? '正在扫描…' : '选择游戏文件夹')
              .fontSize(14)
              .fontColor(AppTheme.onPrimary)
              .backgroundColor(this.themePrimary)
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
                  this.sheetMode = 'actions';
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
    .bindSheet($$this.showGameSheet, this.sheetContent(), {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      preferType: SheetType.BOTTOM,
      dragBar: true,
      showClose: false,
      scrollSizeMode: ScrollSizeMode.CONTINUOUS
    })
  }

  @Builder
  sheetContent() {
    if (this.sheetMode === 'engine') {
      EngineSettingsPanel({
        engineId: this.selectedGame.engineId,
        gameId: this.selectedGame.id,
        showBack: true,
        onBack: () => {
          this.sheetMode = 'actions';
        }
      })
    } else {
      this.gameActionSheet()
    }
  }

  @Builder
  gameActionSheet() {
    Column() {
      List({ space: 8 }) {
        ForEach(this.gameActions, (action: GameActionItem) => {
          ListItem() {
            SettingRow({
              icon: action.icon,
              iconImage: action.image,
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
    if (key === 'engine') {
      this.sheetMode = 'engine';
      return;
    }
    if (key === 'rename') {
      this.renameText = this.selectedGame.title;
      this.showGameSheet = false;
      this.renameDialog.open();
      return;
    }
    if (key === 'delete') {
      this.confirmDelete();
      return;
    }
    if (key === 'cover') {
      this.showGameSheet = false;
      this.pickCover();
      return;
    }
    if (key === 'launch') {
      const engineId = this.selectedGame.engineId;
      const webEngines: string[] = ['tyrano', 'rpgm_mv', 'rpgm_mz', 'webother'];
      if (engineId !== 'artemis' && !webEngines.includes(engineId)) {
        this.getUIContext().getPromptAction().showToast({
          message: '该引擎运行时尚在规划中，暂不支持启动'
        });
        return;
      }
      this.showGameSheet = false;
      AppStorage.setOrCreate<string>('playerGameId', this.selectedGame.id);
      const url = webEngines.includes(engineId) ? 'pages/WebPlayer' : 'pages/Player';
      router.pushUrl({ url: url }).catch((err: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'open player failed: %{public}s', JSON.stringify(err));
      });
    }
  }

  private applyRename(input: string): boolean {
    const name = input.trim();
    if (name.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '名称不能为空' });
      return false;
    }
    const game = this.selectedGame;
    if (name === game.title) {
      return true;
    }
    LibraryStore.rename(game, name);
    this.getUIContext().getPromptAction().showToast({ message: '名称已修改' });
    return true;
  }

  private confirmDelete(): void {
    const game = this.selectedGame;
    this.getUIContext().showAlertDialog({
      title: '删除游戏',
      message: `仅从游戏仓库移除「${game.title}」，不会删除游戏目录、封面或存档文件。`,
      autoCancel: true,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: AppTheme.danger,
        action: () => {
          LibraryStore.remove(game.id);
          SettingsStore.removeGameEngineConfig(game.id);
          this.showGameSheet = false;
          this.getUIContext().getPromptAction().showToast({ message: '已从游戏仓库移除' });
        }
      }
    });
  }

  private async pickCover(): Promise<void> {
    try {
      const picker = new photoAccessHelper.PhotoViewPicker();
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const result = await picker.select(options);
      if (result.photoUris.length === 0) {
        return;
      }
      AppStorage.setOrCreate<string>('coverCropUri', result.photoUris[0]);
      AppStorage.setOrCreate<string>('coverCropGameId', this.selectedGame.id);
      router.pushUrl({ url: 'pages/CoverCrop' }).catch((err: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'open cover crop failed: %{public}s', JSON.stringify(err));
      });
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'pick cover canceled or failed: %{public}s', JSON.stringify(err));
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
