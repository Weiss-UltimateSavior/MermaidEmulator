import { fileIo, fileShare, fileUri } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Game, GameFolder } from '../model/Game';
import { LibraryStore } from './LibraryStore';

const DOMAIN: number = 0x4D45;
const TAG: string = 'GameFolderStore';

class ScanMatch {
  dir: string;
  engineId: string;

  constructor(dir: string, engineId: string) {
    this.dir = dir;
    this.engineId = engineId;
  }
}

export class GameFolderStore {
  static async addAndScan(folderUri: string): Promise<number> {
    const folder = new fileUri.FileUri(folderUri);
    const folderPath = folder.path;
    await GameFolderStore.persistAccess(folderUri);
    LibraryStore.addFolder(folderUri, folderPath);
    return await GameFolderStore.scan(folderPath);
  }

  static async activateAll(folders: GameFolder[]): Promise<void> {
    const jobs: Promise<void>[] = folders.map((folder: GameFolder) => GameFolderStore.activate(folder));
    await Promise.all(jobs);
  }

  static async activate(folder: GameFolder): Promise<void> {
    if (folder.uri.length === 0) {
      return;
    }
    try {
      await fileShare.activatePermission([{
        uri: folder.uri,
        operationMode: fileShare.OperationMode.READ_MODE
      }]);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'activate permission failed: %{public}s', JSON.stringify(err));
    }
  }

  static async release(folder: GameFolder): Promise<void> {
    if (folder.uri.length === 0) {
      return;
    }
    try {
      await fileShare.deactivatePermission([{
        uri: folder.uri,
        operationMode: fileShare.OperationMode.READ_MODE
      }]);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'deactivate permission failed: %{public}s', JSON.stringify(err));
    }
    try {
      await fileShare.revokePermission([{
        uri: folder.uri,
        operationMode: fileShare.OperationMode.READ_MODE
      }]);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'revoke permission failed: %{public}s', JSON.stringify(err));
    }
  }

  static async scan(folderPath: string): Promise<number> {
    const root = new fileUri.FileUri(folderPath);
    const rootPath = root.path;
    const rootName = GameFolderStore.decodeName(root.name);
    const entries: string[] = await fileIo.listFileExt(rootPath, {
      recursion: true,
      listNum: 20000,
      fileFilter: {
        filter: (name: string): boolean => GameFolderStore.isFeatureFile(name)
      }
    });

    if (entries.length === 0) {
      return 0;
    }

    const featureMap: Map<string, Set<string>> = new Map();
    entries.forEach((entry: string) => {
      const relative = GameFolderStore.normalizeEntry(entry, rootPath);
      if (relative.length === 0) {
        return;
      }
      const parts = relative.split('/');
      for (let index = 0; index < parts.length; index++) {
        const dir = parts.slice(0, index).join('/');
        const subPath = parts.slice(index).join('/');
        let subPaths = featureMap.get(dir);
        if (subPaths === undefined) {
          subPaths = new Set<string>();
          featureMap.set(dir, subPaths);
        }
        subPaths.add(subPath);
      }
    });

    const matches: ScanMatch[] = [];
    featureMap.forEach((subPaths: Set<string>, dir: string) => {
      const engineId = GameFolderStore.detectEngine(subPaths);
      if (engineId.length > 0) {
        matches.push(new ScanMatch(dir, engineId));
      }
    });

    const normalized: ScanMatch[] = [];
    matches.forEach((match: ScanMatch) => {
      const dir = GameFolderStore.normalizeGameDir(match.dir);
      if (!normalized.some((other: ScanMatch) => other.dir === dir)) {
        normalized.push(new ScanMatch(dir, match.engineId));
      }
    });

    const leafMatches = normalized.filter((match: ScanMatch) => {
      const prefix = match.dir.length > 0 ? `${match.dir}/` : '';
      return !normalized.some((other: ScanMatch) =>
        other.dir !== match.dir && other.dir.startsWith(prefix));
    });

    const expectedPaths: string[] = [];
    leafMatches.forEach((match: ScanMatch) => {
      expectedPaths.push(match.dir.length > 0 ? `${rootPath}/${match.dir}` : rootPath);
    });

    let added = 0;
    leafMatches.forEach((match: ScanMatch) => {
      const gamePath = match.dir.length > 0 ? `${rootPath}/${match.dir}` : rootPath;
      const title = match.dir.length > 0
        ? GameFolderStore.decodeName(match.dir.split('/').pop() ?? rootName)
        : rootName;
      const existing = LibraryStore.list().find((game: Game) => game.path === gamePath);
      if (existing === undefined) {
        LibraryStore.add(LibraryStore.create(title, gamePath, match.engineId));
        added += 1;
      } else if (existing.engineId !== match.engineId) {
        LibraryStore.setEngine(existing, match.engineId);
      }
    });

    LibraryStore.list().slice().forEach((game: Game) => {
      const underRoot = game.path === rootPath || game.path.startsWith(`${rootPath}/`);
      if (underRoot && !expectedPaths.includes(game.path)) {
        LibraryStore.remove(game.id);
      }
    });
    return added;
  }

  private static normalizeGameDir(dir: string): string {
    const parts: string[] = dir.split('/').filter((part: string) => part.length > 0);
    while (parts.length > 0) {
      const last = parts[parts.length - 1].toLowerCase();
      if (last === 'www' || last === 'app.asar') {
        parts.pop();
      } else {
        break;
      }
    }
    return parts.join('/');
  }

  private static detectEngine(subPaths: Set<string>): string {
    let hasIndex = false;
    let hasSystemIni = false;
    let hasFirstIet = false;
    let hasPfs = false;
    let hasPfsPatch = false;
    let hasBootIni = false;
    let hasObbLikeFile = false;
    let hasRpgMvCore = false;
    let hasRpgMzCore = false;
    let hasTyranoDir = false;
    let hasAppAsar = false;

    subPaths.forEach((candidate: string) => {
      const subPath = candidate.toLowerCase();
      if (subPath === 'index.html' || subPath === 'index.htm') {
        hasIndex = true;
      }
      if (subPath === 'system.ini') {
        hasSystemIni = true;
      }
      if (subPath === 'system/first.iet') {
        hasFirstIet = true;
      }
      if (subPath === 'boot.ini') {
        hasBootIni = true;
      }
      if (subPath === 'js/rpg_core.js') {
        hasRpgMvCore = true;
      }
      if (subPath === 'js/rmmz_core.js') {
        hasRpgMzCore = true;
      }
      if (subPath === 'app.asar' || subPath.endsWith('/app.asar')) {
        hasAppAsar = true;
      }
      if (subPath.startsWith('tyrano/')) {
        hasTyranoDir = true;
      }
      const name = subPath.substring(subPath.lastIndexOf('/') + 1);
      if (name.endsWith('.pfs')) {
        hasPfs = true;
        if (GameFolderStore.isPfsPatch(name)) {
          hasPfsPatch = true;
        }
      }
      if (name.endsWith('.obb')) {
        hasObbLikeFile = true;
      }
    });

    if ((hasSystemIni && hasFirstIet) || hasPfs || hasPfsPatch || (hasBootIni && hasObbLikeFile)) {
      return 'artemis';
    }
    if (hasIndex && hasTyranoDir) {
      return 'tyrano';
    }
    if (hasIndex && hasRpgMvCore) {
      return 'rpgm_mv';
    }
    if (hasIndex && hasRpgMzCore) {
      return 'rpgm_mz';
    }
    if (hasAppAsar) {
      return 'tyrano';
    }
    return '';
  }

  static displayName(folderPath: string): string {
    try {
      return GameFolderStore.decodeName(new fileUri.FileUri(folderPath).name);
    } catch (err) {
      return GameFolderStore.decodeName(folderPath.split('/').pop() ?? folderPath);
    }
  }

  private static isFeatureFile(path: string): boolean {
    const lower = path.toLowerCase();
    const name = lower.substring(lower.lastIndexOf('/') + 1);
    if (name === 'index.html' || name === 'index.htm' || name === 'system.ini' ||
      name === 'boot.ini' || name === 'first.iet' || name === 'rpg_core.js' ||
      name === 'rmmz_core.js' || name === 'app.asar') {
      return true;
    }
    if (name.endsWith('.pfs') || name.endsWith('.obb') || name.endsWith('.tjs')) {
      return true;
    }
    if (GameFolderStore.isPfsPatch(name)) {
      return true;
    }
    if (lower.startsWith('tyrano/') || lower.includes('/tyrano/')) {
      return true;
    }
    return false;
  }

  private static isPfsPatch(name: string): boolean {
    return name.match(/^[^.]+\.pfs\.\d{3}$/) !== null;
  }

  private static normalizeEntry(entry: string, rootPath: string): string {
    let relative = entry;
    if (relative.startsWith(rootPath)) {
      relative = relative.substring(rootPath.length);
    }
    while (relative.startsWith('/')) {
      relative = relative.substring(1);
    }
    return relative;
  }

  private static async persistAccess(folderUri: string): Promise<void> {
    try {
      await fileShare.persistPermission([{
        uri: folderUri,
        operationMode: fileShare.OperationMode.READ_MODE
      }]);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'persist permission failed: %{public}s', JSON.stringify(err));
    }
  }

  private static decodeName(value: string): string {
    try {
      return decodeURIComponent(value);
    } catch (err) {
      return value;
    }
  }
}
