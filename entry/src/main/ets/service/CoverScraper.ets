import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Game } from '../model/Game';
import { CoverCandidate, CoverSources } from './CoverSources';
import { Http } from './Http';
import { LibraryStore } from '../store/LibraryStore';

const DOMAIN: number = 0x4D45;
const TAG: string = 'CoverScraper';
const COVER_DIR: string = 'covers';

export class ScrapeSummary {
  updated: number = 0;
  failed: number = 0;
}

export class CoverScraper {
  static async scrapeLibrary(games: Game[], sources: string[], onlyMissing: boolean, filesDir: string,
    onProgress: (done: number, total: number, title: string) => void): Promise<ScrapeSummary> {
    const targets: Game[] = onlyMissing
      ? games.filter((game: Game) => game.coverPath.length === 0)
      : games.slice();
    const summary = new ScrapeSummary();
    for (let index = 0; index < targets.length; index++) {
      const game = targets[index];
      onProgress(index, targets.length, game.title);
      const updated = await CoverScraper.scrapeGame(game, sources, filesDir);
      if (updated) {
        summary.updated++;
      } else {
        summary.failed++;
      }
      onProgress(index + 1, targets.length, game.title);
    }
    return summary;
  }

  private static async scrapeGame(game: Game, sources: string[], filesDir: string): Promise<boolean> {
    const query = CoverSources.cleanTitle(game.title);
    if (query.length === 0) {
      return false;
    }
    for (const source of sources) {
      let candidates: CoverCandidate[] = [];
      try {
        candidates = await CoverSources.search(source, query, 4);
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'search %{public}s failed: %{public}s', source, JSON.stringify(err));
        continue;
      }
      for (const candidate of candidates) {
        const coverPath = await CoverScraper.downloadCover(game, candidate, source, filesDir);
        if (coverPath.length > 0) {
          LibraryStore.updateCover(game, coverPath, source);
          return true;
        }
      }
    }
    return false;
  }

  private static async downloadCover(game: Game, candidate: CoverCandidate, source: string,
    filesDir: string): Promise<string> {
    if (candidate.coverUrl.length === 0) {
      return '';
    }
    const dir = `${filesDir}/${COVER_DIR}`;
    try {
      if (!fileIo.accessSync(dir)) {
        fileIo.mkdirSync(dir, true);
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'create cover dir failed: %{public}s', JSON.stringify(err));
      return '';
    }
    const filePath = `${dir}/${game.id}_${source}.jpg`;
    const success = await Http.download(candidate.coverUrl, filePath, CoverSources.imageHeaders(source));
    if (!success) {
      CoverScraper.deleteFile(filePath);
      return '';
    }
    if (game.coverPath.length > 0 && game.coverPath !== filePath) {
      CoverScraper.deleteFile(game.coverPath);
    }
    return filePath;
  }

  private static deleteFile(path: string): void {
    try {
      if (fileIo.accessSync(path)) {
        fileIo.unlinkSync(path);
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'delete stale cover failed: %{public}s', JSON.stringify(err));
    }
  }
}
