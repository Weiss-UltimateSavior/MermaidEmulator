import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x4D45;
const TAG: string = 'TyranoStore';
const MAX_SAVE_BYTES: number = 8 * 1024 * 1024;
const MAX_KEY_CHARS: number = 512;

export class TyranoStore {
  static read(saveDir: string, key: string): string {
    const path = TyranoStore.resolveFile(saveDir, key);
    if (path.length === 0) {
      return '';
    }
    try {
      if (!fileIo.accessSync(path)) {
        return '';
      }
      const stat = fileIo.statSync(path);
      if (stat.size <= 0 || stat.size > MAX_SAVE_BYTES) {
        return '';
      }
      return fileIo.readTextSync(path);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'getStorage failed key=%{public}s: %{public}s', String(key),
        JSON.stringify(err));
      return '';
    }
  }

  static write(saveDir: string, key: string, value: string): void {
    const path = TyranoStore.resolveFile(saveDir, key);
    if (path.length === 0) {
      return;
    }
    try {
      const file = fileIo.openSync(path,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(file.fd, value);
      } finally {
        fileIo.closeSync(file);
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'setStorage failed key=%{public}s: %{public}s', String(key),
        JSON.stringify(err));
    }
  }

  static resolveFile(saveDir: string, key: string): string {
    if (saveDir.length === 0 || key === undefined || key === null) {
      return '';
    }
    const clean = key.trim();
    if (clean.length === 0 || clean.length > MAX_KEY_CHARS) {
      return '';
    }
    if (clean.includes('/') || clean.includes('\\') || clean.includes('..')) {
      return '';
    }
    const direct = clean.match(/^[A-Za-z0-9._-]{1,128}$/);
    const name = direct !== null ? clean : `key_${TyranoStore.hash(clean)}`;
    return `${saveDir}/${name}.sav`;
  }

  private static hash(value: string): string {
    let first = 0x811c9dc5;
    let second = 0x01000193;
    for (let index = 0; index < value.length; index++) {
      const code = value.charCodeAt(index);
      first = (Math.imul(first ^ code, 16777619)) >>> 0;
      second = (Math.imul(second + code * (index + 1), 31)) >>> 0;
    }
    return `${TyranoStore.padHex(first)}${TyranoStore.padHex(second)}`;
  }

  private static padHex(value: number): string {
    let text = value.toString(16);
    while (text.length < 8) {
      text = `0${text}`;
    }
    return text;
  }
}
