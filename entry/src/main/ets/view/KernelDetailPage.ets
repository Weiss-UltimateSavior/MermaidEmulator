import { AppTheme } from '../common/Theme';
import { EngineCore, EngineFeature, EngineStatus, KernelProgress } from '../model/Engine';
import { EngineRegistry } from '../engine/EngineRegistry';
import { SettingsStore } from '../store/SettingsStore';
import { IconActionButton, SectionCard, StatusChip } from '../components/CommonWidgets';

@Component
export struct KernelDetailPage {
  @State core: EngineCore = new EngineCore();
  @StorageLink('stg_defaultCore') defaultCore: string = 'artemis';
  private stack: NavPathStack = new NavPathStack();

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 14 }) {
          Row({ space: 8 }) {
            IconActionButton({
              icon: $r('sys.symbol.chevron_backward'),
              boxSize: 38,
              onTap: () => {
                this.stack.pop();
              }
            })
            Text('内核详情')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.textPrimary)
            Blank()
            StatusChip({ text: this.core.statusText(), color: this.core.statusColor() })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Column({ space: 12 }) {
            Row({ space: 14 }) {
              Stack() {
                SymbolGlyph($r('sys.symbol.gamecontroller'))
                  .fontSize(28)
                  .fontColor([this.core.accent])
              }
              .width(64)
              .height(64)
              .backgroundColor(AppTheme.alpha(this.core.accent, '26'))
              .borderRadius(20)

              Column({ space: 6 }) {
                Text(this.core.name)
                  .fontSize(19)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppTheme.textPrimary)
                Text(`${this.core.vendor} · ${this.core.version}`)
                  .fontSize(12)
                  .fontColor(AppTheme.textSecondary)
                Text(`运行时：${this.core.runtime}`)
                  .fontSize(11)
                  .fontColor(AppTheme.textTertiary)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')

            Column({ space: 6 }) {
              Row() {
                Text('整体接入进度')
                  .fontSize(12)
                  .fontColor(AppTheme.textSecondary)
                Blank()
                Text(`${this.core.overallProgress()}%`)
                  .fontSize(12)
                  .fontColor(this.core.accent)
              }
              .width('100%')

              Progress({ value: this.core.overallProgress(), total: 100, type: ProgressType.Linear })
                .width('100%')
                .color(this.core.accent)
                .backgroundColor(AppTheme.surfaceHigh)
                .style({ strokeWidth: 6 })
            }
            .width('100%')
          }
          .width('100%')
          .padding(14)
          .linearGradient({ angle: 135, colors: AppTheme.heroGradient(this.core.accent) })
          .borderRadius(AppTheme.radiusL)
          .border({ width: 1, color: AppTheme.border })

          SectionCard({ title: '内核说明' }) {
            Text(this.core.description)
              .fontSize(12)
              .fontColor(AppTheme.textSecondary)
              .lineHeight(19)
              .width('100%')
          }

          SectionCard({ title: '支持格式' }) {
            Row({ space: 8 }) {
              ForEach(this.core.extensions, (ext: string) => {
                Text(ext)
                  .fontSize(12)
                  .fontColor(AppTheme.textPrimary)
                  .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                  .backgroundColor(AppTheme.surfaceAlt)
                  .borderRadius(8)
              }, (ext: string) => ext)
            }
            .width('100%')
          }

          if (this.core.features.length > 0) {
            SectionCard({ title: '能力矩阵' }) {
              Column({ space: 14 }) {
                ForEach(this.core.features, (feature: EngineFeature) => {
                  Row({ space: 12 }) {
                    Stack() {
                      SymbolGlyph(feature.icon)
                        .fontSize(16)
                        .fontColor([this.core.accent])
                    }
                    .width(32)
                    .height(32)
                    .backgroundColor(AppTheme.surfaceAlt)
                    .borderRadius(10)

                    Column({ space: 3 }) {
                      Text(feature.label)
                        .fontSize(13)
                        .fontColor(AppTheme.textPrimary)
                      Text(feature.detail)
                        .fontSize(11)
                        .fontColor(AppTheme.textTertiary)
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Center)
                }, (feature: EngineFeature) => feature.label)
              }
            }
          }

          SectionCard({ title: '接入进度', subtitle: '由 UI 到运行时的推进顺序' }) {
            Column({ space: 14 }) {
              ForEach(this.core.progress, (item: KernelProgress) => {
                Column({ space: 6 }) {
                  Row() {
                    Text(item.label)
                      .fontSize(12)
                      .fontColor(AppTheme.textSecondary)
                    Blank()
                    Text(`${item.value}% · ${item.stageText()}`)
                      .fontSize(11)
                      .fontColor(item.value >= 100 ? AppTheme.success : AppTheme.textTertiary)
                  }
                  .width('100%')

                  Progress({ value: item.value, total: 100, type: ProgressType.Linear })
                    .width('100%')
                    .color(item.value >= 100 ? AppTheme.success : AppTheme.primary)
                    .backgroundColor(AppTheme.surfaceHigh)
                    .style({ strokeWidth: 5 })
                }
                .width('100%')
              }, (item: KernelProgress) => item.label)
            }
          }

          if (this.core.status !== EngineStatus.PLANNED) {
            Button(this.defaultCore === this.core.id ? '已是默认内核' : '设为默认内核')
              .width('100%')
              .height(44)
              .fontSize(14)
              .fontColor(this.defaultCore === this.core.id ? AppTheme.textSecondary : '#062033')
              .backgroundColor(this.defaultCore === this.core.id ? AppTheme.surfaceAlt : AppTheme.primary)
              .borderRadius(22)
              .onClick(() => {
                this.applyDefault();
              })
          } else {
            Row({ space: 8 }) {
              SymbolGlyph($r('sys.symbol.questionmark_circle'))
                .fontSize(14)
                .fontColor([AppTheme.textTertiary])
              Text('该内核尚未排期，欢迎在设置页反馈优先级。')
                .fontSize(11)
                .fontColor(AppTheme.textTertiary)
                .layoutWeight(1)
            }
            .width('100%')
            .padding(12)
            .backgroundColor(AppTheme.surface)
            .borderRadius(AppTheme.radiusS)
            .border({ width: 1, color: AppTheme.border })
          }
        }
        .width('100%')
        .padding(AppTheme.pagePadding)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppTheme.bg)
      .scrollBar(BarState.Off)
    }
    .hideTitleBar(true)
    .backgroundColor(AppTheme.bg)
    .onReady((context: NavDestinationContext) => {
      this.stack = context.pathStack;
      const param: string = context.pathInfo.param as string;
      this.core = EngineRegistry.find(param);
    })
  }

  private applyDefault(): void {
    if (this.defaultCore === this.core.id) {
      this.getUIContext().getPromptAction().showToast({ message: `${this.core.name} 已是默认内核` });
      return;
    }
    this.defaultCore = this.core.id;
    SettingsStore.persist();
    this.getUIContext().getPromptAction().showToast({ message: `已将 ${this.core.name} 设为默认内核` });
  }
}
