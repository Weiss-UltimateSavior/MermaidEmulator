import { AppTheme } from '../common/Theme';
import { Format } from '../common/Format';
import { Game } from '../model/Game';
import { EngineRegistry } from '../engine/EngineRegistry';

@Component
export struct GameCard {
  @ObjectLink game: Game;
  onOpen: (game: Game) => void = () => {
  };

  build() {
    Column({ space: 8 }) {
      Stack({ alignContent: Alignment.TopStart }) {
        Column()
          .width('100%')
          .aspectRatio(0.74)
          .borderRadius(AppTheme.radiusM)
          .linearGradient({ angle: 155, colors: AppTheme.coverGradient(this.game.title) })

        Stack() {
          Text(this.game.title.length > 0 ? this.game.title.substring(0, 1) : '?')
            .fontSize(42)
            .fontWeight(FontWeight.Bold)
            .fontColor('#EAF3FF')
        }
        .width('100%')
        .height('100%')

        Row() {
          Text(EngineRegistry.find(this.game.engineId).shortName)
            .fontSize(10)
            .fontColor('#EAF3FF')
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor('#66000000')
            .borderRadius(6)
        }
        .margin({ left: 8, top: 8 })

        if (this.game.favorite) {
          Row() {
            SymbolGlyph($r('sys.symbol.star_fill'))
              .fontSize(13)
              .fontColor(['#FFD66B'])
          }
          .width('100%')
          .justifyContent(FlexAlign.End)
          .padding({ right: 8, top: 8 })
        }
      }
      .width('100%')

      Column({ space: 3 }) {
        Text(this.game.title)
          .fontSize(14)
          .fontColor(AppTheme.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.subLine())
          .fontSize(11)
          .fontColor(AppTheme.textTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
    }
    .width('100%')
    .onClick(() => this.onOpen(this.game))
  }

  private subLine(): string {
    if (this.game.lastPlayedAt > 0) {
      return `上次 ${Format.date(this.game.lastPlayedAt)} · ${this.game.playCount} 次`;
    }
    return `导入于 ${Format.date(this.game.importedAt)}`;
  }
}
