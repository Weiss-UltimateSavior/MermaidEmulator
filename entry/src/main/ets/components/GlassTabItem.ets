import { AppTheme } from '../common/Theme';

@Component
export struct GlassTabItem {
  index: number = 0;
  icon: Resource = $r('app.media.nav_game');
  label: string = '';
  @Prop selected: boolean = false;
  onSelect: (index: number) => void = (index: number) => {
  };
  @StorageLink('themePrimary') themePrimary: string = AppTheme.primaryDefault;

  build() {
    Column({ space: 1 }) {
      Image(this.icon)
        .width(26)
        .height(26)
        .objectFit(ImageFit.Contain)
        .colorFilter(this.selected ? this.themePrimary : AppTheme.textSecondary)
      Text(this.label)
        .fontSize(10)
        .fontColor(this.selected ? this.themePrimary : AppTheme.textSecondary)
    }
    .justifyContent(FlexAlign.Center)
    .height(48)
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.onSelect(this.index);
    })
  }
}
