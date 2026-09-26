@Component
export struct AppBackground {
  blurRadius: number = 320;

  build() {
    Stack() {
      Image($r('app.media.bg_page'))
        .width('200%')
        .height('200%')
        .objectFit(ImageFit.Cover)
        .blur(this.blurRadius)

      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#14FFFFFF')
    }
    .width('100%')
    .height('100%')
    .clip(true)
  }
}
