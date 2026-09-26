import { picker } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppTheme } from '../common/Theme';
import { Game } from '../model/Game';
import { GameFolderStore } from '../store/GameFolderStore';
import { GameCard } from '../components/GameCard';
import { EmptyState, PageTopBar } from '../components/CommonWidgets';

const DOMAIN: number = 0x4D45;
const TAG: string = 'LibraryView';

@Component
export struct LibraryView {
  @StorageLink('games') games: Game[] = [];
  @State keyword: string = '';
  @State importing: boolean = false;

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
        Grid() {
          ForEach(this.filtered(), (game: Game) => {
            GridItem() {
              GameCard({ game: game })
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
