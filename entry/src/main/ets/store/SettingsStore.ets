import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x4D45;
const TAG: string = 'SettingsStore';
const PREF_NAME: string = 'mermaid_settings';

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
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'init failed: %{public}s', JSON.stringify(err));
    }
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
