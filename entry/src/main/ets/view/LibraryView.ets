import { fileIo, fileUri, picker } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppTheme } from '../common/Theme';
import { Game } from '../model/Game';
import { EngineRegistry } from '../engine/EngineRegistry';
import { LibraryStore } from '../store/LibraryStore';
import { GameCard } from '../components/GameCard';
import { EmptyState, PageTopBar } from '../components/CommonWidgets';

const DOMAIN: number = 0x4D45;
const TAG: string = 'LibraryView';

@Component
export struct LibraryView {
  @StorageLink('games') games: Game[] = [];
  @State keyword: string = '';
  @State importing: boolean = false;
  onOpenGame: (game: Game) => void = () => {
  };

  build() {
    Column({ space: 14 }) {
      PageTopBar({ title: '游戏库' })

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
              .onClick(() => {
                this.keyword = '';
              })
          }
        }
      } else {
        Row() {
          Text('我的游戏')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textPrimary)
          Blank()
          Row({ space: 5 }) {
            SymbolGlyph($r('sys.symbol.plus'))
              .fontSize(14)
              .fontColor([AppTheme.primary])
            Text(this.importing ? '扫描中…' : '添加文件夹')
              .fontSize(12)
              .fontColor(AppTheme.primary)
          }
          .padding({ left: 10, right: 10, top: 7, bottom: 7 })
          .backgroundColor(AppTheme.alpha(AppTheme.primary, '14'))
          .borderRadius(16)
          .onClick(() => {
            this.pickFolder();
          })
        }
        .width('100%')

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
      top: 0,
      bottom: 84
    })
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
        await this.scanFolder(uris[0]);
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'pick canceled or failed: %{public}s', JSON.stringify(err));
      this.getUIContext().getPromptAction().showToast({ message: '文件夹选择或扫描失败，请检查访问权限' });
    } finally {
      this.importing = false;
    }
  }

  private async scanFolder(folderUri: string): Promise<void> {
    const selectedFolder = new fileUri.FileUri(folderUri);
    const rootPath = selectedFolder.path;
    const rootName = this.decodeFolderName(selectedFolder.name);
    const entries: string[] = await fileIo.listFileExt(rootPath, {
      recursion: true,
      listNum: 10000,
      fileFilter: {
        filter: (name: string): boolean => this.isSupportedGameResource(name)
      }
    });

    if (entries.length === 0) {
      this.getUIContext().getPromptAction().showToast({
        message: '未发现可识别的游戏资源（.pfs / .asb / .psb / .tjs）'
      });
      return;
    }

    const gameDirectories: string[] = [];
    const hasRootResource = entries.some((entry: string) => this.relativeDirectory(entry).length === 0);
    if (hasRootResource) {
      gameDirectories.push('');
    } else {
      entries.forEach((entry: string) => {
        const relativeDirectory = this.gameDirectoryForResource(entry);
        if (!gameDirectories.includes(relativeDirectory)) {
          gameDirectories.push(relativeDirectory);
        }
      });
    }

    let added = 0;
    gameDirectories.forEach((relativeDirectory: string) => {
      const gamePath = relativeDirectory.length > 0 ? `${rootPath}/${relativeDirectory}` : rootPath;
      const title = relativeDirectory.length > 0
        ? this.decodeFolderName(relativeDirectory.split('/').pop() ?? rootName)
        : rootName;
      const alreadyAdded = LibraryStore.list().some((game: Game) => game.path === gamePath);
      if (!alreadyAdded) {
        LibraryStore.add(LibraryStore.create(title, gamePath, EngineRegistry.find('artemis').id));
        added += 1;
      }
    });

    if (added > 0) {
      this.getUIContext().getPromptAction().showToast({ message: `扫描完成，添加了 ${added} 个游戏` });
    } else {
      this.getUIContext().getPromptAction().showToast({ message: '扫描完成，没有发现新的游戏' });
    }
  }

  private isSupportedGameResource(path: string): boolean {
    const lower = path.toLowerCase();
    return lower.endsWith('.pfs') || lower.endsWith('.asb') || lower.endsWith('.psb') || lower.endsWith('.tjs');
  }

  private relativeDirectory(entry: string): string {
    const normalized = entry.startsWith('/') ? entry.substring(1) : entry;
    const separator = normalized.lastIndexOf('/');
    return separator < 0 ? '' : normalized.substring(0, separator);
  }

  private gameDirectoryForResource(entry: string): string {
    const relativeDirectory = this.relativeDirectory(entry);
    const parts = relativeDirectory.split('/').filter((part: string) => part.length > 0);
    const resourceDirectories: string[] = [
      'data', 'resource', 'resources', 'asset', 'assets', 'script', 'scripts',
      'sound', 'sounds', 'voice', 'bg', 'cg', 'image', 'images', 'scenario', 'movie', 'video'
    ];
    while (parts.length > 0 && resourceDirectories.includes(parts[parts.length - 1].toLowerCase())) {
      parts.pop();
    }
    return parts.join('/');
  }

  private decodeFolderName(name: string): string {
    try {
      return decodeURIComponent(name);
    } catch (err) {
      return name;
    }
  }
}
