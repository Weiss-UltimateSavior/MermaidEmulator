import { picker } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppTheme } from '../common/Theme';
import { Game, GameFolder } from '../model/Game';
import { PageTopBar } from '../components/CommonWidgets';
import { SettingRow } from '../components/SettingRow';
import { GameFolderStore } from '../store/GameFolderStore';
import { LibraryStore } from '../store/LibraryStore';
import { SettingsStore } from '../store/SettingsStore';
import { CoverSources } from '../service/CoverSources';
import { CoverScraper, ScrapeSummary } from '../service/CoverScraper';

const DOMAIN: number = 0x4D45;
const TAG: string = 'SettingsView';

class SettingItem {
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
export struct SettingsView {
  @StorageLink('gameFolders') gameFolders: GameFolder[] = [];
  @StorageLink('games') games: Game[] = [];
  @StorageLink('stg_coverVndb') coverVndb: boolean = true;
  @StorageLink('stg_coverSteam') coverSteam: boolean = true;
  @StorageLink('stg_coverBangumi') coverBangumi: boolean = true;
  @StorageLink('stg_coverOnlyMissing') coverOnlyMissing: boolean = true;
  @State busy: boolean = false;
  @State showSheet: boolean = false;
  @State activeSheet: string = '';
  @State scraping: boolean = false;
  @State scrapeDone: number = 0;
  @State scrapeTotal: number = 0;
  @State scrapeCurrent: string = '';
  private settings: SettingItem[] = [
    new SettingItem($r('sys.symbol.folder'), '游戏目录', 'folders'),
    new SettingItem($r('sys.symbol.wand_and_stars'), '封面刮削', 'scraper'),
    new SettingItem($r('sys.symbol.paintpalette'), '外观设置', 'appearance'),
    new SettingItem($r('sys.symbol.gearshape'), '应用设置', 'application')
  ];

  build() {
    Column({ space: AppTheme.topBarGap }) {
      Column() {
        PageTopBar({ title: '参数设置' })
      }
      .width('100%')
      .padding({ left: AppTheme.pagePadding, right: AppTheme.pagePadding })

      List({ space: 8 }) {
        ForEach(this.settings, (item: SettingItem) => {
          ListItem() {
            SettingRow({
              icon: item.icon,
              title: item.label,
              arrow: true,
              onTap: () => {
                this.onSettingTap(item.key);
              }
            })
          }
        }, (item: SettingItem) => item.key)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: AppTheme.pagePadding, right: AppTheme.pagePadding })
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .padding({ bottom: 84 })
    .bindSheet($$this.showSheet, this.sheetContent(), {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      preferType: SheetType.BOTTOM,
      dragBar: true,
      showClose: false,
      scrollSizeMode: ScrollSizeMode.CONTINUOUS
    })
  }

  @Builder
  sheetContent() {
    if (this.activeSheet === 'scraper') {
      this.scraperSheet()
    } else {
      this.folderSheet()
    }
  }

