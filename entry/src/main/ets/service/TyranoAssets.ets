import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';

const DOMAIN: number = 0x4D45;
const TAG: string = 'TyranoAssets';
const MAX_ASAR_HEADER_BYTES: number = 16 * 1024 * 1024;
const MAX_ENTRY_BYTES: number = 256 * 1024 * 1024;

class AsarEntry {
  directory: boolean = false;
  size: number = 0;
  offset: number = 0;
}

interface AsarHeaderFile {
  size?: string;
  offset?: string;
  files?: Record<string, AsarHeaderFile>;
}

export class TyranoEntry {
  contentRoot: string = '';
  asarPath: string = '';

  constructor(contentRoot: string, asarPath: string) {
    this.contentRoot = contentRoot;
    this.asarPath = asarPath;
  }
}

export class TyranoAssets {
  private static readonly SUB_DIRS: string[] = [
    'www', 'resources', 'app.asar', 'app', 'tyrano', 'data', 'scenario', 'system', 'game'
  ];
  private static readonly MAX_ENTRY_DEPTH: number = 2;

  private entry: TyranoEntry;
  private asarEntries: Map<string, AsarEntry> = new Map();
  private asarDataOffset: number = 0;
  private asarReady: boolean = false;

  constructor(entry: TyranoEntry) {
    this.entry = entry;
  }

  static find(gamePath: string): TyranoAssets | null {
    const entry = TyranoAssets.search(TyranoAssets.trimTrailingSlash(gamePath), 0);
    if (entry === null) {
      return null;
    }
    const assets = new TyranoAssets(entry);
    if (entry.asarPath.length > 0 && !assets.openAsar()) {
      return null;
    }
    return assets;
  }

  exists(relativePath: string): boolean {
    const normalized = TyranoAssets.normalize(relativePath);
    if (normalized.length === 0) {
      return false;
    }
    if (this.entry.asarPath.length > 0) {
      const item = this.asarEntries.get(normalized);
      return item !== undefined && !item.directory;
    }
    const path = `${this.entry.contentRoot}/${normalized}`;
    try {
      return fileIo.accessSync(path) && !fileIo.statSync(path).isDirectory();
    } catch (err) {
      return false;
    }
  }

  sizeOf(relativePath: string): number {
    const normalized = TyranoAssets.normalize(relativePath);
    if (this.entry.asarPath.length > 0) {
      const item = this.asarEntries.get(normalized);
      return item !== undefined && !item.directory ? item.size : -1;
    }
    try {
      const stat = fileIo.statSync(`${this.entry.contentRoot}/${normalized}`);
      return stat.isDirectory() ? -1 : stat.size;
    } catch (err) {
      return -1;
    }
  }

