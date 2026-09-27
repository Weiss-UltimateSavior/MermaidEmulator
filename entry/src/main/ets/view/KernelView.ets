import { AppTheme } from '../common/Theme';
import { EngineCore, EngineStatus } from '../model/Engine';
import { EngineRegistry } from '../engine/EngineRegistry';
import { PageTopBar } from '../components/CommonWidgets';
import { SettingRow } from '../components/SettingRow';
import { SettingsStore, WebEngineConfig } from '../store/SettingsStore';

@Component
export struct KernelView {
  @State showEngineSheet: boolean = false;
  @State activeEngineId: string = 'artemis';
  @State webOrientation: string = '固定横屏';
  @State webNetwork: boolean = true;
  @State webVolume: number = 100;
  @State webTouchPad: boolean = false;
  @State webPort: number = WebEngineConfig.DEFAULT_PORT;
  @State webPortText: string = `${WebEngineConfig.DEFAULT_PORT}`;
  @StorageLink('themePrimary') themePrimary: string = AppTheme.primaryDefault;
  @State engineOs: string = 'windows';
  @State engineScale: string = '跟随游戏';
  @State engineOrientation: string = '固定横屏';
  @State engineVsync: boolean = true;
  @State expandedKind: string = '';
  private engines: EngineCore[] = EngineRegistry.all().filter((core: EngineCore) => core.status === EngineStatus.READY);

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
              iconImage: $r('app.media.engine_usb'),
              tintIconImage: true,
              title: engine.name,
              onTap: () => {
                this.openEngineSheet(engine.id);
              }
            }) {
              if (engine.status === EngineStatus.READY) {
                SymbolGlyph($r('sys.symbol.checkmark'))
                  .fontSize(20)
                  .fontColor([this.themePrimary])
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
    .bindSheet($$this.showEngineSheet, this.sheetContent(), {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      preferType: SheetType.BOTTOM,
      dragBar: true,
      showClose: false,
      scrollSizeMode: ScrollSizeMode.CONTINUOUS
    })
  }

  @Builder
  sheetContent() {
    if (this.activeEngineId === 'artemis') {
      this.artemisSheet()
    } else {
      this.webSheet()
    }
  }

  @Builder
  artemisSheet() {
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
              .selectedColor(this.themePrimary)
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
  webSheet() {
    Column() {
      List({ space: 8 }) {
        ListItem() {
          this.paramRow('屏幕方向', 'webOrientation')
        }

        ListItem() {
          this.portRow()
        }

        ListItem() {
          this.switchRow('外部网络', '允许游戏访问外部网络资源', this.webNetwork, (isOn: boolean) => {
            this.webNetwork = isOn;
            this.persistWebConfig();
          })
        }

        ListItem() {
          Column({ space: 10 }) {
            Row({ space: 12 }) {
              Text('音量')
                .fontSize(16)
                .fontColor(AppTheme.textPrimary)
              Slider({ value: this.webVolume, min: 0, max: 100, step: 1 })
                .layoutWeight(1)
                .selectedColor(this.themePrimary)
                .onChange((value: number) => {
                  this.webVolume = value;
                  this.persistWebConfig();
                })
              Text(`${Math.round(this.webVolume)}%`)
                .fontSize(13)
                .fontColor(AppTheme.textSecondary)
                .width(46)
                .textAlign(TextAlign.End)
            }
            .width('100%')
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
          .justifyContent(FlexAlign.Center)
        }

        if (this.activeEngineId === 'rpgm_mv' || this.activeEngineId === 'rpgm_mz') {
          ListItem() {
            this.switchRow('触屏手柄', '虚拟摇杆与动作按键', this.webTouchPad, (isOn: boolean) => {
              this.webTouchPad = isOn;
              this.persistWebConfig();
            })
          }
        }

        ListItem() {
          Text('配置在下次启动该引擎的游戏时生效。')
            .fontSize(12)
            .fontColor(AppTheme.textTertiary)
            .width('100%')
            .padding({ left: AppTheme.pagePadding, right: AppTheme.pagePadding, top: 4 })
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
  switchRow(title: string, detail: string, isOn: boolean, onChange: (isOn: boolean) => void) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(title)
          .fontSize(16)
          .fontColor(AppTheme.textPrimary)
        Text(detail)
          .fontSize(12)
          .fontColor(AppTheme.textTertiary)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor(this.themePrimary)
        .onChange((value: boolean) => {
          onChange(value);
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

  @Builder
  portRow() {
    Column({ space: 6 }) {
      Row({ space: 12 }) {
        Text('Web 服务端口')
          .fontSize(16)
          .fontColor(AppTheme.textPrimary)
          .layoutWeight(1)

        TextInput({ text: this.webPortText })
          .type(InputType.Number)
          .maxLength(5)
          .width(84)
          .height(36)
          .fontSize(14)
          .fontColor(this.themePrimary)
          .textAlign(TextAlign.Center)
          .caretColor(this.themePrimary)
          .backgroundColor(AppTheme.surfaceAlt)
          .borderRadius(AppTheme.radiusS)
          .onChange((value: string) => {
            this.webPortText = KernelView.filterPortDigits(value);
          })
          .onSubmit(() => {
            this.commitWebPort();
          })
          .onBlur(() => {
            this.commitWebPort();
          })
      }
      .width('100%')

      Text(`固定端口（默认 ${WebEngineConfig.DEFAULT_PORT}）保证网页存档域稳定；改动后旧存档可能不再可见`)
        .fontSize(12)
        .fontColor(AppTheme.textTertiary)
        .width('100%')
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

  private openEngineSheet(engineId: string): void {
    this.activeEngineId = engineId;
    if (engineId !== 'artemis') {
      const config = SettingsStore.webConfig(engineId);
      this.webOrientation = config.orientation;
      this.webNetwork = config.network;
      this.webVolume = config.volume;
      this.webTouchPad = config.touchPad;
      this.webPort = config.port;
      this.webPortText = `${config.port}`;
    }
    this.showEngineSheet = true;
  }

  private commitWebPort(): void {
    const parsed = parseInt(this.webPortText, 10);
    const port = SettingsStore.normalizeWebPort(isNaN(parsed) ? 0 : parsed);
    this.webPort = port;
    this.webPortText = `${port}`;
    this.persistWebConfig();
  }

  private static filterPortDigits(value: string): string {
    let digits = '';
    for (let i = 0; i < value.length && digits.length < 5; i++) {
      const ch = value.charAt(i);
      if (ch >= '0' && ch <= '9') {
        digits += ch;
      }
    }
    return digits;
  }

  private persistWebConfig(): void {
    const config = new WebEngineConfig();
    config.orientation = this.webOrientation;
    config.network = this.webNetwork;
    config.volume = this.webVolume;
    config.touchPad = this.webTouchPad;
    config.port = this.webPort;
    SettingsStore.setWebConfig(this.activeEngineId, config);
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
            .fontColor(this.themePrimary)
          SymbolGlyph(this.expandedKind === kind
            ? $r('sys.symbol.chevron_compact_up')
            : $r('sys.symbol.chevron_compact_down'))
            .fontSize(14)
            .fontColor([this.themePrimary])
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
          } else if (kind === 'webOrientation') {
            this.optionRow('固定横屏', this.webOrientation === '固定横屏', () => {
              this.pickValue('webOrientation', '固定横屏');
            })
            this.optionRow('自动旋转', this.webOrientation === '自动旋转', () => {
              this.pickValue('webOrientation', '自动旋转');
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
          .fontColor([this.themePrimary])
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
    if (kind === 'webOrientation') {
      this.webOrientation = value;
      this.persistWebConfig();
      this.expandedKind = '';
      return;
    }
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
    if (kind === 'webOrientation') {
      return this.webOrientation;
    }
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
