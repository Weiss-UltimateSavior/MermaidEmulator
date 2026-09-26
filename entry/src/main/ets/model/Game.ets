import { AppTheme } from '../common/Theme';

export interface GameRecord {
  id: string;
  title: string;
  path: string;
  engineId: string;
  favorite: boolean;
  importedAt: number;
  lastPlayedAt: number;
  playCount: number;
  coverPath?: string;
  coverSource?: string;
}

export interface GameFolderRecord {
  uri: string;
  path: string;
}

export class GameFolder {
  uri: string;
  path: string;

  constructor(uri: string, path: string) {
    this.uri = uri;
    this.path = path;
  }

  static fromRecord(record: GameFolderRecord): GameFolder {
    return new GameFolder(record.uri, record.path);
  }

  toRecord(): GameFolderRecord {
    const record: GameFolderRecord = {
      uri: this.uri,
      path: this.path
    };
    return record;
  }
}

@Observed
export class Game {
  id: string;
  title: string;
  path: string;
  engineId: string;
  favorite: boolean;
  importedAt: number;
  lastPlayedAt: number;
  playCount: number;
  coverPath: string;
  coverSource: string;

  constructor(id: string, title: string, path: string, engineId: string, importedAt: number) {
    this.id = id;
    this.title = title;
    this.path = path;
    this.engineId = engineId;
    this.favorite = false;
    this.importedAt = importedAt;
    this.lastPlayedAt = 0;
    this.playCount = 0;
    this.coverPath = '';
    this.coverSource = '';
  }

  static placeholder(): Game {
    return new Game('', '未选择游戏', '', 'artemis', 0);
  }

  static fromRecord(record: GameRecord): Game {
    const game = new Game(record.id, record.title, record.path, record.engineId, record.importedAt);
    game.favorite = record.favorite;
    game.lastPlayedAt = record.lastPlayedAt;
    game.playCount = record.playCount;
    game.coverPath = record.coverPath ?? '';
    game.coverSource = record.coverSource ?? '';
    return game;
  }

  toRecord(): GameRecord {
    const record: GameRecord = {
      id: this.id,
      title: this.title,
      path: this.path,
      engineId: this.engineId,
      favorite: this.favorite,
      importedAt: this.importedAt,
      lastPlayedAt: this.lastPlayedAt,
      playCount: this.playCount,
      coverPath: this.coverPath,
      coverSource: this.coverSource
    };
    return record;
  }

  coverColor(): string {
    return AppTheme.cover(this.title)[0];
  }
}
