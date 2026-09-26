import { AppTheme } from '../common/Theme';
import { EngineCore } from '../model/Engine';
import { EngineRegistry } from '../engine/EngineRegistry';
import { KernelCard } from '../components/KernelCard';
import { PageTopBar, SectionCard } from '../components/CommonWidgets';

@Component
export struct KernelView {
  onOpenKernel: (core: EngineCore) => void = () => {
  };

  build() {
    Scroll() {
      Column({ space: 14 }) {
        PageTopBar({ title: '内核管理' })

        Column({ space: 10 }) {
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.bolt'))
              .fontSize(16)
              .fontColor([AppTheme.primary])
            Text('首批接入 · Artemis Engine')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.textPrimary)
          }
          .width('100%')

          Text('UI 外壳与内核抽象层已经就绪，下一步接入 arm64 运行时、NAPI 桥接与资源解包。')
            .fontSize(12)
            .fontColor(AppTheme.textSecondary)
            .lineHeight(18)
            .width('100%')

          Progress({ value: this.artemisProgress(), total: 100, type: ProgressType.Linear })
            .width('100%')
            .color(AppTheme.primary)
            .backgroundColor(AppTheme.surfaceHigh)
            .style({ strokeWidth: 6 })
        }
        .width('100%')
        .padding(14)
        .linearGradient({
          angle: 135,
          colors: [[AppTheme.alpha(AppTheme.accent, '3D'), 0.0], [AppTheme.surface, 1.0]]
        })
        .borderRadius(AppTheme.radiusM)
        .border({ width: 1, color: AppTheme.border })

        Row({ space: 10 }) {
          this.statCard('已安装', `${EngineRegistry.installed().length}`, AppTheme.primary)
          this.statCard('已接入', `${EngineRegistry.readyCount()}`, AppTheme.success)
          this.statCard('规划中', `${EngineRegistry.planned().length}`, AppTheme.accent)
        }
        .width('100%')

        SectionCard({ title: '已安装内核', subtitle: '点击查看接入进度' }) {
          Column({ space: 10 }) {
            ForEach(EngineRegistry.installed(), (core: EngineCore) => {
              KernelCard({
                core: core,
                onOpen: (target: EngineCore) => {
                  this.onOpenKernel(target);
                }
              })
            }, (core: EngineCore) => core.id)
          }
        }

        SectionCard({ title: '规划中内核', subtitle: '按需求优先级排期' }) {
          Column({ space: 10 }) {
            ForEach(EngineRegistry.planned(), (core: EngineCore) => {
              KernelCard({
                core: core,
                onOpen: (target: EngineCore) => {
                  this.onOpenKernel(target);
                }
              })
            }, (core: EngineCore) => core.id)
          }
        }

        SectionCard({ title: '内核架构', subtitle: 'EngineCore 抽象' }) {
          Column({ space: 12 }) {
            this.archRow('EngineCore 抽象', '统一描述内核的能力、支持格式、运行时与接入进度')
            this.archRow('EngineRegistry 注册表', '内置内核与规划内核统一注册，按扩展名自动匹配')
            this.archRow('EngineStatus 状态机', '未接入 / 已接入 / 已停用，驱动 UI 与启动流程')
            this.archRow('播放器外壳', 'Surface、控制栏与存档入口已预留，等待内核绑定')
          }
        }
      }
      .width('100%')
      .padding({ left: AppTheme.pagePadding, right: AppTheme.pagePadding, top: 0, bottom: 84 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }

  @Builder
  statCard(label: string, value: string, color: string) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(label)
        .fontSize(11)
        .fontColor(AppTheme.textTertiary)
    }
    .layoutWeight(1)
    .padding({ top: 12, bottom: 12 })
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.radiusM)
    .border({ width: 1, color: AppTheme.border })
  }

  @Builder
  archRow(title: string, desc: string) {
    Row({ space: 10 }) {
      Stack() {
        Column()
          .width(7)
          .height(7)
          .backgroundColor(AppTheme.primary)
          .borderRadius(4)
      }
      .width(18)

      Column({ space: 3 }) {
        Text(title)
          .fontSize(13)
          .fontColor(AppTheme.textPrimary)
        Text(desc)
          .fontSize(11)
          .fontColor(AppTheme.textTertiary)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  private artemisProgress(): number {
    return EngineRegistry.find('artemis').overallProgress();
  }
}
