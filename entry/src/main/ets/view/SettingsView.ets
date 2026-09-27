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
  image: Resource;
  label: string;
  key: string;

  constructor(image: Resource, label: string, key: string) {
    this.image = image;
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
  @StorageLink('themePrimary') themePrimary: string = AppTheme.primaryDefault;
  @State activeSheet: string = '';
  @State wheelHue: number = 197;
  @State wheelBrightness: number = 85;
  private wheelSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private wheelCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.wheelSettings);
  @State scraping: boolean = false;
  @State scrapeDone: number = 0;
  @State scrapeTotal: number = 0;
  @State scrapeCurrent: string = '';
  private settings: SettingItem[] = [
    new SettingItem($r('app.media.setting_folder'), '游戏目录', 'folders'),
    new SettingItem($r('app.media.setting_scraper'), '封面刮削', 'scraper'),
    new SettingItem($r('app.media.setting_appearance'), '外观设置', 'appearance'),
    new SettingItem($r('app.media.setting_application'), '应用设置', 'application')
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
              iconImage: item.image,
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
    } else if (this.activeSheet === 'appearance') {
      this.appearanceSheet()
    } else if (this.activeSheet === 'wheel') {
      this.wheelSheet()
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
              .selectedColor(this.themePrimary)
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
              .selectedColor(this.themePrimary)
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
              .selectedColor(this.themePrimary)
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
              .selectedColor(this.themePrimary)
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
                  .fontColor([this.themePrimary])
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
                .color(this.themePrimary)
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
          .backgroundColor(this.themePrimary)
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
    if (key === 'appearance') {
      this.activeSheet = 'appearance';
      this.showSheet = true;
    }
  }

  @Builder
  appearanceSheet() {
    Column() {
      List({ space: 8 }) {
        ListItem() {
          Row({ space: 10 }) {
            Text('主题色')
              .fontSize(16)
              .fontColor(AppTheme.textPrimary)
              .layoutWeight(1)
            Text(this.themePrimary.toUpperCase())
              .fontSize(14)
              .fontColor(AppTheme.textSecondary)
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(18)
              .fontColor([AppTheme.textTertiary])
          }
          .width('100%')
          .height(56)
          .padding({ left: AppTheme.pagePadding, right: AppTheme.pagePadding })
          .backgroundColor(AppTheme.surface)
          .borderRadius(AppTheme.radiusM)
          .clickEffect(null)
          .hoverEffect(HoverEffect.None)
          .onClick(() => {
            this.syncWheelFromTheme();
            this.activeSheet = 'wheel';
          })
        }

        ListItem() {
          Text('请选择有彩度的颜色；透明、黑、白、灰不适用为主题色。')
            .fontSize(12)
            .fontColor(AppTheme.textTertiary)
            .width('100%')
            .padding({ left: AppTheme.pagePadding, right: AppTheme.pagePadding, top: 4 })
        }
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

  @Builder
  wheelSheet() {
    Column({ space: 12 }) {
      List({ space: 8 }) {
        ListItem() {
          Column({ space: 14 }) {
            Text('色调轮盘')
              .fontSize(16)
              .fontColor(AppTheme.textPrimary)
              .width('100%')

            Stack() {
              Canvas(this.wheelCtx)
                .width(200)
                .height(200)
                .onReady(() => {
                  this.drawWheel();
                })
                .onTouch((event: TouchEvent) => {
                  const touch = event.touches.length > 0 ? event.touches[0] : null;
                  if (touch === null) {
                    return;
                  }
                  if (event.type === TouchType.Down || event.type === TouchType.Move) {
                    this.pickFromWheel(touch.x, touch.y);
                  }
                })
            }
            .width('100%')

            Row({ space: 12 }) {
              Column()
                .width(28)
                .height(28)
                .borderRadius(14)
                .backgroundColor(this.themePrimary)
              Text(this.themePrimary.toUpperCase())
                .fontSize(14)
                .fontColor(AppTheme.textSecondary)
                .layoutWeight(1)
            }
            .width('100%')

            Row({ space: 12 }) {
              Text('明度')
                .fontSize(14)
                .fontColor(AppTheme.textPrimary)
              Slider({ value: this.wheelBrightness, min: 25, max: 100, step: 1 })
                .layoutWeight(1)
                .selectedColor(this.themePrimary)
                .onChange((value: number) => {
                  this.wheelBrightness = value;
                  this.applyWheelColor();
                })
              Text(`${Math.round(this.wheelBrightness)}%`)
                .fontSize(13)
                .fontColor(AppTheme.textSecondary)
                .width(46)
                .textAlign(TextAlign.End)
            }
            .width('100%')
          }
          .width('100%')
          .padding(AppTheme.pagePadding)
          .backgroundColor(AppTheme.surface)
          .borderRadius(AppTheme.radiusM)
          .alignItems(HorizontalAlign.Start)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: AppTheme.pagePadding, right: AppTheme.pagePadding })
      .scrollBar(BarState.Off)

      Row({ space: 12 }) {
        Button('恢复默认')
          .layoutWeight(1)
          .height(44)
          .fontSize(14)
          .fontColor(AppTheme.textPrimary)
          .backgroundColor(AppTheme.surfaceAlt)
          .borderRadius(22)
          .stateEffect(false)
          .onClick(() => {
            SettingsStore.setThemeColor(AppTheme.primaryDefault);
            this.syncWheelFromTheme();
          })
        Button('完成')
          .layoutWeight(1)
          .height(44)
          .fontSize(14)
          .fontColor(AppTheme.onPrimary)
          .backgroundColor(this.themePrimary)
          .borderRadius(22)
          .stateEffect(false)
          .onClick(() => {
            this.activeSheet = 'appearance';
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

  private syncWheelFromTheme(): void {
    const rgb = SettingsView.parseHexColor(this.themePrimary);
    if (rgb === null) {
      return;
    }
    const r = rgb[0];
    const g = rgb[1];
    const b = rgb[2];
    const max = Math.max(r, Math.max(g, b));
    const min = Math.min(r, Math.min(g, b));
    const delta = max - min;
    let hue = 0;
    if (delta > 0) {
      if (max === r) {
        hue = 60 * (((g - b) / delta) % 6);
      } else if (max === g) {
        hue = 60 * ((b - r) / delta + 2);
      } else {
        hue = 60 * ((r - g) / delta + 4);
      }
    }
    if (hue < 0) {
      hue += 360;
    }
    this.wheelHue = hue;
    this.wheelBrightness = Math.round(max * 100 / 255);
  }

  private drawWheel(): void {
    const ctx = this.wheelCtx;
    const size = 200;
    const center = size / 2;
    const outer = 94;
    const inner = 56;
    ctx.clearRect(0, 0, size, size);
    const segments = 144;
    for (let index = 0; index < segments; index++) {
      const startAngle = (index / segments) * Math.PI * 2;
      const endAngle = ((index + 1) / segments) * Math.PI * 2 + 0.03;
      const hue = index * 360 / segments;
      const color = SettingsView.hsvToHex(hue, 0.92, 0.95);
      ctx.beginPath();
      ctx.arc(center, center, (outer + inner) / 2, startAngle, endAngle);
      ctx.lineWidth = outer - inner;
      ctx.strokeStyle = color;
      ctx.stroke();
    }
    ctx.beginPath();
    ctx.arc(center, center, inner - 4, 0, Math.PI * 2);
    ctx.fillStyle = '#FFFFFF';
    ctx.fill();
  }

  private pickFromWheel(x: number, y: number): void {
    const center = 100;
    const dx = x - center;
    const dy = y - center;
    const distance = Math.sqrt(dx * dx + dy * dy);
    if (distance < 56 || distance > 97) {
      return;
    }
    let angle = Math.atan2(dy, dx) * 180 / Math.PI;
    if (angle < 0) {
      angle += 360;
    }
    this.wheelHue = angle;
    this.applyWheelColor();
  }

  private applyWheelColor(): void {
    const value = Math.max(0.25, this.wheelBrightness / 100);
    const color = SettingsView.hsvToHex(this.wheelHue, 0.92, value);
    this.applyThemeColor(color);
  }

  private static parseHexColor(color: string): number[] | null {
    const hex = color.startsWith('#') ? color.substring(1) : color;
    const rgb = hex.length === 8 ? hex.substring(2) : hex;
    if (rgb.length !== 6) {
      return null;
    }
    const r = parseInt(rgb.substring(0, 2), 16);
    const g = parseInt(rgb.substring(2, 4), 16);
    const b = parseInt(rgb.substring(4, 6), 16);
    if (isNaN(r) || isNaN(g) || isNaN(b)) {
      return null;
    }
    return [r, g, b];
  }

  private static hsvToHex(hue: number, saturation: number, value: number): string {
    const c = value * saturation;
    const hh = hue / 60;
    const x = c * (1 - Math.abs(hh % 2 - 1));
    let r = 0;
    let g = 0;
    let b = 0;
    if (hh < 1) {
      r = c;
      g = x;
    } else if (hh < 2) {
      r = x;
      g = c;
    } else if (hh < 3) {
      g = c;
      b = x;
    } else if (hh < 4) {
      g = x;
      b = c;
    } else if (hh < 5) {
      r = x;
      b = c;
    } else {
      r = c;
      b = x;
    }
    const m = value - c;
    return `#FF${SettingsView.channelHex(r + m)}${SettingsView.channelHex(g + m)}${SettingsView.channelHex(b + m)}`.toUpperCase();
  }

  private static channelHex(value: number): string {
    let channel = Math.round(value * 255);
    if (channel < 0) {
      channel = 0;
    }
    if (channel > 255) {
      channel = 255;
    }
    return channel < 16 ? `0${channel.toString(16)}` : channel.toString(16);
  }

  private applyThemeColor(color: string): void {
    if (!SettingsView.isValidThemeColor(color)) {
      this.getUIContext().getPromptAction().showToast({
        message: '请选择有彩度的颜色（不要透明、黑、白、灰）'
      });
      return;
    }
    SettingsStore.setThemeColor(color);
  }

  private static isValidThemeColor(color: string): boolean {
    const hex = color.startsWith('#') ? color.substring(1) : color;
    if (hex.length !== 6 && hex.length !== 8) {
      return false;
    }
    if (hex.length === 8 && hex.substring(0, 2).toLowerCase() !== 'ff') {
      return false;
    }
    const rgb = hex.length === 8 ? hex.substring(2) : hex;
    const r = parseInt(rgb.substring(0, 2), 16);
    const g = parseInt(rgb.substring(2, 4), 16);
    const b = parseInt(rgb.substring(4, 6), 16);
    if (isNaN(r) || isNaN(g) || isNaN(b)) {
      return false;
    }
    const max = Math.max(r, Math.max(g, b));
    const min = Math.min(r, Math.min(g, b));
    const chroma = max - min;
    if (chroma < 40 || max < 60 || min > 225) {
      return false;
    }
    return true;
  }

  @Builder
  folderSheet() {
    Column({ space: 16 }) {
      if (this.gameFolders.length === 0) {
        Column({ space: 10 }) {
          Stack() {
            SymbolGlyph($r('sys.symbol.folder'))
              .fontSize(30)
              .fontColor([this.themePrimary])
          }
          .width(72)
          .height(72)
          .backgroundColor(AppTheme.alpha(this.themePrimary, '1F'))
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
          .backgroundColor(this.themePrimary)
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
