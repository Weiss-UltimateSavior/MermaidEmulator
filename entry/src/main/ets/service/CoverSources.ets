import { Http } from './Http';

const USER_AGENT: string = 'MermaidEmulator/1.0';
const VNDB_MIN_INTERVAL: number = 1100;
const VNDB_FIELDS: string =
  'title,alttitle,titles.lang,titles.title,titles.main,released,image.url,image.thumbnail,developers.name,developers.original';

interface VndbTitle {
  lang?: string;
  title?: string;
  main?: boolean;
}

interface VndbImage {
  url?: string;
  thumbnail?: string;
}

interface VndbDeveloper {
  name?: string;
  original?: string;
}

interface VndbItem {
  id?: string;
  title?: string;
  alttitle?: string;
  released?: string;
  titles?: VndbTitle[];
  image?: VndbImage;
  developers?: VndbDeveloper[];
}

interface VndbResponse {
  results?: VndbItem[];
}

interface VndbSearchRequest {
  filters: string[];
  fields: string;
  sort: string;
  results: number;
}

interface SteamItem {
  id?: number;
  name?: string;
}

interface SteamResponse {
  items?: SteamItem[];
}

interface BangumiFilter {
  type: number[];
  nsfw: boolean;
}

interface BangumiSearchRequest {
  keyword: string;
  sort: string;
  filter: BangumiFilter;
}

interface BangumiImages {
  large?: string;
  common?: string;
}

interface BangumiItem {
  id?: number;
  type?: number;
  name?: string;
  name_cn?: string;
  date?: string;
  images?: BangumiImages;
}

interface BangumiResponse {
  data?: BangumiItem[];
}

export class CoverCandidate {
  source: string = '';
  id: string = '';
  title: string = '';
  subtitle: string = '';
  detail: string = '';
  coverUrl: string = '';
}

function delay(ms: number): Promise<void> {
  return new Promise<void>((resolve: (value: void) => void) => {
    setTimeout(() => {
      resolve();
    }, ms);
  });
}

export class CoverSources {
  static readonly VNDB: string = 'vndb';
  static readonly STEAM: string = 'steam';
  static readonly BANGUMI: string = 'bangumi';

  private static lastVndbRequest: number = 0;

  static async search(source: string, keyword: string, limit: number): Promise<CoverCandidate[]> {
    if (source === CoverSources.VNDB) {
      return await CoverSources.searchVndb(keyword, limit);
    }
    if (source === CoverSources.STEAM) {
      return await CoverSources.searchSteam(keyword, limit);
    }
    if (source === CoverSources.BANGUMI) {
      return await CoverSources.searchBangumi(keyword, limit);
    }
    return [];
  }

  static sourceName(source: string): string {
    if (source === CoverSources.VNDB) {
      return 'VNDB';
    }
    if (source === CoverSources.STEAM) {
      return 'Steam';
    }
    if (source === CoverSources.BANGUMI) {
      return 'Bangumi';
    }
    return source;
  }

  static imageHeaders(source: string): Record<string, string> {
    const headers: Record<string, string> = { 'User-Agent': USER_AGENT };
    if (source === CoverSources.VNDB) {
      headers['Referer'] = 'https://vndb.org/';
      headers['Cookie'] = 'vndb_img=1; vndb_samesite=1';
    } else if (source === CoverSources.STEAM) {
      headers['Referer'] = 'https://store.steampowered.com/';
    } else if (source === CoverSources.BANGUMI) {
      headers['Referer'] = 'https://bgm.tv/';
    }
    return headers;
  }

