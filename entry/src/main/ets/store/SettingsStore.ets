import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x4D45;
const TAG: string = 'SettingsStore';
const PREF_NAME: string = 'mermaid_settings';

export class WebEngineConfig {
  static readonly DEFAULT_PORT: number = 23333;
  static readonly MIN_PORT: number = 1;
  static readonly MAX_PORT: number = 65535;
  orientation: string = '固定横屏';
  network: boolean = true;
  volume: number = 100;
  touchPad: boolean = false;
  port: number = WebEngineConfig.DEFAULT_PORT;
}

export class GameEngineConfig {
  os: string = '';
  scale: string = '';
  orientation: string = '';
  vsync: string = '';
  network: string = '';
  volume: string = '';
  port: string = '';
  touchPad: string = '';
}

export class ArtemisConfig {
  osId: string = 'windows';
  scale: string = '跟随游戏';
  orientation: string = '固定横屏';
  vsync: boolean = true;
}

export class SettingsStore {
  private static pref: preferences.Preferences | null = null;

  static init(context: Context): void {
    if (SettingsStore.pref !== null) {
      return;
    }
    try {
      SettingsStore.pref = preferences.getPreferencesSync(context, { name: PREF_NAME });
      AppStorage.setOrCreate<boolean>('stg_autoCore', SettingsStore.readBool('stg_autoCore', true));
      AppStorage.setOrCreate<boolean>('stg_copyImport', SettingsStore.readBool('stg_copyImport', true));
      AppStorage.setOrCreate<string>('stg_defaultCore', SettingsStore.readString('stg_defaultCore', 'artemis'));
      AppStorage.setOrCreate<string>('stg_resolution', SettingsStore.readString('stg_resolution', '跟随原始分辨率'));
      AppStorage.setOrCreate<string>('stg_fps', SettingsStore.readString('stg_fps', '60 FPS'));
      AppStorage.setOrCreate<string>('stg_scaleMode', SettingsStore.readString('stg_scaleMode', '保持比例'));
      AppStorage.setOrCreate<number>('stg_volume', SettingsStore.readNumber('stg_volume', 70));
      AppStorage.setOrCreate<boolean>('stg_coverVndb', SettingsStore.readBool('stg_coverVndb', true));
      AppStorage.setOrCreate<boolean>('stg_coverSteam', SettingsStore.readBool('stg_coverSteam', true));
      AppStorage.setOrCreate<boolean>('stg_coverBangumi', SettingsStore.readBool('stg_coverBangumi', true));
      AppStorage.setOrCreate<boolean>('stg_coverOnlyMissing', SettingsStore.readBool('stg_coverOnlyMissing', true));
      AppStorage.setOrCreate<string>('stg_engineOs', SettingsStore.readString('stg_engineOs', 'windows'));
      AppStorage.setOrCreate<string>('stg_engineScale', SettingsStore.readString('stg_engineScale', '跟随游戏'));
      AppStorage.setOrCreate<string>('stg_engineOrientation', SettingsStore.readString('stg_engineOrientation', '固定横屏'));
      AppStorage.setOrCreate<boolean>('stg_engineVsync', SettingsStore.readBool('stg_engineVsync', true));
      AppStorage.setOrCreate<string>('themePrimary', SettingsStore.readString('stg_themeColor', '#0E8BD3'));
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'init failed: %{public}s', JSON.stringify(err));
    }
  }

  static webConfig(engineId: string): WebEngineConfig {
    const config = new WebEngineConfig();
    config.touchPad = engineId === 'rpgm_mv' || engineId === 'rpgm_mz';
    const pref = SettingsStore.pref;
    if (pref === null) {
      return config;
    }
    try {
      const raw = pref.getSync(`stg_web_${engineId}`, '');
      const text = typeof raw === 'string' ? raw : '';
      if (text.length === 0) {
        return config;
      }
      const parsed = JSON.parse(text) as WebEngineConfig;
      if (typeof parsed.orientation === 'string') {
        config.orientation = parsed.orientation;
      }
      if (typeof parsed.network === 'boolean') {
        config.network = parsed.network;
      }
      if (typeof parsed.volume === 'number') {
        config.volume = parsed.volume;
      }
      if (typeof parsed.touchPad === 'boolean') {
        config.touchPad = parsed.touchPad;
      }
      if (typeof parsed.port === 'number') {
        config.port = SettingsStore.normalizeWebPort(parsed.port);
      }
    } catch (err) {
      return config;
    }
    return config;
  }

  static normalizeWebPort(value: number): number {
    if (value >= WebEngineConfig.MIN_PORT && value <= WebEngineConfig.MAX_PORT &&
      Math.floor(value) === value) {
      return value;
    }
    return WebEngineConfig.DEFAULT_PORT;
  }

  static gameEngineConfig(gameId: string): GameEngineConfig {
    const config = new GameEngineConfig();
    const pref = SettingsStore.pref;
    if (pref === null || gameId.length === 0) {
      return config;
    }
    try {
      const raw = pref.getSync(`stg_game_${gameId}`, '');
      const text = typeof raw === 'string' ? raw : '';
      if (text.length === 0) {
        return config;
      }
      const parsed = JSON.parse(text) as GameEngineConfig;
      if (typeof parsed.os === 'string') {
        config.os = parsed.os;
      }
      if (typeof parsed.scale === 'string') {
        config.scale = parsed.scale;
      }
      if (typeof parsed.orientation === 'string') {
        config.orientation = parsed.orientation;
      }
      if (typeof parsed.vsync === 'string') {
        config.vsync = parsed.vsync;
      }
      if (typeof parsed.network === 'string') {
        config.network = parsed.network;
      }
      if (typeof parsed.volume === 'string') {
        config.volume = parsed.volume;
      }
      if (typeof parsed.port === 'string') {
        config.port = parsed.port;
      }
      if (typeof parsed.touchPad === 'string') {
        config.touchPad = parsed.touchPad;
      }
    } catch (err) {
      return config;
    }
    return config;
  }

  static setGameEngineConfig(gameId: string, config: GameEngineConfig): void {
    const pref = SettingsStore.pref;
    if (pref === null || gameId.length === 0) {
      return;
    }
    try {
      pref.putSync(`stg_game_${gameId}`, JSON.stringify(config));
      pref.flush((err) => {
        if (err) {
          hilog.warn(DOMAIN, TAG, 'game engine config flush failed: %{public}s', JSON.stringify(err));
        }
      });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'game engine config persist failed: %{public}s', JSON.stringify(err));
    }
  }

  static artemisConfig(gameId: string): ArtemisConfig {
    const config = new ArtemisConfig();
    config.osId = AppStorage.get<string>('stg_engineOs') ?? 'windows';
    config.scale = AppStorage.get<string>('stg_engineScale') ?? '跟随游戏';
    config.orientation = AppStorage.get<string>('stg_engineOrientation') ?? '固定横屏';
    config.vsync = AppStorage.get<boolean>('stg_engineVsync') ?? true;
    const overrides = SettingsStore.gameEngineConfig(gameId);
    if (overrides.os.length > 0) {
      config.osId = overrides.os;
    }
    if (overrides.scale.length > 0) {
      config.scale = overrides.scale;
    }
    if (overrides.orientation.length > 0) {
      config.orientation = overrides.orientation;
    }
    if (overrides.vsync === 'true' || overrides.vsync === 'false') {
      config.vsync = overrides.vsync === 'true';
    }
    return config;
  }

  static webConfigFor(gameId: string, engineId: string): WebEngineConfig {
    const config = SettingsStore.webConfig(engineId);
    const overrides = SettingsStore.gameEngineConfig(gameId);
    if (overrides.orientation === '固定横屏' || overrides.orientation === '自动旋转') {
      config.orientation = overrides.orientation;
    }
    if (overrides.network === 'true' || overrides.network === 'false') {
      config.network = overrides.network === 'true';
    }
    if (overrides.touchPad === 'true' || overrides.touchPad === 'false') {
      config.touchPad = overrides.touchPad === 'true';
    }
    const volume = parseInt(overrides.volume, 10);
    if (!isNaN(volume) && volume >= 0 && volume <= 100) {
      config.volume = volume;
    }
    const port = parseInt(overrides.port, 10);
    if (!isNaN(port) && port >= WebEngineConfig.MIN_PORT && port <= WebEngineConfig.MAX_PORT) {
      config.port = port;
    }
    return config;
  }

  static setWebConfig(engineId: string, config: WebEngineConfig): void {
    const pref = SettingsStore.pref;
    if (pref === null) {
      return;
    }
    try {
      pref.putSync(`stg_web_${engineId}`, JSON.stringify(config));
      pref.flush((err) => {
        if (err) {
          hilog.warn(DOMAIN, TAG, 'web config flush failed: %{public}s', JSON.stringify(err));
        }
      });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'web config persist failed: %{public}s', JSON.stringify(err));
    }
  }

  static setThemeColor(color: string): void {
    AppStorage.setOrCreate<string>('themePrimary', color);
    SettingsStore.persist();
  }

  static setString(key: string, value: string): void {
    AppStorage.setOrCreate<string>(key, value);
    SettingsStore.persist();
  }

  static setBool(key: string, value: boolean): void {
    AppStorage.setOrCreate<boolean>(key, value);
    SettingsStore.persist();
  }

  static persist(): void {
    const pref = SettingsStore.pref;
    if (pref === null) {
      return;
    }
    try {
      pref.putSync('stg_autoCore', AppStorage.get<boolean>('stg_autoCore') ?? true);
      pref.putSync('stg_copyImport', AppStorage.get<boolean>('stg_copyImport') ?? true);
      pref.putSync('stg_defaultCore', AppStorage.get<string>('stg_defaultCore') ?? 'artemis');
      pref.putSync('stg_resolution', AppStorage.get<string>('stg_resolution') ?? '跟随原始分辨率');
      pref.putSync('stg_fps', AppStorage.get<string>('stg_fps') ?? '60 FPS');
      pref.putSync('stg_scaleMode', AppStorage.get<string>('stg_scaleMode') ?? '保持比例');
      pref.putSync('stg_volume', AppStorage.get<number>('stg_volume') ?? 70);
      pref.putSync('stg_coverVndb', AppStorage.get<boolean>('stg_coverVndb') ?? true);
      pref.putSync('stg_coverSteam', AppStorage.get<boolean>('stg_coverSteam') ?? true);
      pref.putSync('stg_coverBangumi', AppStorage.get<boolean>('stg_coverBangumi') ?? true);
      pref.putSync('stg_coverOnlyMissing', AppStorage.get<boolean>('stg_coverOnlyMissing') ?? true);
      pref.putSync('stg_engineOs', AppStorage.get<string>('stg_engineOs') ?? 'windows');
      pref.putSync('stg_engineScale', AppStorage.get<string>('stg_engineScale') ?? '跟随游戏');
      pref.putSync('stg_engineOrientation', AppStorage.get<string>('stg_engineOrientation') ?? '固定横屏');
      pref.putSync('stg_engineVsync', AppStorage.get<boolean>('stg_engineVsync') ?? true);
      pref.putSync('stg_themeColor', AppStorage.get<string>('themePrimary') ?? '#0E8BD3');
      pref.flush((err) => {
        if (err) {
          hilog.warn(DOMAIN, TAG, 'flush failed: %{public}s', JSON.stringify(err));
        }
      });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'persist failed: %{public}s', JSON.stringify(err));
    }
  }

  private static readBool(key: string, defValue: boolean): boolean {
    const pref = SettingsStore.pref;
    if (pref === null) {
      return defValue;
    }
    const value = pref.getSync(key, defValue);
    return typeof value === 'boolean' ? value : defValue;
  }

  private static readString(key: string, defValue: string): string {
    const pref = SettingsStore.pref;
    if (pref === null) {
      return defValue;
    }
    const value = pref.getSync(key, defValue);
    return typeof value === 'string' ? value : defValue;
  }

  private static readNumber(key: string, defValue: number): number {
    const pref = SettingsStore.pref;
    if (pref === null) {
      return defValue;
    }
    const value = pref.getSync(key, defValue);
    return typeof value === 'number' ? value : defValue;
  }
}
