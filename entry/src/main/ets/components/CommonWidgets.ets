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
export struct SectionCard {
  title: string = '';
  subtitle: string = '';

  @Builder
  emptyContent() {
  }

  @BuilderParam content: () => void = this.emptyContent;

  build() {
    Column({ space: 6 }) {
      if (this.title.length > 0) {
        Row() {
          Text(this.title)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textPrimary)
          Blank()
          if (this.subtitle.length > 0) {
            Text(this.subtitle)
              .fontSize(11)
              .fontColor(AppTheme.textTertiary)
          }
        }
        .width('100%')
        .padding({ bottom: 6 })
      }

      this.content()
    }
    .width('100%')
    .padding(14)
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.radiusM)
    .border({ width: 1, color: AppTheme.border })
  }
}

@Component
export struct SettingRow {
  icon: Resource = $r('sys.symbol.info_circle');
  label: string = '';
  value: string = '';
  hint: string = '';
  showArrow: boolean = false;
  onTap: () => void = () => {
  };

  @Builder
  emptyRight() {
  }

  @BuilderParam right: () => void = this.emptyRight;

  build() {
    Row({ space: 12 }) {
      Stack() {
        SymbolGlyph(this.icon)
          .fontSize(18)
          .fontColor([AppTheme.textSecondary])
      }
      .width(34)
      .height(34)
      .backgroundColor(AppTheme.surfaceAlt)
      .borderRadius(10)

      Column({ space: 3 }) {
        Text(this.label)
          .fontSize(14)
          .fontColor(AppTheme.textPrimary)
        if (this.hint.length > 0) {
          Text(this.hint)
            .fontSize(11)
            .fontColor(AppTheme.textTertiary)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      this.right()

      if (this.value.length > 0) {
        Text(this.value)
          .fontSize(13)
          .fontColor(AppTheme.textSecondary)
      }

      if (this.showArrow) {
        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize(14)
          .fontColor([AppTheme.textTertiary])
      }
    }
    .width('100%')
    .padding({ top: 9, bottom: 9 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => this.onTap())
  }
}

@Component
export struct StatusChip {
  text: string = '';
  color: string = AppTheme.textSecondary;

  build() {
    Text(this.text)
      .fontSize(11)
      .fontColor(this.color)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .backgroundColor(AppTheme.alpha(this.color, '26'))
      .borderRadius(8)
  }
}

@Component
export struct EmptyState {
  icon: Resource = $r('sys.symbol.gamecontroller');
  title: string = '';
  desc: string = '';

  @Builder
  emptyAction() {
  }

  @BuilderParam action: () => void = this.emptyAction;

  build() {
    Column({ space: 12 }) {
      Stack() {
        SymbolGlyph(this.icon)
          .fontSize(30)
          .fontColor([AppTheme.primary])
      }
      .width(72)
      .height(72)
      .backgroundColor(AppTheme.alpha(AppTheme.primary, '1F'))
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

@Component
export struct IconActionButton {
  icon: Resource = $r('sys.symbol.plus');
  boxSize: number = 40;
  color: string = AppTheme.textPrimary;
  bg: string = AppTheme.surface;
  onTap: () => void = () => {
  };

  build() {
    Stack() {
      SymbolGlyph(this.icon)
        .fontSize(this.boxSize * 0.46)
        .fontColor([this.color])
    }
    .width(this.boxSize)
    .height(this.boxSize)
    .backgroundColor(this.bg)
    .borderRadius(this.boxSize / 2)
    .onClick(() => this.onTap())
  }
}