  static cleanTitle(title: string): string {
    let cleaned = title
      .replace(/\[[^\]]*\]|【[^】]*】/g, ' ')
      .replace(/[\[\]【】]/g, ' ')
      .replace(/[（(].*/g, ' ')
      .replace(/(complete|trial|patch|汉化|中文版|日文版|体验版)/gi, ' ')
      .replace(/_/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
    if (cleaned.length === 0) {
      cleaned = title.trim();
    }
    return cleaned;
  }

  private static async searchVndb(keyword: string, limit: number): Promise<CoverCandidate[]> {
    await CoverSources.throttleVndb();
    const request: VndbSearchRequest = {
      filters: ['search', '=', keyword],
      fields: VNDB_FIELDS,
      sort: 'searchrank',
      results: Math.min(Math.max(limit, 1), 10)
    };
    const text = await Http.postJson('https://api.vndb.org/kana/vn', JSON.stringify(request), {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      'User-Agent': USER_AGENT
    });
    const response = JSON.parse(text) as VndbResponse;
    const items: VndbItem[] = response.results ?? [];
    const candidates: CoverCandidate[] = [];
    items.forEach((item: VndbItem) => {
      const coverUrl = CoverSources.firstNonEmpty(item.image?.thumbnail, item.image?.url);
      if (coverUrl.length === 0) {
        return;
      }
      const candidate = new CoverCandidate();
      candidate.source = CoverSources.VNDB;
      candidate.id = item.id ?? '';
      candidate.title = CoverSources.firstNonEmpty(CoverSources.chineseTitle(item), item.title ?? '');
      candidate.subtitle = CoverSources.firstNonEmpty(CoverSources.originalTitle(item), item.title ?? '');
      candidate.detail = CoverSources.detailText('VNDB', candidate.id, item.released ?? '',
        CoverSources.developerText(item));
      candidate.coverUrl = coverUrl;
      candidates.push(candidate);
    });
    return candidates;
  }

  private static async searchSteam(keyword: string, limit: number): Promise<CoverCandidate[]> {
    const size = Math.min(Math.max(limit, 1), 10);
    const url = `https://store.steampowered.com/api/storesearch/?term=${encodeURIComponent(keyword)}&l=schinese&cc=CN`;
    const text = await Http.getJson(url, {
      'Accept': 'application/json',
      'User-Agent': USER_AGENT
    });
    const response = JSON.parse(text) as SteamResponse;
    const items: SteamItem[] = response.items ?? [];
    const candidates: CoverCandidate[] = [];
    items.forEach((item: SteamItem) => {
      if (candidates.length >= size) {
        return;
      }
      const appId = item.id ?? 0;
      if (appId <= 0) {
        return;
      }
      const candidate = new CoverCandidate();
      candidate.source = CoverSources.STEAM;
      candidate.id = `${appId}`;
      candidate.title = item.name ?? '';
      candidate.detail = CoverSources.detailText('Steam', candidate.id);
      candidate.coverUrl = `https://cdn.akamai.steamstatic.com/steam/apps/${appId}/library_600x900.jpg`;
      candidates.push(candidate);
    });
    return candidates;
  }

  private static async searchBangumi(keyword: string, limit: number): Promise<CoverCandidate[]> {
    const size = Math.min(Math.max(limit, 1), 10);
    const request: BangumiSearchRequest = {
      keyword: keyword,
      sort: 'rank',
      filter: {
        type: [4],
        nsfw: true
      }
    };
    const url = `https://api.bgm.tv/v0/search/subjects?limit=${size}&offset=0`;
    const text = await Http.postJson(url, JSON.stringify(request), {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      'User-Agent': USER_AGENT
    });
    const response = JSON.parse(text) as BangumiResponse;
    const items: BangumiItem[] = response.data ?? [];
    const candidates: CoverCandidate[] = [];
    items.forEach((item: BangumiItem) => {
      if (item.type !== undefined && item.type !== 4) {
        return;
      }
      const coverUrl = CoverSources.firstNonEmpty(item.images?.large, item.images?.common);
      if (coverUrl.length === 0) {
        return;
      }
      const name = item.name ?? '';
      const nameCn = item.name_cn ?? '';
      const candidate = new CoverCandidate();
      candidate.source = CoverSources.BANGUMI;
      candidate.id = `${item.id ?? 0}`;
      candidate.title = CoverSources.firstNonEmpty(nameCn, name);
      candidate.subtitle = name;
      candidate.detail = CoverSources.detailText('Bangumi', candidate.id, item.date ?? '');
      candidate.coverUrl = coverUrl;
      candidates.push(candidate);
    });
    return candidates;
  }

  private static chineseTitle(item: VndbItem): string {
    const titles: VndbTitle[] = item.titles ?? [];
    for (const entry of titles) {
      const lang = entry.lang ?? '';
      const value = entry.title ?? '';
      if ((lang === 'zh-Hans' || lang === 'zh-Hant' || lang === 'zh') && value.length > 0) {
        return value;
      }
    }
    return '';
  }

  private static originalTitle(item: VndbItem): string {
    const titles: VndbTitle[] = item.titles ?? [];
    for (const entry of titles) {
      const value = entry.title ?? '';
      if (entry.main === true && value.length > 0) {
        return value;
      }
    }
    return item.alttitle ?? '';
  }

  private static developerText(item: VndbItem): string {
    const developers: VndbDeveloper[] = item.developers ?? [];
    const names: string[] = [];
    developers.forEach((developer: VndbDeveloper) => {
      if (names.length >= 3) {
        return;
      }
      const name = CoverSources.firstNonEmpty(developer.original, developer.name);
      if (name.length > 0) {
        names.push(name);
      }
    });
    return names.join(' / ');
  }

  private static firstNonEmpty(a: string | undefined, b: string | undefined): string {
    if (a !== undefined && a.length > 0 && a !== 'null') {
      return a;
    }
    if (b !== undefined && b.length > 0 && b !== 'null') {
      return b;
    }
    return '';
  }

  private static detailText(...values: string[]): string {
    return values.filter((value: string) => value.length > 0 && value !== 'null').join(' · ');
  }

  private static async throttleVndb(): Promise<void> {
    const wait = VNDB_MIN_INTERVAL - (Date.now() - CoverSources.lastVndbRequest);
    if (wait > 0) {
      await delay(wait);
    }
    CoverSources.lastVndbRequest = Date.now();
  }
}
