import { AppTheme } from '../common/Theme';

@Component
export struct SettingRow {
  icon: Resource = $r('sys.symbol.folder');
  iconImage: Resource | null = null;
  showIcon: boolean = true;
  @StorageLink('themePrimary') themePrimary: string = AppTheme.primaryDefault;
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
        if (this.iconImage !== null) {
          Image(this.iconImage)
            .width(24)
            .height(24)
            .objectFit(ImageFit.Contain)
            .colorFilter(this.themePrimary)
        } else {
          SymbolGlyph(this.icon)
            .fontSize(24)
            .fontColor([this.themePrimary])
        }
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
          .fontColor([this.themePrimary])
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
