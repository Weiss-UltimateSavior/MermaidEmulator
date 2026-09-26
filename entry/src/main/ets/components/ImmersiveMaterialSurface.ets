import { uiMaterial } from '@kit.ArkUI';

@Component
export struct ImmersiveMaterialSurface {
  surfaceHeight: number = 0;
  surfaceRadius: number = 0;
  bleedHorizontal: number = 0;

  @Builder
  emptyContent() {
  }

  @BuilderParam content: () => void = this.emptyContent;

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .borderRadius(this.surfaceRadius)
        .backgroundColor('#22FFFFFF')
        .backgroundBlurStyle(BlurStyle.COMPONENT_THIN, {
          colorMode: ThemeColorMode.LIGHT,
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: 1.0
        })
        .systemMaterial(new uiMaterial.ImmersiveMaterial({
          style: uiMaterial.ImmersiveStyle.THIN,
          materialColor: '#00FFFFFF',
          applyShadow: false,
          interactive: true,
          lightEffect: { color: '#A6E9FF' }
        }))

      this.content()
    }
    .width(this.bleedHorizontal > 0
      ? `calc(100% + ${this.bleedHorizontal * 2}vp)`
      : '100%')
    .height(this.surfaceHeight)
    .offset({ x: -this.bleedHorizontal })
    .borderRadius(this.surfaceRadius)
    .clip(this.surfaceRadius > 0)
  }
}
