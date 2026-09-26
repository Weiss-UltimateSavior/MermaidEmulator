import { AppTheme } from '../common/Theme';
import { Game } from '../model/Game';
import { EngineCore } from '../model/Engine';
import { EngineRegistry } from '../engine/EngineRegistry';
import { AppBackground } from '../components/AppBackground';
import { PageTopBar } from '../components/CommonWidgets';

@Component
export struct PlayerPage {
  @State game: Game = Game.placeholder();
  @State logs: string[] = [];
  @StorageLink('safeBottomVp') safeBottom: number = 0;
  private stack: NavPathStack = new NavPathStack();
  private timerId: number = -1;

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  build() {
    NavDestination() {
      Stack() {
        AppBackground()

        Column() {
          Column() {
            PageTopBar({ title: this.game.title })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 0, bottom: 10 })

          Column({ space: 12 }) {
            Stack({ alignContent: Alignment.Center }) {
              Column({ space: 8 }) {
                Stack() {
                  SymbolGlyph($r('sys.symbol.gamecontroller'))
                    .fontSize(24)
                    .fontColor([AppTheme.accent])
                }
                .width(54)
                .height(54)
                .backgroundColor(AppTheme.alpha(AppTheme.accent, '26'))
                .borderRadius(27)

                Text(`${EngineRegistry.find(this.game.engineId).name} 运行时未接入`)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.textPrimary)

                Text('播放器外壳已就绪：画面 Surface、控制栏与存档入口均已预留。')
                  .fontSize(10)
                  .fontColor(AppTheme.textTertiary)
                  .textAlign(TextAlign.Center)
                  .padding({ left: 16, right: 16 })

                Column({ space: 6 }) {
                  this.stepRow($r('sys.symbol.checkmark_circle_fill'), 'UI 外壳与播放器界面', true)
                  this.stepRow($r('sys.symbol.checkmark_circle_fill'), '内核抽象与注册表', true)
                  this.stepRow($r('sys.symbol.record_circle'), 'NAPI 运行时桥接', false)
                  this.stepRow($r('sys.symbol.record_circle'), '渲染与音频管线', false)
                }
                .padding({ top: 2 })
              }
              .width('100%')
            }
            .width('100%')
            .aspectRatio(16 / 9)
            .backgroundColor('#02060E')
            .borderRadius(AppTheme.radiusM)
            .border({ width: 1, color: AppTheme.border })

            Column({ space: 4 }) {
              ForEach(this.logs, (line: string) => {
                Text(`› ${line}`)
                  .fontSize(11)
                  .fontColor(AppTheme.textTertiary)
                  .width('100%')
              }, (line: string, index: number) => `${index}_${line}`)
            }
            .width('100%')
            .height(118)
            .padding(10)
            .backgroundColor(AppTheme.surface)
            .borderRadius(AppTheme.radiusS)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .padding({ left: 16, right: 16 })

          Row() {
            PlayerControl({
              icon: $r('sys.symbol.line_3_horizontal'),
              label: '菜单',
              onTap: () => {
                this.notReady();
              }
            })
            PlayerControl({
              icon: $r('sys.symbol.archivebox'),
              label: '存档',
              onTap: () => {
                this.notReady();
              }
            })
            PlayerControl({
              icon: $r('sys.symbol.folder'),
              label: '读档',
              onTap: () => {
                this.notReady();
              }
            })

            Stack() {
              SymbolGlyph($r('sys.symbol.play_fill'))
                .fontSize(28)
                .fontColor([AppTheme.onPrimary])
            }
            .width(62)
            .height(62)
            .backgroundColor(AppTheme.primary)
            .borderRadius(31)
            .onClick(() => {
              this.notReady();
            })

            PlayerControl({
              icon: $r('sys.symbol.slider_horizontal_2'),
              label: '设置',
              onTap: () => {
                this.notReady();
              }
            })
            PlayerControl({
              icon: $r('sys.symbol.xmark'),
              label: '退出',
              onTap: () => {
                this.stack.pop();
              }
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceEvenly)
          .padding({ top: 10, bottom: 18 + this.safeBottom })
          .backgroundColor(AppTheme.bgElevated)
          .border({ width: 1, color: AppTheme.border })
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.stack = context.pathStack;
      const param: Game = context.pathInfo.param as Game;
      this.game = param;
      this.startLogs();
    })
  }

  @Builder
  stepRow(icon: Resource, label: string, done: boolean) {
    Row({ space: 8 }) {
      SymbolGlyph(icon)
        .fontSize(12)
        .fontColor([done ? AppTheme.success : AppTheme.textTertiary])
      Text(label)
        .fontSize(10)
        .fontColor(done ? AppTheme.textSecondary : AppTheme.textTertiary)
    }
    .alignItems(VerticalAlign.Center)
  }

  private startLogs(): void {
    const core: EngineCore = EngineRegistry.find(this.game.engineId);
    const lines: string[] = [
      'UI 外壳初始化完成',
      `读取内核注册表：${EngineRegistry.installed().length} 个已安装内核`,
      `加载内核 ${core.name}（${core.statusText()}）`,
      '画面 Surface 已创建，等待运行时绑定',
      '音频通路已预留，等待内核输出',
      '当前处于待机模式：运行时桥接后即可播放'
    ];
    this.logs = [];
    let index = 0;
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
    }
    this.timerId = setInterval(() => {
      if (index >= lines.length) {
        if (this.timerId >= 0) {
          clearInterval(this.timerId);
          this.timerId = -1;
        }
        return;
      }
      this.logs = this.logs.concat([lines[index]]);
      index = index + 1;
    }, 620);
  }

  private notReady(): void {
    this.getUIContext().getPromptAction().showToast({ message: '内核运行时未接入，控制功能待桥接后启用' });
  }
}

@Component
struct PlayerControl {
  icon: Resource = $r('sys.symbol.line_3_horizontal');
  label: string = '';
  onTap: () => void = () => {
  };

  build() {
    Column({ space: 5 }) {
      SymbolGlyph(this.icon)
        .fontSize(20)
        .fontColor([AppTheme.textSecondary])
      Text(this.label)
        .fontSize(10)
        .fontColor(AppTheme.textTertiary)
    }
    .padding(6)
    .onClick(() => this.onTap())
  }
}