  @Builder
  scraperSheet() {
    Column() {
      List({ space: 8 }) {
        ListItem() {
          SettingRow({
            icon: $r('sys.symbol.wand_and_stars'),
            title: 'VNDB',
            detail: '视觉小说数据库，优先匹配中文标题',
            radius: AppTheme.radiusM
          }) {
            Toggle({ type: ToggleType.Switch, isOn: this.coverVndb })
              .selectedColor(AppTheme.primary)
              .onChange((isOn: boolean) => {
                this.coverVndb = isOn;
                SettingsStore.persist();
              })
          }
        }

        ListItem() {
          SettingRow({
            icon: $r('sys.symbol.gamecontroller'),
            title: 'Steam',
            detail: 'Steam 商店封面，竖版库图',
            radius: AppTheme.radiusM
          }) {
            Toggle({ type: ToggleType.Switch, isOn: this.coverSteam })
              .selectedColor(AppTheme.primary)
              .onChange((isOn: boolean) => {
                this.coverSteam = isOn;
                SettingsStore.persist();
              })
          }
        }

        ListItem() {
          SettingRow({
            icon: $r('sys.symbol.play_fill'),
            title: 'Bangumi',
            detail: '番组计划条目封面',
            radius: AppTheme.radiusM
          }) {
            Toggle({ type: ToggleType.Switch, isOn: this.coverBangumi })
              .selectedColor(AppTheme.primary)
              .onChange((isOn: boolean) => {
                this.coverBangumi = isOn;
                SettingsStore.persist();
              })
          }
        }

        ListItem() {
          SettingRow({
            icon: $r('sys.symbol.bookmark'),
            title: '仅刮削缺失封面',
            detail: '已有封面的游戏将跳过',
            radius: AppTheme.radiusM
          }) {
            Toggle({ type: ToggleType.Switch, isOn: this.coverOnlyMissing })
              .selectedColor(AppTheme.primary)
              .onChange((isOn: boolean) => {
                this.coverOnlyMissing = isOn;
                SettingsStore.persist();
              })
          }
        }

        if (this.scraping || this.scrapeTotal > 0) {
          ListItem() {
            Column({ space: 10 }) {
              Row({ space: 12 }) {
                SymbolGlyph($r('sys.symbol.arrow_down_circle'))
                  .fontSize(24)
                  .fontColor([AppTheme.primary])
                Text(this.scraping ? '正在刮削封面' : '刮削完成')
                  .fontSize(16)
                  .fontColor(AppTheme.textPrimary)
                  .layoutWeight(1)
                Text(`${this.scrapePercent()}%`)
                  .fontSize(14)
                  .fontColor(AppTheme.textTertiary)
              }
              .width('100%')

              Progress({ value: this.scrapeDone, total: Math.max(this.scrapeTotal, 1), type: ProgressType.Linear })
                .width('100%')
                .style({ strokeWidth: 6 })
                .color(AppTheme.primary)
                .backgroundColor(AppTheme.surfaceAlt)
                .borderRadius(3)

              Text(this.scrapeStatusText())
                .fontSize(12)
                .fontColor(AppTheme.textTertiary)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
            }
            .width('100%')
            .padding({
              left: AppTheme.pagePadding,
              right: AppTheme.pagePadding,
              top: 12,
              bottom: 14
            })
            .backgroundColor(AppTheme.surface)
            .borderRadius(AppTheme.radiusM)
            .alignItems(HorizontalAlign.Start)
          }
        }
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: AppTheme.pagePadding, right: AppTheme.pagePadding })
      .scrollBar(BarState.Off)

      Column() {
        Button(this.scraping ? '正在刮削…' : '开始刮削')
          .width('100%')
          .height(44)
          .fontSize(14)
          .fontColor(AppTheme.onPrimary)
          .backgroundColor(AppTheme.primary)
          .borderRadius(22)
          .enabled(!this.scraping)
          .stateEffect(false)
          .onClick(() => {
            this.startScrape();
          })
      }
      .width('100%')
      .padding({
        left: AppTheme.pagePadding,
        right: AppTheme.pagePadding,
        top: 16
      })
    }
    .width('100%')
    .height('100%')
    .padding({
      top: 20,
      bottom: 20
    })
  }

  private scrapePercent(): number {
    if (this.scrapeTotal === 0) {
      return 0;
    }
    return Math.round(this.scrapeDone / this.scrapeTotal * 100);
  }

  private scrapeStatusText(): string {
    if (this.scraping && this.scrapeCurrent.length > 0) {
      return `正在处理：${this.scrapeCurrent}`;
    }
    if (this.scrapeTotal === 0) {
      return '选择封面源后开始刮削游戏库';
    }
    return `已处理 ${this.scrapeDone} / ${this.scrapeTotal} 个游戏`;
  }

  private enabledSources(): string[] {
    const sources: string[] = [];
    if (this.coverVndb) {
      sources.push(CoverSources.VNDB);
    }
    if (this.coverSteam) {
      sources.push(CoverSources.STEAM);
    }
    if (this.coverBangumi) {
      sources.push(CoverSources.BANGUMI);
    }
    return sources;
  }

