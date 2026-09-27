import { AppTheme } from '../common/Theme';

@CustomDialog
export struct RenameDialog {
  controller: CustomDialogController;
  @Link name: string;
  onConfirm: (name: string) => boolean = (name: string) => {
    return true;
  };
  @StorageLink('themePrimary') themePrimary: string = AppTheme.primaryDefault;

  build() {
    Column({ space: 16 }) {
      Text('名称修改')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.textPrimary)
        .width('100%')

      Column({ space: 6 }) {
        TextInput({ text: this.name })
          .maxLength(64)
          .height(48)
          .fontSize(16)
          .fontColor(AppTheme.textPrimary)
          .caretColor(this.themePrimary)
          .backgroundColor(AppTheme.surfaceAlt)
          .borderRadius(AppTheme.radiusS)
          .onChange((value: string) => {
            this.name = value;
          })

        Text('仅修改游戏页显示的名称，不会重命名游戏目录。')
          .fontSize(12)
          .fontColor(AppTheme.textTertiary)
          .width('100%')
      }
      .width('100%')

      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .height(42)
          .fontSize(14)
          .fontColor(AppTheme.textPrimary)
          .backgroundColor(AppTheme.surfaceAlt)
          .borderRadius(21)
          .stateEffect(false)
          .onClick(() => {
            this.controller.close();
          })

        Button('确定')
          .layoutWeight(1)
          .height(42)
          .fontSize(14)
          .fontColor(AppTheme.onPrimary)
          .backgroundColor(this.themePrimary)
          .borderRadius(21)
          .stateEffect(false)
          .onClick(() => {
            if (this.onConfirm(this.name)) {
              this.controller.close();
            }
          })
      }
      .width('100%')
    }
    .width('80%')
    .constraintSize({ maxWidth: 400 })
    .padding(20)
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.radiusL)
  }
}
