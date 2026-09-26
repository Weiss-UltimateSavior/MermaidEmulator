import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Game, GameFolder, GameFolderRecord, GameRecord } from '../model/Game';

const DOMAIN: number = 0x4D45;
const TAG: string = 'LibraryStore';
const PREF_NAME: string = 'mermaid_library';
const KEY_GAMES: string = 'games';
const KEY_FOLDERS: string = 'game_folders';
const DEMO_PATH_PREFIX: string = '/DemoGames/';

export class LibraryStore {
  private static pref: preferences.Preferences | null = null;

  static init(context: Context): void {
    if (LibraryStore.pref !== null) {
      return;
    }
    try {
      LibraryStore.pref = preferences.getPreferencesSync(context, { name: PREF_NAME });
      const rawFolders = LibraryStore.pref.getSync(KEY_FOLDERS, '[]');
      const folderText = typeof rawFolders === 'string' ? rawFolders : '[]';
      AppStorage.setOrCreate<GameFolder[]>('gameFolders', LibraryStore.decodeFolders(folderText));
      const raw = LibraryStore.pref.getSync(KEY_GAMES, '[]');
      const text = typeof raw === 'string' ? raw : '[]';
      const games = LibraryStore.decode(text);
      const realGames = games.filter((game: Game) => !game.path.startsWith(DEMO_PATH_PREFIX));
      AppStorage.setOrCreate<Game[]>('games', realGames);
      if (realGames.length !== games.length) {
        LibraryStore.persist();
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'init failed: %{public}s', JSON.stringify(err));
      AppStorage.setOrCreate<Game[]>('games', []);
      AppStorage.setOrCreate<GameFolder[]>('gameFolders', []);
    }
  }

  static list(): Game[] {
    return AppStorage.get<Game[]>('games') ?? [];
  }

  static folders(): GameFolder[] {
    return AppStorage.get<GameFolder[]>('gameFolders') ?? [];
  }

  static addFolder(folderUri: string, folderPath: string): void {
    const current = LibraryStore.folders();
    if (current.some((folder: GameFolder) => folder.path === folderPath)) {
      return;
    }
    const next: GameFolder[] = [new GameFolder(folderUri, folderPath)].concat(current);
    AppStorage.setOrCreate<GameFolder[]>('gameFolders', next);
    LibraryStore.persistFolders(next);
  }

  static removeFolder(folderPath: string): void {
    const next = LibraryStore.folders().filter((folder: GameFolder) => folder.path !== folderPath);
    AppStorage.setOrCreate<GameFolder[]>('gameFolders', next);
    LibraryStore.persistFolders(next);
  }

  static create(title: string, path: string, engineId: string): Game {
    const suffix = Math.floor(Math.random() * 100000).toString(36);
    return new Game(`g_${Date.now().toString(36)}_${suffix}`, title, path, engineId, Date.now());
  }

  static add(game: Game): void {
    const next: Game[] = [game];
    LibraryStore.list().forEach((item: Game) => next.push(item));
    LibraryStore.commit(next);
  }

  static remove(id: string): void {
    LibraryStore.commit(LibraryStore.list().filter((item: Game) => item.id !== id));
  }

  static clear(): void {
    LibraryStore.commit([]);
  }

  static markPlayed(game: Game): void {
    game.lastPlayedAt = Date.now();
    game.playCount = game.playCount + 1;
    LibraryStore.persist();
  }

  static toggleFavorite(game: Game): void {
    game.favorite = !game.favorite;
    LibraryStore.persist();
  }

  static setEngine(game: Game, engineId: string): void {
    game.engineId = engineId;
    LibraryStore.persist();
  }

  static updateCover(game: Game, coverPath: string, coverSource: string): void {
    game.coverPath = coverPath;
    game.coverSource = coverSource;
    LibraryStore.persist();
  }

  private static commit(list: Game[]): void {
    AppStorage.setOrCreate<Game[]>('games', list);
    LibraryStore.persist();
  }

  private static persist(): void {
    const pref = LibraryStore.pref;
    if (pref === null) {
      return;
    }
    try {
      pref.putSync(KEY_GAMES, LibraryStore.encode(LibraryStore.list()));
      pref.flush((err) => {
        if (err) {
          hilog.warn(DOMAIN, TAG, 'flush failed: %{public}s', JSON.stringify(err));
        }
      });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'persist failed: %{public}s', JSON.stringify(err));
    }
  }

  private static persistFolders(folders: GameFolder[]): void {
    const pref = LibraryStore.pref;
    if (pref === null) {
      return;
    }
    try {
      pref.putSync(KEY_FOLDERS, JSON.stringify(folders.map((folder: GameFolder) => folder.toRecord())));
      pref.flush((err) => {
        if (err) {
          hilog.warn(DOMAIN, TAG, 'folder flush failed: %{public}s', JSON.stringify(err));
        }
      });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'folder persist failed: %{public}s', JSON.stringify(err));
    }
  }

  private static encode(list: Game[]): string {
    return JSON.stringify(list.map((item: Game) => item.toRecord()));
  }

  private static decode(text: string): Game[] {
    try {
      const records = JSON.parse(text) as GameRecord[];
      return records.map((record: GameRecord) => Game.fromRecord(record));
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'decode failed: %{public}s', JSON.stringify(err));
      return [];
    }
  }

  private static decodeFolders(text: string): GameFolder[] {
    try {
      const records = JSON.parse(text) as (GameFolderRecord | string)[];
      return records.map((record: GameFolderRecord | string) => {
        if (typeof record === 'string') {
          return new GameFolder('', record);
        }
        return GameFolder.fromRecord(record);
      });
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'folder decode failed: %{public}s', JSON.stringify(err));
      return [];
    }
  }
}
