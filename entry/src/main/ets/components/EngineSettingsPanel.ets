import { AppTheme } from '../common/Theme';
import { GameEngineConfig, SettingsStore, WebEngineConfig } from '../store/SettingsStore';
import { SettingRow } from './SettingRow';

@Component
export struct EngineSettingsPanel {
  @Prop @Watch('reload') engineId: string = 'artemis';
  @Prop @Watch('reload') gameId: string = '';
  showBack: boolean = false;
  onBack: () => void = () => {
  };
  @StorageLink('themePrimary') themePrimary: string = AppTheme.primaryDefault;
  @State expandedKind: string = '';
  @State osValue: string = 'windows';
  @State scaleValue: string = '跟随游戏';
  @State orientationValue: string = '固定横屏';
  @State vsyncValue: boolean = true;
  @State networkValue: boolean = true;
  @State volumeValue: number = 100;
  @State touchPadValue: boolean = false;
  @State portText: string = `${WebEngineConfig.DEFAULT_PORT}`;
  @State overrides: GameEngineConfig = new GameEngineConfig();

  aboutToAppear(): void {
    this.reload();
  }

  build() {
    Column() {
      List({ space: 8 }) {
        if (this.showBack) {
          ListItem() {
            SettingRow({
              icon: $r('sys.symbol.chevron_left'),
              title: '返回游戏操作',
              radius: AppTheme.radiusM,
              onTap: () => {
                this.onBack();
              }
            })
          }
        }

        if (this.engineId === 'artemis') {
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
            if (this.isGameScope()) {
              this.paramRow('垂直同步', 'vsync')
            } else {
              this.switchRow('垂直同步', '限制帧率与画面撕裂', this.vsyncValue, (isOn: boolean) => {
                this.toggleGlobal('vsync', isOn);
              })
            }
          }
        } else {
          ListItem() {
            this.paramRow('屏幕方向', 'orientation')
          }

          ListItem() {
            this.paramRow('Web 服务端口', 'port')
          }

          ListItem() {
            if (this.isGameScope()) {
              this.paramRow('外部网络', 'network')
            } else {
              this.switchRow('外部网络', '允许游戏访问外部网络资源', this.networkValue, (isOn: boolean) => {
                this.toggleGlobal('network', isOn);
              })
            }
          }

          ListItem() {
            if (this.isGameScope()) {
              this.paramRow('运行音量', 'volume')
            } else {
              this.volumeRow()
            }
          }

          if (this.engineId === 'rpgm_mv' || this.engineId === 'rpgm_mz') {
            ListItem() {
              if (this.isGameScope()) {
                this.paramRow('触屏手柄', 'touchPad')
              } else {
                this.switchRow('触屏手柄', '虚拟摇杆与动作按键', this.touchPadValue, (isOn: boolean) => {
                  this.toggleGlobal('touchPad', isOn);
                })
              }
            }
          }
        }

        ListItem() {
          Text(this.isGameScope() ? '未设置的参数跟随全局，配置在下次启动该游戏时生效。' : '配置在下次启动该引擎的游戏时生效。')
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

  private reload(): void {
    this.expandedKind = '';
    this.overrides = SettingsStore.gameEngineConfig(this.gameId);
    this.applyEffective();
  }

  private applyEffective(): void {
    if (this.engineId === 'artemis') {
      const config = SettingsStore.artemisConfig(this.gameId);
      this.osValue = config.osId;
      this.scaleValue = config.scale;
      this.orientationValue = config.orientation;
      this.vsyncValue = config.vsync;
      return;
    }
    const config = SettingsStore.webConfigFor(this.gameId, this.engineId);
    this.orientationValue = config.orientation;
    this.networkValue = config.network;
    this.volumeValue = config.volume;
    this.touchPadValue = config.touchPad;
    this.portText = `${config.port}`;
  }

  private isGameScope(): boolean {
    return this.gameId.length > 0;
  }

  private currentValue(kind: string): string {
    if (kind === 'os') {
      return this.osValue;
    }
    if (kind === 'scale') {
      return this.scaleValue;
    }
    if (kind === 'orientation') {
      return this.orientationValue;
    }
    if (kind === 'vsync') {
      return this.vsyncValue ? 'true' : 'false';
    }
    if (kind === 'network') {
      return this.networkValue ? 'true' : 'false';
    }
    if (kind === 'touchPad') {
      return this.touchPadValue ? 'true' : 'false';
    }
    if (kind === 'volume') {
      return `${Math.round(this.volumeValue)}`;
    }
    return `${SettingsStore.normalizeWebPort(this.parsedPort())}`;
  }

  private overrideValue(kind: string): string {
    if (kind === 'os') {
      return this.overrides.os;
    }
    if (kind === 'scale') {
      return this.overrides.scale;
    }
    if (kind === 'orientation') {
      return this.overrides.orientation;
    }
    if (kind === 'vsync') {
      return this.overrides.vsync;
    }
    if (kind === 'network') {
      return this.overrides.network;
    }
    if (kind === 'touchPad') {
      return this.overrides.touchPad;
    }
    if (kind === 'volume') {
      return this.overrides.volume;
    }
    return this.overrides.port;
  }

  private setOverride(kind: string, value: string): void {
    if (kind === 'os') {
      this.overrides.os = value;
    } else if (kind === 'scale') {
      this.overrides.scale = value;
    } else if (kind === 'orientation') {
      this.overrides.orientation = value;
    } else if (kind === 'vsync') {
      this.overrides.vsync = value;
    } else if (kind === 'network') {
      this.overrides.network = value;
    } else if (kind === 'touchPad') {
      this.overrides.touchPad = value;
    } else if (kind === 'volume') {
      this.overrides.volume = value;
    } else {
      this.overrides.port = value;
    }
  }

  private globalValue(kind: string): string {
    if (this.engineId === 'artemis') {
      const config = SettingsStore.artemisConfig('');
      if (kind === 'os') {
        return config.osId;
      }
      if (kind === 'scale') {
        return config.scale;
      }
      if (kind === 'orientation') {
        return config.orientation;
      }
      return config.vsync ? 'true' : 'false';
    }
    const config = SettingsStore.webConfig(this.engineId);
    if (kind === 'orientation') {
      return config.orientation;
    }
    if (kind === 'network') {
      return config.network ? 'true' : 'false';
    }
    if (kind === 'touchPad') {
      return config.touchPad ? 'true' : 'false';
    }
    if (kind === 'volume') {
      return `${config.volume}`;
    }
    return `${config.port}`;
  }

  private optionValues(kind: string): string[] {
    if (kind === 'os') {
      return ['windows', 'android', 'ios'];
    }
    if (kind === 'scale') {
      return ['跟随游戏', '保持比例', '铺满裁剪'];
    }
    if (kind === 'vsync' || kind === 'network' || kind === 'touchPad') {
      return ['true', 'false'];
    }
    return ['固定横屏', '自动旋转'];
  }

  private valueLabel(kind: string, value: string): string {
    if (kind === 'os') {
      if (value === 'android') {
        return 'Android';
      }
      if (value === 'ios') {
        return 'iOS';
      }
      if (value === 'windows') {
        return 'Windows';
      }
      return value;
    }
    if (kind === 'vsync' || kind === 'network' || kind === 'touchPad') {
      return value === 'true' ? '开启' : '关闭';
    }
    if (kind === 'volume') {
      const volume = parseInt(value, 10);
      return `${isNaN(volume) ? 100 : volume}%`;
    }
    return value;
  }

  private paramLabel(kind: string): string {
    if (this.isGameScope()) {
      const value = this.overrideValue(kind);
      return value.length > 0 ? this.valueLabel(kind, value) : '跟随全局';
    }
    return this.valueLabel(kind, this.currentValue(kind));
  }

  private isOptionSelected(kind: string, value: string): boolean {
    if (this.isGameScope()) {
      return this.overrideValue(kind) === value;
    }
    return this.currentValue(kind) === value;
  }

  private pickOption(kind: string, value: string): void {
    if (this.isGameScope()) {
      this.setOverride(kind, value);
      SettingsStore.setGameEngineConfig(this.gameId, this.overrides);
      this.applyEffective();
      this.expandedKind = '';
      return;
    }
    if (kind === 'os') {
      this.osValue = value;
      SettingsStore.setString('stg_engineOs', value);
    } else if (kind === 'scale') {
      this.scaleValue = value;
      SettingsStore.setString('stg_engineScale', value);
    } else if (kind === 'orientation') {
      this.orientationValue = value;
      if (this.engineId === 'artemis') {
        SettingsStore.setString('stg_engineOrientation', value);
      } else {
        this.persistWebGlobal();
      }
    } else if (kind === 'vsync') {
      this.vsyncValue = value === 'true';
      SettingsStore.setBool('stg_engineVsync', this.vsyncValue);
    } else if (kind === 'network') {
      this.networkValue = value === 'true';
      this.persistWebGlobal();
    } else if (kind === 'touchPad') {
      this.touchPadValue = value === 'true';
      this.persistWebGlobal();
    }
    this.expandedKind = '';
  }

  private toggleGlobal(kind: string, isOn: boolean): void {
    if (kind === 'vsync') {
      this.vsyncValue = isOn;
      SettingsStore.setBool('stg_engineVsync', isOn);
      return;
    }
    if (kind === 'network') {
      this.networkValue = isOn;
    } else {
      this.touchPadValue = isOn;
    }
    this.persistWebGlobal();
  }

  private persistWebGlobal(): void {
    const config = new WebEngineConfig();
    config.orientation = this.orientationValue;
    config.network = this.networkValue;
    config.volume = Math.round(this.volumeValue);
    config.touchPad = this.touchPadValue;
    config.port = SettingsStore.normalizeWebPort(this.parsedPort());
    SettingsStore.setWebConfig(this.engineId, config);
  }

  private onVolumeChange(value: number): void {
    this.volumeValue = value;
    if (this.isGameScope()) {
      this.setOverride('volume', `${Math.round(value)}`);
      SettingsStore.setGameEngineConfig(this.gameId, this.overrides);
      return;
    }
    this.persistWebGlobal();
  }

  private parsedPort(): number {
    const parsed = parseInt(this.portText, 10);
    return isNaN(parsed) ? 0 : parsed;
  }

  private commitPort(): void {
    if (this.isGameScope()) {
      if (this.portText.length === 0) {
        this.setOverride('port', '');
      } else {
        const parsed = parseInt(this.portText, 10);
        if (!isNaN(parsed) && parsed >= WebEngineConfig.MIN_PORT && parsed <= WebEngineConfig.MAX_PORT) {
          this.setOverride('port', `${parsed}`);
        }
      }
      SettingsStore.setGameEngineConfig(this.gameId, this.overrides);
      this.applyEffective();
      return;
    }
    const port = SettingsStore.normalizeWebPort(this.parsedPort());
    this.portText = `${port}`;
    this.persistWebGlobal();
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

  @Builder
  paramRow(title: string, kind: string) {
    Column() {
      Row() {
        Text(title)
          .fontSize(16)
          .fontColor(AppTheme.textPrimary)
          .layoutWeight(1)

        Row({ space: 2 }) {
          Text(this.paramLabel(kind))
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
          if (this.isGameScope()) {
            this.optionRow(`跟随全局（${this.valueLabel(kind, this.globalValue(kind))}）`,
              this.overrideValue(kind).length === 0, () => {
                this.pickOption(kind, '');
              })
          }
          if (kind === 'volume') {
            this.volumeEditor()
          } else if (kind === 'port') {
            this.portEditor()
          } else {
            ForEach(this.optionValues(kind), (value: string) => {
              this.optionRow(this.valueLabel(kind, value), this.isOptionSelected(kind, value), () => {
                this.pickOption(kind, value);
              })
            }, (value: string) => value)
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

  @Builder
  volumeEditor() {
    Row({ space: 12 }) {
      Slider({ value: this.volumeValue, min: 0, max: 100, step: 1 })
        .layoutWeight(1)
        .selectedColor(this.themePrimary)
        .onChange((value: number) => {
          this.onVolumeChange(value);
        })
      Text(`${Math.round(this.volumeValue)}%`)
        .fontSize(13)
        .fontColor(AppTheme.textSecondary)
        .width(46)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
  }

  @Builder
  portEditor() {
    Column({ space: 6 }) {
      TextInput({ text: this.portText })
        .type(InputType.Number)
        .maxLength(5)
        .width('100%')
        .height(36)
        .fontSize(14)
        .fontColor(this.themePrimary)
        .textAlign(TextAlign.Center)
        .caretColor(this.themePrimary)
        .backgroundColor(AppTheme.surfaceAlt)
        .borderRadius(AppTheme.radiusS)
        .onChange((value: string) => {
          this.portText = EngineSettingsPanel.filterPortDigits(value);
        })
        .onSubmit(() => {
          this.commitPort();
        })
        .onBlur(() => {
          this.commitPort();
        })

      Text(this.isGameScope()
        ? `固定端口（默认 ${WebEngineConfig.DEFAULT_PORT}）保证网页存档域稳定；留空并确认可跟随全局`
        : `固定端口（默认 ${WebEngineConfig.DEFAULT_PORT}）保证网页存档域稳定；改动后旧存档可能不再可见`)
        .fontSize(12)
        .fontColor(AppTheme.textTertiary)
        .width('100%')
    }
    .width('100%')
    .padding({ top: 4 })
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
  volumeRow() {
    Row({ space: 12 }) {
      Text('音量')
        .fontSize(16)
        .fontColor(AppTheme.textPrimary)
      Slider({ value: this.volumeValue, min: 0, max: 100, step: 1 })
        .layoutWeight(1)
        .selectedColor(this.themePrimary)
        .onChange((value: number) => {
          this.onVolumeChange(value);
        })
      Text(`${Math.round(this.volumeValue)}%`)
        .fontSize(13)
        .fontColor(AppTheme.textSecondary)
        .width(46)
        .textAlign(TextAlign.End)
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