  read(relativePath: string, offset: number, length: number): ArrayBuffer | null {
    const normalized = TyranoAssets.normalize(relativePath);
    if (normalized.length === 0) {
      return null;
    }
    const total = this.sizeOf(normalized);
    if (total < 0) {
      return null;
    }
    const start = offset < 0 ? 0 : offset;
    const want = length < 0 ? total - start : Math.min(length, total - start);
    if (want <= 0) {
      return null;
    }
    try {
      if (this.entry.asarPath.length > 0) {
        const item = this.asarEntries.get(normalized);
        if (item === undefined) {
          return null;
        }
        return TyranoAssets.readFileRange(this.entry.asarPath, this.asarDataOffset + item.offset + start, want);
      }
      return TyranoAssets.readFileRange(`${this.entry.contentRoot}/${normalized}`, start, want);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'read failed path=%{public}s: %{public}s', normalized, JSON.stringify(err));
      return null;
    }
  }

  private openAsar(): boolean {
    const path = this.entry.asarPath;
    let file: fileIo.File | null = null;
    try {
      const stat = fileIo.statSync(path);
      file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      const head = new ArrayBuffer(16);
      fileIo.readSync(file.fd, head);
      const view = new DataView(head);
      const magic = view.getUint32(0, true);
      const headerSize = view.getUint32(4, true);
      if (magic !== 4 || headerSize < 8 || headerSize > MAX_ASAR_HEADER_BYTES ||
        headerSize + 8 > stat.size) {
        return false;
      }
      const jsonLength = view.getUint32(12, true);
      if (jsonLength <= 0 || jsonLength > headerSize) {
        return false;
      }
      const jsonBuffer = new ArrayBuffer(jsonLength);
      fileIo.readSync(file.fd, jsonBuffer);
      this.asarDataOffset = 8 + headerSize;
      const header = JSON.parse(TyranoAssets.decodeUtf8(jsonBuffer)) as AsarHeaderFile;
      this.parseAsarNode('', header);
      this.asarReady = true;
      hilog.info(DOMAIN, TAG, 'asar loaded entries=%{public}d', this.asarEntries.size);
      return true;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'asar open failed: %{public}s', JSON.stringify(err));
      return false;
    } finally {
      if (file !== null) {
        fileIo.closeSync(file);
      }
    }
  }

  private parseAsarNode(prefix: string, node: AsarHeaderFile): void {
    const files = node.files;
    if (files === undefined) {
      if (prefix.length > 0) {
        const entry = new AsarEntry();
        entry.directory = false;
        entry.size = parseInt(node.size ?? '0', 10);
        entry.offset = parseInt(node.offset ?? '0', 10);
        this.asarEntries.set(TyranoAssets.normalize(prefix), entry);
      }
      return;
    }
    if (prefix.length > 0) {
      const dir = new AsarEntry();
      dir.directory = true;
      this.asarEntries.set(TyranoAssets.normalize(prefix), dir);
    }
    Object.keys(files).forEach((name: string) => {
      const child = files[name];
      const next = prefix.length === 0 ? name : `${prefix}/${name}`;
      this.parseAsarNode(next, child);
    });
  }

  private static search(dir: string, depth: number): TyranoEntry | null {
    const rootAsar = `${dir}/app.asar`;
    if (TyranoAssets.isFile(rootAsar)) {
      return new TyranoEntry(dir, rootAsar);
    }
    const resourcesAsar = `${dir}/resources/app.asar`;
    if (TyranoAssets.isFile(resourcesAsar)) {
      return new TyranoEntry(dir, resourcesAsar);
    }
    if (TyranoAssets.isDirectory(rootAsar) && TyranoAssets.isFile(`${rootAsar}/index.html`)) {
      return new TyranoEntry(rootAsar, '');
    }
    if (TyranoAssets.isDirectory(resourcesAsar) &&
      TyranoAssets.isFile(`${resourcesAsar}/index.html`)) {
      return new TyranoEntry(resourcesAsar, '');
    }
    if (TyranoAssets.isFile(`${dir}/index.html`)) {
      return new TyranoEntry(dir, '');
    }
    if (depth >= TyranoAssets.MAX_ENTRY_DEPTH) {
      return null;
    }
    for (const name of TyranoAssets.SUB_DIRS) {
      const sub = `${dir}/${name}`;
      if (TyranoAssets.isDirectory(sub)) {
        const hit = TyranoAssets.search(sub, depth + 1);
        if (hit !== null) {
          return hit;
        }
      }
    }
    return null;
  }

  static mimeOf(path: string): string {
    const lower = path.toLowerCase();
    if (lower.endsWith('.html') || lower.endsWith('.htm')) {
      return 'text/html; charset=utf-8';
    }
    if (lower.endsWith('.js') || lower.endsWith('.mjs')) {
      return 'application/javascript; charset=utf-8';
    }
    if (lower.endsWith('.css')) {
      return 'text/css; charset=utf-8';
    }
    if (lower.endsWith('.json')) {
      return 'application/json; charset=utf-8';
    }
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.svg')) {
      return 'image/svg+xml';
    }
    if (lower.endsWith('.mp3')) {
      return 'audio/mpeg';
    }
    if (lower.endsWith('.ogg') || lower.endsWith('.oga')) {
      return 'audio/ogg';
    }
    if (lower.endsWith('.m4a')) {
      return 'audio/mp4';
    }
    if (lower.endsWith('.aac')) {
      return 'audio/aac';
    }
    if (lower.endsWith('.flac')) {
      return 'audio/flac';
    }
    if (lower.endsWith('.wav')) {
      return 'audio/wav';
    }
    if (lower.endsWith('.mp4') || lower.endsWith('.m4v')) {
      return 'video/mp4';
    }
    if (lower.endsWith('.webm')) {
      return 'video/webm';
    }
    if (lower.endsWith('.ttf')) {
      return 'font/ttf';
    }
    if (lower.endsWith('.otf')) {
      return 'font/otf';
    }
    if (lower.endsWith('.woff')) {
      return 'font/woff';
    }
    if (lower.endsWith('.woff2')) {
      return 'font/woff2';
    }
    if (lower.endsWith('.wasm')) {
      return 'application/wasm';
    }
    if (lower.endsWith('.xml')) {
      return 'application/xml; charset=utf-8';
    }
    if (lower.endsWith('.txt')) {
      return 'text/plain; charset=utf-8';
    }
    return 'application/octet-stream';
  }

  static normalize(path: string): string {
    let value = path.trim().replace(/\\/g, '/');
    while (value.startsWith('/')) {
      value = value.substring(1);
    }
    const parts: string[] = [];
    value.split('/').forEach((part: string) => {
      if (part.length === 0 || part === '.') {
        return;
      }
      if (part === '..') {
        parts.pop();
        return;
      }
      parts.push(part);
    });
    return parts.join('/');
  }

  static decodeUtf8(buffer: ArrayBuffer): string {
    const decoder = util.TextDecoder.create('utf-8', { fatal: false, ignoreBOM: true });
    return decoder.decodeToString(new Uint8Array(buffer));
  }

  private static readFileRange(path: string, offset: number, length: number): ArrayBuffer | null {
    const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
    try {
      const buffer = new ArrayBuffer(length);
      const read = fileIo.readSync(file.fd, buffer, { offset: offset, length: length });
      if (read === length) {
        return buffer;
      }
      return read > 0 ? buffer.slice(0, read) : null;
    } finally {
      fileIo.closeSync(file);
    }
  }

  private static isFile(path: string): boolean {
    try {
      return fileIo.accessSync(path) && !fileIo.statSync(path).isDirectory();
    } catch (err) {
      return false;
    }
  }

  private static isDirectory(path: string): boolean {
    try {
      return fileIo.accessSync(path) && fileIo.statSync(path).isDirectory();
    } catch (err) {
      return false;
    }
  }

  private static trimTrailingSlash(path: string): string {
    let value = path;
    while (value.length > 1 && value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }
}
