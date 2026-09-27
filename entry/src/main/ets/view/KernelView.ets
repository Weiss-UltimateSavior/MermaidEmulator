import { AppTheme } from '../common/Theme';
import { EngineCore, EngineStatus } from '../model/Engine';
import { EngineRegistry } from '../engine/EngineRegistry';
import { EngineSettingsPanel } from '../components/EngineSettingsPanel';
import { PageTopBar } from '../components/CommonWidgets';
import { SettingRow } from '../components/SettingRow';

@Component
export struct KernelView {
  @State showEngineSheet: boolean = false;
  @State activeEngineId: string = 'artemis';
  @StorageLink('themePrimary') themePrimary: string = AppTheme.primaryDefault;
  private engines: EngineCore[] =
    EngineRegistry.all().filter((core: EngineCore) => core.status === EngineStatus.READY);

  build() {
    Column({ space: AppTheme.topBarGap }) {
      Column() {
        PageTopBar({ title: '引擎列表' })
      }
      .width('100%')
      .padding({ left: AppTheme.pagePadding, right: AppTheme.pagePadding })

      List({ space: 8 }) {
        ForEach(this.engines, (engine: EngineCore) => {
          ListItem() {
            SettingRow({
              iconImage: $r('app.media.engine_usb'),
              title: engine.name,
              onTap: () => {
                this.openEngineSheet(engine.id);
              }
            }) {
              if (engine.status === EngineStatus.READY) {
                SymbolGlyph($r('sys.symbol.checkmark'))
                  .fontSize(20)
                  .fontColor([this.themePrimary])
              } else {
                Text(engine.statusText())
                  .fontSize(14)
                  .fontColor(engine.statusColor())
              }
            }
          }
        }, (engine: EngineCore) => engine.id)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: AppTheme.pagePadding, right: AppTheme.pagePadding })
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .padding({ bottom: 84 })
    .bindSheet($$this.showEngineSheet, this.sheetContent(), {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      preferType: SheetType.BOTTOM,
      dragBar: true,
      showClose: false,
      scrollSizeMode: ScrollSizeMode.CONTINUOUS
    })
  }

  @Builder
  sheetContent() {
    EngineSettingsPanel({ engineId: this.activeEngineId })
  }

  private openEngineSheet(engineId: string): void {
    this.activeEngineId = engineId;
    this.showEngineSheet = true;
  }
}
