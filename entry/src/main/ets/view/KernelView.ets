import { AppTheme } from '../common/Theme';
import { EngineCore, EngineStatus } from '../model/Engine';
import { EngineRegistry } from '../engine/EngineRegistry';
import { PageTopBar } from '../components/CommonWidgets';
import { SettingRow } from '../components/SettingRow';
import { SettingsStore } from '../store/SettingsStore';

@Component
export struct KernelView {
  @State showEngineSheet: boolean = false;
  @State engineOs: string = 'windows';
  @State engineScale: string = '跟随游戏';
  @State engineOrientation: string = '固定横屏';
  @State engineVsync: boolean = true;
  @State expandedKind: string = '';
  private engines: EngineCore[] = EngineRegistry.installed();

  aboutToAppear(): void {
    this.engineOs = AppStorage.get<string>('stg_engineOs') ?? 'windows';
    this.engineScale = AppStorage.get<string>('stg_engineScale') ?? '跟随游戏';
    this.engineOrientation = AppStorage.get<string>('stg_engineOrientation') ?? '固定横屏';
    this.engineVsync = AppStorage.get<boolean>('stg_engineVsync') ?? true;
  }

  build() {
    Column({ space: AppTheme.topBarGap }) {
      Column() {
        PageTopBar({ title: '引擎列表' })
      }
      .width('100%')
      .padding({ left: AppTheme.pagePadding, right: AppTheme.pagePadding })

      List({ space: 8 }) {
        ForEach(this.engines, (engine: EngineCore) => {
          ListItem() {
            SettingRow({
              icon: engine.icon,
              title: engine.name,
              onTap: () => {
                this.showEngineSheet = true;
              }
            }) {
              if (engine.status === EngineStatus.READY) {
                SymbolGlyph($r('sys.symbol.checkmark'))
                  .fontSize(20)
                  .fontColor([AppTheme.primary])
              } else {
                Text(engine.statusText())
                  .fontSize(14)
                  .fontColor(engine.statusColor())
              }
            }
          }
        }, (engine: EngineCore) => engine.id)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: AppTheme.pagePadding, right: AppTheme.pagePadding })
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .padding({ bottom: 84 })
    .bindSheet($$this.showEngineSheet, this.engineConfigSheet(), {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      preferType: SheetType.BOTTOM,
      dragBar: true,
      showClose: false,
      scrollSizeMode: ScrollSizeMode.CONTINUOUS
    })
  }

  @Builder
  engineConfigSheet() {
    Column() {
      List({ space: 8 }) {
        ListItem() {
          this.paramRow('模拟平台', 'os')
        }

        ListItem() {
          this.paramRow('画面缩放', 'scale')
        }

        ListItem() {
          this.paramRow('屏幕方向', 'orientation')
        }

        ListItem() {
          Row() {
            Text('垂直同步')
              .fontSize(16)
              .fontColor(AppTheme.textPrimary)
              .layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.engineVsync })
              .selectedColor(AppTheme.primary)
              .onChange((isOn: boolean) => {
                this.engineVsync = isOn;
                SettingsStore.setBool('stg_engineVsync', isOn);
              })
          }
          .width('100%')
          .constraintSize({ minHeight: 56 })
          .padding({
            left: AppTheme.pagePadding,
            right: AppTheme.pagePadding,
            top: 14,
            bottom: 14
          })
          .backgroundColor(AppTheme.surface)
          .borderRadius(AppTheme.radiusM)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: AppTheme.pagePadding, right: AppTheme.pagePadding })
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .padding({
      top: 20,
      bottom: 20
    })
  }

  @Builder
  paramRow(title: string, kind: string) {
    Column() {
      Row() {
        Text(title)
          .fontSize(16)
          .fontColor(AppTheme.textPrimary)
          .layoutWeight(1)
        Row({ space: 2 }) {
          Text(this.labelFor(kind))
            .fontSize(14)
            .fontColor(AppTheme.primary)
          SymbolGlyph(this.expandedKind === kind
            ? $r('sys.symbol.chevron_compact_up')
            : $r('sys.symbol.chevron_compact_down'))
            .fontSize(14)
            .fontColor([AppTheme.primary])
        }
        .padding({ left: 4, top: 6, bottom: 6 })
        .clickEffect(null)
        .hoverEffect(HoverEffect.None)
        .onClick(() => {
          this.expandedKind = this.expandedKind === kind ? '' : kind;
        })
      }
      .width('100%')

      if (this.expandedKind === kind) {
        Column() {
          if (kind === 'os') {
            this.optionRow('Windows', this.engineOs === 'windows', () => {
              this.pickValue('os', 'windows');
            })
            this.optionRow('Android', this.engineOs === 'android', () => {
              this.pickValue('os', 'android');
            })
            this.optionRow('iOS', this.engineOs === 'ios', () => {
              this.pickValue('os', 'ios');
            })
          } else if (kind === 'scale') {
            this.optionRow('跟随游戏', this.engineScale === '跟随游戏', () => {
              this.pickValue('scale', '跟随游戏');
            })
            this.optionRow('保持比例', this.engineScale === '保持比例', () => {
              this.pickValue('scale', '保持比例');
            })
            this.optionRow('铺满裁剪', this.engineScale === '铺满裁剪', () => {
              this.pickValue('scale', '铺满裁剪');
            })
          } else {
            this.optionRow('固定横屏', this.engineOrientation === '固定横屏', () => {
              this.pickValue('orientation', '固定横屏');
            })
            this.optionRow('自动旋转', this.engineOrientation === '自动旋转', () => {
              this.pickValue('orientation', '自动旋转');
            })
          }
        }
        .width('100%')
        .padding({ top: 6 })
      }
    }
    .width('100%')
    .padding({
      left: AppTheme.pagePadding,
      right: AppTheme.pagePadding,
      top: 14,
      bottom: 14
    })
    .backgroundColor(AppTheme.surface)
    .borderRadius(AppTheme.radiusM)
  }

  @Builder
  optionRow(label: string, selected: boolean, onPick: () => void) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(AppTheme.textPrimary)
        .layoutWeight(1)
      if (selected) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(16)
          .fontColor([AppTheme.primary])
      }
    }
    .width('100%')
    .height(42)
    .padding({ left: 4, right: 4 })
    .clickEffect(null)
    .hoverEffect(HoverEffect.None)
    .onClick(() => {
      onPick();
    })
  }

  private pickValue(kind: string, value: string): void {
    if (kind === 'os') {
      this.engineOs = value;
      SettingsStore.setString('stg_engineOs', value);
    } else if (kind === 'scale') {
      this.engineScale = value;
      SettingsStore.setString('stg_engineScale', value);
    } else {
      this.engineOrientation = value;
      SettingsStore.setString('stg_engineOrientation', value);
    }
    this.expandedKind = '';
  }

  private labelFor(kind: string): string {
    if (kind === 'os') {
      return this.engineOsLabel();
    }
    if (kind === 'scale') {
      return this.engineScale;
    }
    return this.engineOrientation;
  }

  private engineOsLabel(): string {
    if (this.engineOs === 'android') {
      return 'Android';
    }
    if (this.engineOs === 'ios') {
      return 'iOS';
    }
    return 'Windows';
  }
}
