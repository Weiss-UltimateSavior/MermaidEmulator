import { fileIo, fileUri } from '@kit.CoreFileKit';
import { Game } from '../model/Game';
import { LibraryStore } from './LibraryStore';

export class GameFolderStore {
  static async addAndScan(folderUri: string): Promise<number> {
    const folder = new fileUri.FileUri(folderUri);
    const folderPath = folder.path;
    LibraryStore.addFolder(folderPath);
    return await GameFolderStore.scan(folderPath);
  }

  static async scan(folderPath: string): Promise<number> {
    const root = new fileUri.FileUri(folderPath);
    const rootPath = root.path;
    const rootName = GameFolderStore.decodeName(root.name);
    const entries: string[] = await fileIo.listFileExt(rootPath, {
      recursion: true,
      listNum: 10000,
      fileFilter: {
        filter: (name: string): boolean => GameFolderStore.isGameResource(name)
      }
    });

    if (entries.length === 0) {
      return 0;
    }

    const gameDirectories: string[] = [];
    const hasRootResource = entries.some((entry: string) => GameFolderStore.relativeDirectory(entry).length === 0);
    if (hasRootResource) {
      gameDirectories.push('');
    } else {
      entries.forEach((entry: string) => {
        const relativeDirectory = GameFolderStore.gameDirectoryForResource(entry);
        if (!gameDirectories.includes(relativeDirectory)) {
          gameDirectories.push(relativeDirectory);
        }
      });
    }

    let added = 0;
    gameDirectories.forEach((relativeDirectory: string) => {
      const gamePath = relativeDirectory.length > 0 ? `${rootPath}/${relativeDirectory}` : rootPath;
      const title = relativeDirectory.length > 0
        ? GameFolderStore.decodeName(relativeDirectory.split('/').pop() ?? rootName)
        : rootName;
      const exists = LibraryStore.list().some((game: Game) => game.path === gamePath);
      if (!exists) {
        LibraryStore.add(LibraryStore.create(title, gamePath, 'artemis'));
        added += 1;
      }
    });
    return added;
  }

  static displayName(folderPath: string): string {
    try {
      return GameFolderStore.decodeName(new fileUri.FileUri(folderPath).name);
    } catch (err) {
      return GameFolderStore.decodeName(folderPath.split('/').pop() ?? folderPath);
    }
  }

  private static isGameResource(path: string): boolean {
    const lower = path.toLowerCase();
    return lower.endsWith('.pfs') || lower.endsWith('.asb') || lower.endsWith('.psb') || lower.endsWith('.tjs');
  }

  private static relativeDirectory(entry: string): string {
    const normalized = entry.startsWith('/') ? entry.substring(1) : entry;
    const separator = normalized.lastIndexOf('/');
    return separator < 0 ? '' : normalized.substring(0, separator);
  }

  private static gameDirectoryForResource(entry: string): string {
    const relativeDirectory = GameFolderStore.relativeDirectory(entry);
    const parts = relativeDirectory.split('/').filter((part: string) => part.length > 0);
    const resourceDirectories: string[] = [
      'data', 'resource', 'resources', 'asset', 'assets', 'script', 'scripts',
      'sound', 'sounds', 'voice', 'bg', 'cg', 'image', 'images', 'scenario', 'movie', 'video'
    ];
    while (parts.length > 0 && resourceDirectories.includes(parts[parts.length - 1].toLowerCase())) {
      parts.pop();
    }
    return parts.join('/');
  }

  private static decodeName(value: string): string {
    try {
      return decodeURIComponent(value);
    } catch (err) {
      return value;
    }
  }
}
