import { AppTheme } from '../common/Theme';

@Component
export struct PageTopBar {
  title: string = '';
  @StorageLink('safeTopVp') safeTop: number = 0;

  build() {
    Column() {
      Blank().height(this.safeTop + AppTheme.pagePadding)
      Row() {
        Text(this.title)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height(48)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
  }
}

@Component
export struct EmptyState {
  icon: Resource = $r('sys.symbol.gamecontroller');
  title: string = '';
  desc: string = '';
  @StorageLink('themePrimary') themePrimary: string = AppTheme.primaryDefault;

  @Builder
  emptyAction() {
  }

  @BuilderParam action: () => void = this.emptyAction;

  build() {
    Column({ space: 12 }) {
      Stack() {
        SymbolGlyph(this.icon)
          .fontSize(30)
          .fontColor([this.themePrimary])
      }
      .width(72)
      .height(72)
      .backgroundColor(AppTheme.alpha(this.themePrimary, '1F'))
      .borderRadius(36)

      Text(this.title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.textPrimary)

      Text(this.desc)
        .fontSize(12)
        .fontColor(AppTheme.textTertiary)
        .textAlign(TextAlign.Center)
        .padding({ left: 24, right: 24 })

      this.action()
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }
}
