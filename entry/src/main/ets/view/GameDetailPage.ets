import { AppTheme } from '../common/Theme';
import { Format } from '../common/Format';
import { Game } from '../model/Game';
import { EngineCore } from '../model/Engine';
import { EngineRegistry } from '../engine/EngineRegistry';
import { LibraryStore } from '../store/LibraryStore';
import { AppBackground } from '../components/AppBackground';
import { IconActionButton, PageTopBar, SectionCard, SettingRow, StatusChip } from '../components/CommonWidgets';

@Component
export struct GameDetailPage {
  @State game: Game = Game.placeholder();
  @State textSpeed: number = 60;
  @State autoAdvance: boolean = false;
  @StorageLink('safeBottomVp') safeBottom: number = 0;
  private stack: NavPathStack = new NavPathStack();

  build() {
    NavDestination() {
      Stack() {
        AppBackground()

        Scroll() {
          Column({ space: 14 }) {
            PageTopBar({ title: '游戏详情' })

            Row({ space: 14 }) {
              Stack({ alignContent: Alignment.Center }) {
                Column()
                  .width(72)
                  .height(96)
                  .borderRadius(AppTheme.radiusS)
                  .linearGradient({ angle: 155, colors: AppTheme.coverGradient(this.game.title) })
                Text(this.game.title.length > 0 ? this.game.title.substring(0, 1) : '?')
                  .fontSize(30)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#EAF3FF')
              }

              Column({ space: 8 }) {
                Text(this.game.title)
                  .fontSize(19)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppTheme.textPrimary)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Row({ space: 6 }) {
                  StatusChip({
                    text: EngineRegistry.find(this.game.engineId).shortName,
                    color: EngineRegistry.find(this.game.engineId).accent
                  })
                  StatusChip({
                    text: EngineRegistry.find(this.game.engineId).statusText(),
                    color: EngineRegistry.find(this.game.engineId).statusColor()
                  })
                }

                Text(this.game.path)
                  .fontSize(11)
                  .fontColor(AppTheme.textTertiary)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .padding(14)
            .linearGradient({ angle: 135, colors: AppTheme.heroGradient(this.game.coverColor()) })
            .borderRadius(AppTheme.radiusL)
            .border({ width: 1, color: AppTheme.border })

            Row({ space: 10 }) {
              IconActionButton({
                icon: this.game.favorite ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'),
                color: this.game.favorite ? '#FFD66B' : AppTheme.textPrimary,
                boxSize: 46,
                onTap: () => {
                  LibraryStore.toggleFavorite(this.game);
                }
              })
              IconActionButton({
                icon: $r('sys.symbol.trash'),
                color: AppTheme.danger,
                boxSize: 46,
                onTap: () => {
                  this.confirmDelete();
                }
              })
              Button('启动游戏')
                .layoutWeight(1)
                .height(46)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.onPrimary)
                .backgroundColor(AppTheme.primary)
                .borderRadius(23)
                .onClick(() => {
                  this.launch();
                })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            SectionCard({ title: '详细信息' }) {
              Column() {
                this.infoRow('导入时间', Format.dateTime(this.game.importedAt))
                Divider().color(AppTheme.border)
                this.infoRow('上次运行', Format.dateTime(this.game.lastPlayedAt))
                Divider().color(AppTheme.border)
                this.infoRow('运行次数', `${this.game.playCount} 次`)
                Divider().color(AppTheme.border)
                this.infoRow('收藏', this.game.favorite ? '已收藏' : '未收藏')
              }
            }

            SectionCard({ title: '内核', subtitle: '点击切换' }) {
              Column() {
                Column() {
                  SettingRow({
                    icon: $r('sys.symbol.gamecontroller'),
                    label: EngineRegistry.find(this.game.engineId).name,
                    hint: EngineRegistry.find(this.game.engineId).runtime,
                    showArrow: true
                  })
                }
                .bindMenu(this.engineMenu())

                Divider().color(AppTheme.border)

                Text(EngineRegistry.find(this.game.engineId).description)
                  .fontSize(12)
                  .fontColor(AppTheme.textSecondary)
                  .lineHeight(18)
                  .width('100%')
                  .padding({ top: 10, bottom: 4 })
              }
            }

            SectionCard({ title: '启动参数', subtitle: '随游戏保存' }) {
              Column() {
                SettingRow({
                  icon: $r('sys.symbol.textformat'),
                  label: '文字速度',
                  value: `${this.textSpeed}%`,
                  hint: '对话文本显示速度'
                }) {
                  Slider({
                    value: this.textSpeed,
                    min: 0,
                    max: 100,
                    step: 5,
                    style: SliderStyle.InSet
                  })
                    .width(120)
                    .selectedColor(AppTheme.primary)
                    .trackColor(AppTheme.surfaceHigh)
                    .blockColor(AppTheme.textPrimary)
                    .onChange((value: number) => {
                      this.textSpeed = Math.round(value);
                    })
                }
                Divider().color(AppTheme.border)
                SettingRow({
                  icon: $r('sys.symbol.forward_end_fill'),
                  label: '自动播放',
                  hint: '自动推进对话'
                }) {
                  Toggle({ type: ToggleType.Switch, isOn: this.autoAdvance })
                    .selectedColor(AppTheme.primary)
                    .onChange((isOn: boolean) => {
                      this.autoAdvance = isOn;
                    })
                }
              }
            }

            Row({ space: 8 }) {
              SymbolGlyph($r('sys.symbol.bolt'))
                .fontSize(14)
                .fontColor([AppTheme.warning])
              Text('该游戏使用 Artemis 内核，运行时尚未接入，启动后将进入播放器外壳。')
                .fontSize(11)
                .fontColor(AppTheme.textTertiary)
                .layoutWeight(1)
            }
            .width('100%')
            .padding(12)
            .backgroundColor(AppTheme.alpha(AppTheme.warning, '1A'))
            .borderRadius(AppTheme.radiusS)
          }
          .width('100%')
          .padding({
            left: AppTheme.pagePadding,
            right: AppTheme.pagePadding,
            top: 0,
            bottom: AppTheme.pagePadding + this.safeBottom
          })
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.stack = context.pathStack;
      const param: Game = context.pathInfo.param as Game;
      this.game = param;
    })
  }

  @Builder
  infoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor(AppTheme.textSecondary)
      Blank()
      Text(value)
        .fontSize(13)
        .fontColor(AppTheme.textPrimary)
    }
    .width('100%')
    .padding({ top: 9, bottom: 9 })
  }

  private engineMenu(): MenuElement[] {
    return EngineRegistry.installed().map((core: EngineCore) => {
      const item: MenuElement = {
        value: core.id === this.game.engineId ? `${core.name}（当前）` : core.name,
        action: () => {
          LibraryStore.setEngine(this.game, core.id);
          this.getUIContext().getPromptAction().showToast({ message: `已切换到 ${core.name}` });
        }
      };
      return item;
    });
  }

  private launch(): void {
    const core = EngineRegistry.find(this.game.engineId);
    LibraryStore.markPlayed(this.game);
    if (!core.runtimeReady) {
      this.getUIContext().getPromptAction().showToast({ message: `${core.name} 运行时未接入，进入播放器外壳` });
    }
    this.stack.pushPath(new NavPathInfo('Player', this.game));
  }

  private confirmDelete(): void {
    this.getUIContext().showAlertDialog({
      title: '移除游戏',
      message: `确定要从游戏库移除「${this.game.title}」吗？`,
      autoCancel: true,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '移除',
        fontColor: AppTheme.danger,
        action: () => {
          LibraryStore.remove(this.game.id);
          this.stack.pop();
        }
      }
    });
  }
}
