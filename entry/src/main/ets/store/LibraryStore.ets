import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Game, GameRecord } from '../model/Game';

const DOMAIN: number = 0x4D45;
const TAG: string = 'LibraryStore';
const PREF_NAME: string = 'mermaid_library';
const KEY_GAMES: string = 'games';
const KEY_FOLDERS: string = 'game_folders';
const KEY_DEMO_SEEDED: string = 'demo_seeded_v3';

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
      AppStorage.setOrCreate<string[]>('gameFolders', LibraryStore.decodeFolders(folderText));
      const raw = LibraryStore.pref.getSync(KEY_GAMES, '[]');
      const text = typeof raw === 'string' ? raw : '[]';
      const games = LibraryStore.decode(text);
      if (games.length === 0 && LibraryStore.pref.getSync(KEY_DEMO_SEEDED, false) !== true) {
        const demoGames = LibraryStore.createDemoGames();
        AppStorage.setOrCreate<Game[]>('games', demoGames);
        LibraryStore.pref.putSync(KEY_DEMO_SEEDED, true);
        LibraryStore.persist();
      } else {
        AppStorage.setOrCreate<Game[]>('games', games);
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'init failed: %{public}s', JSON.stringify(err));
      AppStorage.setOrCreate<Game[]>('games', []);
      AppStorage.setOrCreate<string[]>('gameFolders', []);
    }
  }

  static list(): Game[] {
    return AppStorage.get<Game[]>('games') ?? [];
  }

  static folders(): string[] {
    return AppStorage.get<string[]>('gameFolders') ?? [];
  }

  static addFolder(folderPath: string): void {
    const current = LibraryStore.folders();
    if (current.includes(folderPath)) {
      return;
    }
    const next: string[] = [folderPath].concat(current);
    AppStorage.setOrCreate<string[]>('gameFolders', next);
    LibraryStore.persistFolders(next);
  }

  static removeFolder(folderPath: string): void {
    const next = LibraryStore.folders().filter((path: string) => path !== folderPath);
    AppStorage.setOrCreate<string[]>('gameFolders', next);
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

  private static persistFolders(folders: string[]): void {
    const pref = LibraryStore.pref;
    if (pref === null) {
      return;
    }
    try {
      pref.putSync(KEY_FOLDERS, JSON.stringify(folders));
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

  private static createDemoGames(): Game[] {
    const titles: string[] = [
      '星海来信',
      '雨后的青空',
      '月影のメモリア',
      '夏日终点站',
      '蓝色玻璃海',
      '远方的灯塔',
      '你与春天',
      '风铃与旧书店',
      '海风、咖啡与她',
      '迟来的告白',
      '白昼梦行者',
      '第七封信',
      '蔚蓝方程式',
      '星轨上的约定',
      '不存在的夏天',
      '桥边的午后',
      '暮色尽头',
      '城南旧电影院',
      '永恒的周末',
      '雨声收集者'
    ];
    const now = Date.now();
    return titles.map((title: string, index: number) => {
      const importedAt = now - index * 24 * 60 * 60 * 1000;
      const game = new Game(
        `demo_artemis_${index + 1}`,
        title,
        `/DemoGames/Artemis/${title}`,
        'artemis',
        importedAt
      );
      game.favorite = index === 2 || index === 8 || index === 15;
      if (index % 3 === 0) {
        game.lastPlayedAt = now - index * 60 * 60 * 1000;
        game.playCount = index + 1;
      }
      return game;
    });
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

  private static decodeFolders(text: string): string[] {
    try {
      return JSON.parse(text) as string[];
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'folder decode failed: %{public}s', JSON.stringify(err));
      return [];
    }
  }
}
