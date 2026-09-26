import { AppTheme } from '../common/Theme';

@Component
export struct SettingRow {
  icon: Resource = $r('sys.symbol.folder');
  showIcon: boolean = true;
  title: string = '';
  detail: string = '';
  arrow: boolean = false;
  radius: number = AppTheme.radiusL;
  onTap: () => void = () => {
  };

  @Builder
  emptySuffix() {
  }

  @BuilderParam suffix: () => void = this.emptySuffix;

  build() {
    Row({ space: 12 }) {
      if (this.showIcon) {
        SymbolGlyph(this.icon)
          .fontSize(24)
          .fontColor([AppTheme.primary])
      }

      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(16)
          .fontColor(AppTheme.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (this.detail.length > 0) {
          Text(this.detail)
            .fontSize(14)
            .fontColor(AppTheme.textTertiary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.arrow) {
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(20)
          .fontColor([AppTheme.primary])
      }

      this.suffix()
    }
    .width('100%')
    .constraintSize({ minHeight: 56 })
    .padding({
      left: AppTheme.pagePadding,
      right: AppTheme.pagePadding,
      top: 14,
      bottom: 14
    })
    .backgroundColor(AppTheme.surface)
    .borderRadius(this.radius)
    .onClick(() => {
      this.onTap();
    })
    .clickEffect(null)
    .hoverEffect(HoverEffect.None)
  }
}
