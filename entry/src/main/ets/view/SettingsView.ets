import { picker } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppTheme } from '../common/Theme';
import { PageTopBar } from '../components/CommonWidgets';
import { GameFolderStore } from '../store/GameFolderStore';
import { LibraryStore } from '../store/LibraryStore';

const DOMAIN: number = 0x4D45;
const TAG: string = 'SettingsView';

@Component
export struct SettingsView {
  @StorageLink('gameFolders') gameFolders: string[] = [];
  @State busy: boolean = false;

  build() {
    Scroll() {
      Column({ space: 18 }) {
        PageTopBar({ title: '设置' })

        Column({ space: 10 }) {
          Text('游戏文件夹')
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.textPrimary)
          Text('添加目录后会递归扫描其中的 Artemis 游戏资源。')
            .fontSize(12)
            .fontColor(AppTheme.textSecondary)
          Button(this.busy ? '正在选择或扫描…' : '添加游戏文件夹')
            .width('100%')
            .height(44)
            .fontSize(14)
            .fontColor(AppTheme.onPrimary)
            .backgroundColor(AppTheme.primary)
            .borderRadius(22)
            .enabled(!this.busy)
            .onClick(() => {
              this.addGameFolder();
            })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppTheme.surface)
        .borderRadius(AppTheme.radiusL)

        if (this.gameFolders.length === 0) {
          Text('尚未添加游戏文件夹')
            .width('100%')
            .fontSize(13)
            .fontColor(AppTheme.textTertiary)
            .textAlign(TextAlign.Center)
            .padding({ top: 12, bottom: 12 })
        } else {
          Column({ space: 10 }) {
            ForEach(this.gameFolders, (folderPath: string) => {
              this.folderRow(folderPath)
            }, (folderPath: string) => folderPath)
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding({ left: AppTheme.pagePadding, right: AppTheme.pagePadding, bottom: 100 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }

  @Builder
  folderRow(folderPath: string) {
    Row({ space: 12 }) {
      Stack() {
        SymbolGlyph($r('sys.symbol.folder'))
          .fontSize(20)
          .fontColor([AppTheme.primary])
      }
      .width(42)
      .height(42)
      .backgroundColor(AppTheme.alpha(AppTheme.primary, '18'))
      .borderRadius(21)

      Column({ space: 4 }) {
        Text(GameFolderStore.displayName(folderPath))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(folderPath)
          .fontSize(10)
          .fontColor(AppTheme.textTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Column({ space: 8 }) {
        Text('扫描')
          .fontSize(12)
          .fontColor(AppTheme.primary)
          .onClick(() => {
            this.rescanFolder(folderPath);
          })
        Text('移除')
          .fontSize(12)
          .fontColor(AppTheme.danger)
          .onClick(() => {
            LibraryStore.removeFolder(folderPath);
          })
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.radiusM)
    .alignItems(VerticalAlign.Center)
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
          ? `文件夹已添加，扫描到 ${added} 个新游戏`
          : '文件夹已添加，没有发现新的游戏资源';
        this.getUIContext().getPromptAction().showToast({ message: message });
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'add folder failed: %{public}s', JSON.stringify(err));
      this.getUIContext().getPromptAction().showToast({ message: '添加或扫描文件夹失败' });
    } finally {
      this.busy = false;
    }
  }

  private async rescanFolder(folderPath: string): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    try {
      const added = await GameFolderStore.scan(folderPath);
      const message = added > 0 ? `扫描完成，新增 ${added} 个游戏` : '扫描完成，没有发现新游戏';
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'rescan folder failed: %{public}s', JSON.stringify(err));
      this.getUIContext().getPromptAction().showToast({ message: '扫描失败，请重新授权该文件夹' });
    } finally {
      this.busy = false;
    }
  }
}
