import { AppTheme } from '../common/Theme';

export class GameSidebarItem {
  key: string;
  label: string;
  icon: Resource;
  danger: boolean;

  constructor(key: string, label: string, icon: Resource, danger: boolean = false) {
    this.key = key;
    this.label = label;
    this.icon = icon;
    this.danger = danger;
  }
}

@Component
export struct GameSidebar {
  items: GameSidebarItem[] = [];
  onClose: () => void = () => {
  };
  onAction: (key: string) => void = () => {
  };
  @StorageLink('themePrimary') themePrimary: string = AppTheme.primaryDefault;

  build() {
    Stack({ alignContent: Alignment.Start }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#33000000')
        .onClick(() => {
          this.onClose();
        })

      Column({ space: 6 }) {
        ForEach(this.items, (item: GameSidebarItem) => {
          this.itemRow(item)
        }, (item: GameSidebarItem) => item.key)
      }
      .width(140)
      .padding(8)
      .margin({ left: 14 })
      .backgroundColor('#E61A1F28')
      .borderRadius(20)
    }
    .width('100%')
    .height('100%')
    .transition(TransitionEffect.OPACITY.animation({ duration: 150 }))
  }

  @Builder
  itemRow(item: GameSidebarItem) {
    Row({ space: 10 }) {
      SymbolGlyph(item.icon)
        .fontSize(20)
        .fontColor([item.danger ? AppTheme.danger : this.themePrimary])

      Text(item.label)
        .fontSize(15)
        .fontColor(item.danger ? AppTheme.danger : AppTheme.onPrimary)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(46)
    .padding({ left: 14, right: 12 })
    .borderRadius(12)
    .clickEffect(null)
    .hoverEffect(HoverEffect.None)
    .onClick(() => {
      this.onAction(item.key);
    })
  }
}
