import { AppTheme } from '../common/Theme';
import { EngineCore } from '../model/Engine';
import { StatusChip } from './CommonWidgets';

@Component
export struct KernelCard {
  core: EngineCore = new EngineCore();
  onOpen: (core: EngineCore) => void = () => {
  };

  build() {
    Row({ space: 12 }) {
      Stack() {
        SymbolGlyph($r('sys.symbol.gamecontroller'))
          .fontSize(22)
          .fontColor([this.core.accent])
      }
      .width(46)
      .height(46)
      .backgroundColor(AppTheme.alpha(this.core.accent, '22'))
      .borderRadius(14)

      Column({ space: 5 }) {
        Row({ space: 8 }) {
          Text(this.core.name)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textPrimary)
          StatusChip({ text: this.core.statusText(), color: this.core.statusColor() })
        }

        Text(`${this.core.vendor} · ${this.core.version}`)
          .fontSize(11)
          .fontColor(AppTheme.textTertiary)

        Row({ space: 6 }) {
          ForEach(this.core.extensions.slice(0, 4), (ext: string) => {
            Text(ext)
              .fontSize(10)
              .fontColor(AppTheme.textSecondary)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor(AppTheme.surfaceAlt)
              .borderRadius(6)
          }, (ext: string) => ext)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      SymbolGlyph($r('sys.symbol.chevron_forward'))
        .fontSize(14)
        .fontColor([AppTheme.textTertiary])
    }
    .width('100%')
    .padding(14)
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.radiusM)
    .border({ width: 1, color: AppTheme.border })
    .onClick(() => this.onOpen(this.core))
  }
}
