import { picker } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppTheme } from '../common/Theme';
import { Format } from '../common/Format';
import { Game } from '../model/Game';
import { EngineCore } from '../model/Engine';
import { EngineRegistry } from '../engine/EngineRegistry';
import { LibraryStore } from '../store/LibraryStore';
import { GameCard } from '../components/GameCard';
import { EmptyState, IconActionButton, PageHeader } from '../components/CommonWidgets';

const DOMAIN: number = 0x4D45;
const TAG: string = 'LibraryView';

@Component
export struct LibraryView {
  @StorageLink('games') games: Game[] = [];
  @StorageLink('stg_autoCore') autoCore: boolean = true;
  @StorageLink('stg_defaultCore') defaultCore: string = 'artemis';
  @State keyword: string = '';
  @State importing: boolean = false;
  onOpenGame: (game: Game) => void = () => {
  };

  build() {
    Column({ space: 14 }) {
      PageHeader({ title: '游戏库', subtitle: this.headerSubtitle() }) {
        Row() {
          IconActionButton({
            icon: $r('sys.symbol.square_and_arrow_down'),
            color: '#062033',
            bg: AppTheme.primary,
            onTap: () => {
              this.pickFiles();
            }
          })
        }
        .bindMenu(this.importMenu)
      }

      Row({ space: 10 }) {
        this.statCard('收录游戏', `${this.games.length}`, AppTheme.primary)
        this.statCard('内核总数', `${EngineRegistry.all().length}`, AppTheme.accent)
        this.statCard('已接入', `${EngineRegistry.readyCount()}`, AppTheme.success)
      }
      .width('100%')

      Search({ value: this.keyword, placeholder: '搜索游戏名称' })
        .height(40)
        .width('100%')
        .backgroundColor(AppTheme.surface)
        .placeholderColor(AppTheme.textTertiary)
        .textFont({ size: 14 })
        .fontColor(AppTheme.textPrimary)
        .searchIcon({ color: AppTheme.textSecondary })
        .onChange((value: string) => {
          this.keyword = value;
        })

      if (this.filtered().length === 0) {
        EmptyState({
          icon: this.games.length === 0 ? $r('sys.symbol.gamecontroller') : $r('sys.symbol.magnifyingglass'),
          title: this.games.length === 0 ? '游戏库还是空的' : '没有找到匹配的游戏',
          desc: this.games.length === 0
            ? '导入 Artemis 等内核支持的本地游戏包，即可在内核管理页查看接入进度。'
            : '换个关键词试试，或清空搜索条件。'
        }) {
          if (this.games.length === 0) {
            Button('导入游戏')
              .fontSize(14)
              .fontColor('#062033')
              .backgroundColor(AppTheme.primary)
              .borderRadius(20)
              .height(40)
              .padding({ left: 22, right: 22 })
              .onClick(() => {
                this.pickFiles();
              })
          } else {
            Button('清空搜索')
              .fontSize(14)
              .fontColor(AppTheme.textPrimary)
              .backgroundColor(AppTheme.surfaceAlt)
              .borderRadius(20)
              .height(40)
              .padding({ left: 22, right: 22 })
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
                onOpen: (target: Game) => {
                  this.onOpenGame(target);
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
      }
    }
    .width('100%')
    .height('100%')
    .padding({
      left: AppTheme.pagePadding,
      right: AppTheme.pagePadding,
      top: AppTheme.pagePadding,
      bottom: 84
    })
    .backgroundColor(AppTheme.bg)
  }

  @Builder
  importMenu() {
    Menu() {
      MenuItem({ content: '导入游戏文件（zip / pfs / apk）' })
        .onClick(() => {
          this.pickFiles();
        })
      MenuItem({ content: '导入游戏文件夹' })
        .onClick(() => {
          this.pickFolder();
        })
    }
  }

  @Builder
  statCard(label: string, value: string, color: string) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(label)
        .fontSize(11)
        .fontColor(AppTheme.textTertiary)
    }
    .layoutWeight(1)
    .padding({ top: 12, bottom: 12 })
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.radiusM)
    .border({ width: 1, color: AppTheme.border })
  }

  private headerSubtitle(): string {
    const installed = EngineRegistry.installed().length;
    return `已收录 ${this.games.length} 个游戏 · ${installed} 个已安装内核`;
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

  private async pickFiles(): Promise<void> {
    await this.pick(picker.DocumentSelectMode.FILE);
  }

  private async pickFolder(): Promise<void> {
    await this.pick(picker.DocumentSelectMode.FOLDER);
  }

  private async pick(mode: picker.DocumentSelectMode): Promise<void> {
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
      options.maxSelectNumber = 9;
      options.selectMode = mode;
      if (mode === picker.DocumentSelectMode.FILE) {
        options.fileSuffixFilters = ['游戏包(.zip, .7z, .apk, .pfs)|.zip,.7z,.apk,.pfs', '全部文件|.*'];
      }
      const uris: string[] = await documentPicker.select(options);
      this.ingest(uris);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'pick canceled or failed: %{public}s', JSON.stringify(err));
    } finally {
      this.importing = false;
    }
  }

  private ingest(uris: string[]): void {
    if (uris.length === 0) {
      return;
    }
    uris.forEach((uri: string) => {
      const title = Format.fileTitle(uri);
      const core: EngineCore = this.autoCore ? EngineRegistry.detect(title) : EngineRegistry.find(this.defaultCore);
      LibraryStore.add(LibraryStore.create(title, uri, core.id));
    });
    this.getUIContext().getPromptAction().showToast({ message: `已导入 ${uris.length} 个条目` });
  }
}
