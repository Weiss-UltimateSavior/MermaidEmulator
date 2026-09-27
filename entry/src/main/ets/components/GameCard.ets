import { fileUri } from '@kit.CoreFileKit';
import { AppTheme } from '../common/Theme';
import { Game } from '../model/Game';
import { EngineRegistry } from '../engine/EngineRegistry';

@Component
export struct GameCard {
  @ObjectLink game: Game;
  onTap: (game: Game) => void = (game: Game) => {
  };
  private tapStartedAt: number = 0;
  private tapX: number = 0;
  private tapY: number = 0;
  private suppressTap: boolean = false;

  build() {
    Column({ space: 8 }) {
      Stack({ alignContent: Alignment.TopStart }) {
        if (this.game.coverPath.length > 0) {
          Image(fileUri.getUriFromPath(this.game.coverPath))
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
        } else {
          Column()
            .width('100%')
            .height('100%')
            .borderRadius(AppTheme.radiusM)
            .linearGradient({ angle: 155, colors: AppTheme.coverGradient(this.game.title) })

          Column() {
            Text(this.game.title.length > 0 ? this.game.title.substring(0, 1) : '?')
              .fontSize(42)
              .fontWeight(FontWeight.Bold)
              .fontColor('#EAF3FF')
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }

        Row() {
          Text(EngineRegistry.find(this.game.engineId).shortName)
            .fontSize(10)
            .fontColor('#EAF3FF')
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor('#66000000')
            .borderRadius(6)
        }
        .margin({ left: 8, top: 8 })
      }
      .width('100%')
      .aspectRatio(0.74)
      .borderRadius(AppTheme.radiusM)
      .clip(true)

      Text(this.game.title)
        .fontSize(14)
        .fontColor(AppTheme.textPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .width('100%')
    .onTouch((event: TouchEvent) => {
      const touch = event.touches.length > 0 ? event.touches[0] : null;
      if (touch === null) {
        return;
      }
      if (event.type === TouchType.Down) {
        this.tapStartedAt = Date.now();
        this.tapX = touch.x;
        this.tapY = touch.y;
        this.suppressTap = false;
      } else if (event.type === TouchType.Move) {
        if (Math.abs(touch.x - this.tapX) > 10 || Math.abs(touch.y - this.tapY) > 10) {
          this.suppressTap = true;
        }
      } else if (event.type === TouchType.Up) {
        if (Date.now() - this.tapStartedAt > 500) {
          this.suppressTap = true;
        }
      } else {
        this.suppressTap = true;
      }
    })
    .onClick(() => {
      if (this.suppressTap) {
        this.suppressTap = false;
        return;
      }
      this.onTap(this.game);
    })
  }
}
