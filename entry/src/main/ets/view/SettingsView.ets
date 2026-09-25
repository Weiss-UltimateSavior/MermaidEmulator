import { AppTheme } from '../common/Theme';
import { Game } from '../model/Game';
import { EngineCore } from '../model/Engine';
import { EngineRegistry } from '../engine/EngineRegistry';
import { LibraryStore } from '../store/LibraryStore';
import { SettingsStore } from '../store/SettingsStore';
import { PageHeader, SectionCard, SettingRow } from '../components/CommonWidgets';

@Component
export struct SettingsView {
  @StorageLink('stg_autoCore') autoCore: boolean = true;
  @StorageLink('stg_copyImport') copyImport: boolean = true;
  @StorageLink('stg_defaultCore') defaultCore: string = 'artemis';
  @StorageLink('stg_resolution') resolution: string = '跟随原始分辨率';
  @StorageLink('stg_fps') fps: string = '60 FPS';
  @StorageLink('stg_scaleMode') scaleMode: string = '保持比例';
  @StorageLink('stg_volume') volume: number = 70;
  @StorageLink('games') games: Game[] = [];

  build() {
    Scroll() {
      Column({ space: 14 }) {
        PageHeader({ title: '设置', subtitle: '存储、内核与画音参数' })

        SectionCard({ title: '存储' }) {
          Column() {
            SettingRow({
              icon: $r('sys.symbol.externaldrive'),
              label: '存储位置',
              value: '应用私有目录',
              hint: '游戏数据与存档的默认位置',
              showArrow: true,
              onTap: () => {
                this.getUIContext().getPromptAction().showToast({ message: '当前使用应用私有目录，暂不支持自定义' });
              }
            })
            Divider().color(AppTheme.border)
            SettingRow({
              icon: $r('sys.symbol.archivebox'),
              label: '导入时复制到应用目录',
              hint: '避免源文件被移动后无法启动'
            }) {
              Toggle({ type: ToggleType.Switch, isOn: this.copyImport })
                .selectedColor(AppTheme.primary)
                .onChange((isOn: boolean) => {
                  this.copyImport = isOn;
                  SettingsStore.persist();
                })
            }
          }
        }

        SectionCard({ title: '内核' }) {
          Column() {
            SettingRow({
              icon: $r('sys.symbol.square_stack_3d'),
              label: '自动匹配内核',
              hint: '按文件扩展名自动选择内核'
            }) {
              Toggle({ type: ToggleType.Switch, isOn: this.autoCore })
                .selectedColor(AppTheme.primary)
                .onChange((isOn: boolean) => {
                  this.autoCore = isOn;
                  SettingsStore.persist();
                })
            }
            Divider().color(AppTheme.border)
            Column() {
              SettingRow({
                icon: $r('sys.symbol.gamecontroller'),
                label: '默认内核',
                value: EngineRegistry.find(this.defaultCore).name,
                hint: '自动匹配失败时使用',
                showArrow: true
              })
            }
            .bindMenu(this.coreMenu())
          }
        }

        SectionCard({ title: '画面' }) {
          Column() {
            Column() {
              SettingRow({
                icon: $r('sys.symbol.display'),
                label: '渲染分辨率',
                value: this.resolution,
                showArrow: true
              })
            }
            .bindMenu(this.optionMenu('stg_resolution', ['跟随原始分辨率', '720p', '1080p', '2K'], this.resolution))

            Divider().color(AppTheme.border)

            Column() {
              SettingRow({
                icon: $r('sys.symbol.timer_circle_fill'),
                label: '帧率上限',
                value: this.fps,
                showArrow: true
              })
            }
            .bindMenu(this.optionMenu('stg_fps', ['跟随原始', '30 FPS', '60 FPS', '120 FPS'], this.fps))

            Divider().color(AppTheme.border)

            Column() {
              SettingRow({
                icon: $r('sys.symbol.uiwindow_split_1x2'),
                label: '缩放模式',
                value: this.scaleMode,
                showArrow: true
              })
            }
            .bindMenu(this.optionMenu('stg_scaleMode', ['保持比例', '拉伸铺满', '原始像素'], this.scaleMode))
          }
        }

        SectionCard({ title: '音频' }) {
          SettingRow({
            icon: $r('sys.symbol.speaker_wave_3'),
            label: '主音量',
            value: `${this.volume}%`,
            hint: '内核音频输出的全局音量'
          }) {
            Slider({
              value: this.volume,
              min: 0,
              max: 100,
              step: 1,
              style: SliderStyle.InSet
            })
              .width(120)
              .selectedColor(AppTheme.primary)
              .trackColor(AppTheme.surfaceHigh)
              .blockColor(AppTheme.textPrimary)
              .onChange((value: number, mode: SliderChangeMode) => {
                this.volume = Math.round(value);
                if (mode === SliderChangeMode.End) {
                  SettingsStore.persist();
                }
              })
          }
        }

        SectionCard({ title: '数据' }) {
          Column() {
            SettingRow({
              icon: $r('sys.symbol.list_bullet'),
              label: '游戏库条目',
              value: `${this.games.length} 条`
            })
            Divider().color(AppTheme.border)
            SettingRow({
              icon: $r('sys.symbol.trash'),
              label: '清空游戏库',
              hint: '仅移除库记录，不删除源文件',
              showArrow: true,
              onTap: () => {
                this.confirmClear();
              }
            })
          }
        }

        SectionCard({ title: '关于' }) {
          Column() {
            SettingRow({
              icon: $r('sys.symbol.info_circle'),
              label: '应用版本',
              value: '1.0.0'
            })
            Divider().color(AppTheme.border)
            SettingRow({
              icon: $r('sys.symbol.square_stack_3d'),
              label: '内核架构',
              value: 'EngineCore v1'
            })
            Divider().color(AppTheme.border)
            SettingRow({
              icon: $r('sys.symbol.gamecontroller'),
              label: '首批接入',
              value: 'Artemis Engine'
            })
          }
        }
      }
      .width('100%')
      .padding({ left: AppTheme.pagePadding, right: AppTheme.pagePadding, top: AppTheme.pagePadding, bottom: 84 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.bg)
    .scrollBar(BarState.Off)
  }

  private optionMenu(key: string, options: string[], current: string): MenuElement[] {
    return options.map((option: string) => {
      const item: MenuElement = {
        value: option === current ? `${option}（当前）` : option,
        action: () => {
          AppStorage.setOrCreate<string>(key, option);
          SettingsStore.persist();
        }
      };
      return item;
    });
  }

  private coreMenu(): MenuElement[] {
    return EngineRegistry.installed().map((core: EngineCore) => {
      const item: MenuElement = {
        value: core.id === this.defaultCore ? `${core.name}（当前）` : core.name,
        action: () => {
          this.defaultCore = core.id;
          SettingsStore.persist();
        }
      };
      return item;
    });
  }

  private confirmClear(): void {
    this.getUIContext().showAlertDialog({
      title: '清空游戏库',
      message: `将移除全部 ${this.games.length} 条游戏记录，源文件不会被删除。`,
      autoCancel: true,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '清空',
        fontColor: AppTheme.danger,
        action: () => {
          LibraryStore.clear();
          this.getUIContext().getPromptAction().showToast({ message: '游戏库已清空' });
        }
      }
    });
  }
}