  private async startScrape(): Promise<void> {
    if (this.scraping) {
      return;
    }
    const sources = this.enabledSources();
    if (sources.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '请至少启用一个封面源' });
      return;
    }
    if (this.games.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '游戏库为空，先添加游戏目录' });
      return;
    }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    this.scraping = true;
    this.scrapeDone = 0;
    this.scrapeTotal = 0;
    this.scrapeCurrent = '';
    try {
      const summary: ScrapeSummary = await CoverScraper.scrapeLibrary(
        this.games,
        sources,
        this.coverOnlyMissing,
        context.filesDir,
        (done: number, total: number, title: string) => {
          this.scrapeDone = done;
          this.scrapeTotal = total;
          this.scrapeCurrent = title;
        }
      );
      const message = summary.failed > 0
        ? `刮削完成：更新 ${summary.updated} 个，失败 ${summary.failed} 个`
        : `刮削完成：更新 ${summary.updated} 个封面`;
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'scrape failed: %{public}s', JSON.stringify(err));
      this.getUIContext().getPromptAction().showToast({ message: '刮削失败，请检查网络连接' });
    } finally {
      this.scraping = false;
    }
  }

  private onSettingTap(key: string): void {
    if (key === 'folders') {
      this.activeSheet = 'folders';
      this.showSheet = true;
    }
    if (key === 'scraper') {
      this.activeSheet = 'scraper';
      this.showSheet = true;
    }
  }

  @Builder
  folderSheet() {
    Column({ space: 16 }) {
      if (this.gameFolders.length === 0) {
        Column({ space: 10 }) {
          Stack() {
            SymbolGlyph($r('sys.symbol.folder'))
              .fontSize(30)
              .fontColor([AppTheme.primary])
          }
          .width(72)
          .height(72)
          .backgroundColor(AppTheme.alpha(AppTheme.primary, '1F'))
          .borderRadius(36)

          Text('还没有添加游戏目录')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textPrimary)

          Text('添加后会递归扫描其中的 Artemis 游戏资源，并把游戏加入游戏库。')
            .fontSize(12)
            .fontColor(AppTheme.textTertiary)
            .textAlign(TextAlign.Center)
            .padding({ left: 24, right: 24 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding({ left: AppTheme.pagePadding, right: AppTheme.pagePadding })
      } else {
        List({ space: 8 }) {
          ForEach(this.gameFolders, (folder: GameFolder) => {
            ListItem() {
              SettingRow({
                icon: $r('sys.symbol.folder'),
                title: GameFolderStore.displayName(folder.path),
                detail: this.folderDetail(folder.path),
                radius: AppTheme.radiusM,
                onTap: () => {
                  this.rescanFolder(folder);
                }
              }) {
                this.removeAction(folder)
              }
            }
          }, (folder: GameFolder) => folder.path)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: AppTheme.pagePadding, right: AppTheme.pagePadding })
        .scrollBar(BarState.Off)
      }

      Column() {
        Button(this.busy ? '正在处理…' : '添加游戏目录')
          .width('100%')
          .height(44)
          .fontSize(14)
          .fontColor(AppTheme.onPrimary)
          .backgroundColor(AppTheme.primary)
          .borderRadius(22)
          .enabled(!this.busy)
          .stateEffect(false)
          .onClick(() => {
            this.addGameFolder();
          })
      }
      .width('100%')
      .padding({ left: AppTheme.pagePadding, right: AppTheme.pagePadding })
    }
    .width('100%')
    .height('100%')
    .padding({
      top: 20,
      bottom: 20
    })
  }

  @Builder
  removeAction(folder: GameFolder) {
    Text('移除')
      .fontSize(14)
      .fontColor(AppTheme.danger)
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .onClick(() => {
        this.confirmRemove(folder);
      })
  }

  private folderDetail(folderPath: string): string {
    const count = this.games.filter((game: Game) =>
      game.path === folderPath || game.path.startsWith(`${folderPath}/`)).length;
    return count > 0 ? `${count} 个游戏 · 轻点重新扫描` : '轻点重新扫描';
  }

  private confirmRemove(folder: GameFolder): void {
    const name = GameFolderStore.displayName(folder.path);
    this.getUIContext().showAlertDialog({
      title: '移除游戏目录',
      message: `移除「${name}」后，已导入的游戏仍会保留，但不会再随该目录更新。`,
      autoCancel: true,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '移除',
        fontColor: AppTheme.danger,
        action: () => {
          GameFolderStore.release(folder);
          LibraryStore.removeFolder(folder.path);
          this.getUIContext().getPromptAction().showToast({ message: '已移除该目录' });
        }
      }
    });
  }

  private async addGameFolder(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
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
          ? `目录已添加，扫描到 ${added} 个新游戏`
          : '目录已添加，没有发现新的游戏资源';
        this.getUIContext().getPromptAction().showToast({ message: message });
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'add folder failed: %{public}s', JSON.stringify(err));
      this.getUIContext().getPromptAction().showToast({ message: '添加或扫描目录失败' });
    } finally {
      this.busy = false;
    }
  }

  private async rescanFolder(folder: GameFolder): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    try {
      await GameFolderStore.activate(folder);
      const added = await GameFolderStore.scan(folder.path);
      const message = added > 0 ? `扫描完成，新增 ${added} 个游戏` : '扫描完成，没有发现新游戏';
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'rescan folder failed: %{public}s', JSON.stringify(err));
      this.getUIContext().getPromptAction().showToast({ message: '扫描失败，请重新授权该目录' });
    } finally {
      this.busy = false;
    }
  }
}
