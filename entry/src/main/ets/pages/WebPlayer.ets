import { router, window } from '@kit.ArkUI';
import { util } from '@kit.ArkTS';
import { webview } from '@kit.ArkWeb';
import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppTheme } from '../common/Theme';
import { Game } from '../model/Game';
import { GameSidebar, GameSidebarItem } from '../components/GameSidebar';
import { LibraryStore } from '../store/LibraryStore';
import { TyranoAssets } from '../service/TyranoAssets';
import { TyranoStore } from '../service/TyranoStore';
import { SettingsStore, WebEngineConfig } from '../store/SettingsStore';

const DOMAIN: number = 0x4D45;
const TAG: string = 'WebPlayer';
const HOST: string = 'http://127.0.0.1';
const ENTRY_PATH: string = 'index.html';
const HOOK_FILE: string = 'tyrano_hook.js';

class WebBridge {
  setStorage: (key: string, value: string) => void = () => {
  };
  getStorage: (key: string) => string = () => {
    return '';
  };
  closeGame: () => void = () => {
  };
  finishGame: () => void = () => {
  };
  openUrl: (url: string) => void = () => {
  };
  stopMovie: () => void = () => {
  };
  audio: (value: string) => void = () => {
  };
  Save: (key: string, data: string) => void = () => {
  };
  Load: (key: string) => string = () => {
    return '';
  };
  Exists: (key: string) => boolean = () => {
    return false;
  };
  Remove: (key: string) => boolean = () => {
    return false;
  };
}

@Entry
@Component
struct WebPlayer {
  @State gameTitle: string = '';
  @State hostState: string = '正在启动…';
  @State sidebarVisible: boolean = false;
  private controller: webview.WebviewController = new webview.WebviewController();
  private assets: TyranoAssets | null = null;
  private saveDir: string = '';
  private hookScript: string = '';
  private bridge: WebBridge = new WebBridge();
  private mainWindow: window.Window | null = null;
  private engineId: string = 'tyrano';
  private bridgeName: string = 'appJsInterface';
  private config: WebEngineConfig = new WebEngineConfig();
  private origin: string = `${HOST}:${WebEngineConfig.DEFAULT_PORT}`;
  private sidebarItems: GameSidebarItem[] = [];
  private sidebarScripts: Map<string, string> = new Map<string, string>();
  private mzCoreAppend: string = '';
  private mzManagersAppend: string = '';

  aboutToAppear(): void {
    const gameId = AppStorage.get<string>('playerGameId') ?? '';
    const game = LibraryStore.list().find((item: Game) => item.id === gameId);
    if (game === undefined) {
      this.hostState = '未找到游戏记录';
      return;
    }
    this.gameTitle = game.title;
    this.engineId = game.engineId;
    this.bridgeName = this.engineId === 'tyrano' ? 'appJsInterface' : 'saveDataManager';
    this.config = SettingsStore.webConfigFor(game.id, this.engineId);
    this.origin = `${HOST}:${this.config.port}`;
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.hostState = '无法获取应用上下文';
      return;
    }
    const assets = TyranoAssets.find(game.path);
    if (assets === null) {
      this.hostState = '未找到 Web 入口（index.html / app.asar）';
      return;
    }
    this.assets = assets;
    this.saveDir = `${context.filesDir}/web_saves/${game.id}`;
    try {
      if (!fileIo.accessSync(this.saveDir)) {
        fileIo.mkdirSync(this.saveDir, true);
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'create save dir failed: %{public}s', JSON.stringify(err));
    }
    this.setupGameWindow(context);
    this.loadHook(context);
    this.setupBridge();
    this.setupSidebar();
    this.hostState = '';
  }

  aboutToDisappear(): void {
    this.controller.stopAllMedia();
    this.restoreAppWindow();
  }

  onBackPress(): boolean {
    if (this.sidebarVisible) {
      this.sidebarVisible = false;
    }
    return true;
  }

  private setupSidebar(): void {
    const items: GameSidebarItem[] = [];
    const scripts = new Map<string, string>();
    if (this.engineId === 'tyrano') {
      items.push(new GameSidebarItem('save', '游戏存档', $r('sys.symbol.square_and_arrow_down')));
      items.push(new GameSidebarItem('load', '游戏读档', $r('sys.symbol.archivebox')));
      items.push(new GameSidebarItem('log', '对话履历', $r('sys.symbol.doc_text')));
      items.push(new GameSidebarItem('auto', '自动播放', $r('sys.symbol.play_circle')));
      items.push(new GameSidebarItem('skip', '快速跳过', $r('sys.symbol.fast_forward')));
      scripts.set('save',
        'try { if (typeof TYRANO !== "undefined" && TYRANO.kag && TYRANO.kag.menu) TYRANO.kag.menu.displaySave(); } catch (e) {}');
      scripts.set('load',
        'try { if (typeof TYRANO !== "undefined" && TYRANO.kag && TYRANO.kag.menu) TYRANO.kag.menu.displayLoad(); } catch (e) {}');
      scripts.set('log',
        'try { if (typeof TYRANO !== "undefined" && TYRANO.kag && TYRANO.kag.menu) TYRANO.kag.menu.displayLog(); } catch (e) {}');
      scripts.set('auto',
        'try { if (typeof TYRANO !== "undefined" && TYRANO.kag && TYRANO.kag.ftag) TYRANO.kag.ftag.startTag("autostart", {}); } catch (e) {}');
      scripts.set('skip',
        'try { if (typeof TYRANO !== "undefined" && TYRANO.kag && TYRANO.kag.ftag) TYRANO.kag.ftag.startTag("skipstart", {}); } catch (e) {}');
    } else if (this.engineId === 'rpgm_mv' || this.engineId === 'rpgm_mz') {
      items.push(new GameSidebarItem('save', '游戏存档', $r('sys.symbol.square_and_arrow_down')));
      items.push(new GameSidebarItem('load', '游戏读档', $r('sys.symbol.archivebox')));
      items.push(new GameSidebarItem('options', '游戏设置', $r('sys.symbol.gearshape')));
      items.push(new GameSidebarItem('title', '回到标题', $r('sys.symbol.house')));
      scripts.set('save',
        'try { if (typeof SceneManager !== "undefined" && typeof Scene_Save !== "undefined") SceneManager.push(Scene_Save); } catch (e) {}');
      scripts.set('load',
        'try { if (typeof SceneManager !== "undefined" && typeof Scene_Load !== "undefined") SceneManager.push(Scene_Load); } catch (e) {}');
      scripts.set('options',
        'try { if (typeof SceneManager !== "undefined" && typeof Scene_Options !== "undefined") SceneManager.push(Scene_Options); } catch (e) {}');
      scripts.set('title',
        'try { if (typeof SceneManager !== "undefined" && typeof Scene_Title !== "undefined") SceneManager.goto(Scene_Title); } catch (e) {}');
    } else {
      items.push(new GameSidebarItem('reload', '重新载入', $r('sys.symbol.arrow_clockwise')));
      scripts.set('reload', 'try { window.location.reload(); } catch (e) {}');
    }
    items.push(new GameSidebarItem('exit', '结束游戏', $r('sys.symbol.xmark'), true));
    this.sidebarItems = items;
    this.sidebarScripts = scripts;
  }

  private handleSidebarAction(key: string): void {
    this.sidebarVisible = false;
    if (key === 'exit') {
      this.confirmDestructive('结束游戏', '未保存的游戏进度将会丢失，确定结束吗？', '结束', () => {
        this.bridge.closeGame();
      });
      return;
    }
    if (key === 'title') {
      this.confirmDestructive('回到标题', '未保存的游戏进度将会丢失，确定回到标题界面吗？', '回到标题', () => {
        this.runSidebarScript('title');
      });
      return;
    }
    this.runSidebarScript(key);
  }

  private runSidebarScript(key: string): void {
    const script = this.sidebarScripts.get(key);
    if (script !== undefined) {
      this.runGameScript(script);
    }
  }

  private confirmDestructive(title: string, message: string, confirmLabel: string,
    action: () => void): void {
    this.getUIContext().showAlertDialog({
      title: title,
      message: message,
      autoCancel: true,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: confirmLabel,
        fontColor: AppTheme.danger,
        action: action
      }
    });
  }

  private setupGameWindow(context: Context): void {
    const preferred = this.config.orientation === '自动旋转'
      ? window.Orientation.AUTO_ROTATION_LANDSCAPE
      : window.Orientation.LANDSCAPE;
    window.getLastWindow(context).then((win: window.Window) => {
      this.mainWindow = win;
      win.setPreferredOrientation(preferred)
        .then(() => win.setWindowLayoutFullScreen(true))
        .then(() => win.setWindowSystemBarEnable([]))
        .catch((err: BusinessError) => {
          hilog.warn(DOMAIN, TAG, 'immersive landscape failed: %{public}s', JSON.stringify(err));
        });
    }).catch((err: BusinessError) => {
      hilog.warn(DOMAIN, TAG, 'get last window failed: %{public}s', JSON.stringify(err));
    });
  }

  private restoreAppWindow(): void {
    const win = this.mainWindow;
    if (win === null) {
      return;
    }
    this.mainWindow = null;
    win.setPreferredOrientation(window.Orientation.PORTRAIT)
      .then(() => win.setWindowSystemBarEnable(['status', 'navigation']))
      .catch((err: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'restore window failed: %{public}s', JSON.stringify(err));
      });
  }

  private async loadHook(context: Context): Promise<void> {
    const volumeScript =
      `window.__appVolume=${Math.max(0, Math.min(100, this.config.volume)) / 100};` +
      '(function(){var v=window.__appVolume;var P=HTMLMediaElement.prototype;var op=P.play;' +
      'P.play=function(){try{this.volume=v;}catch(e){}return op.apply(this,arguments);};' +
      'window.__setAppVolume=function(n){v=n;document.querySelectorAll("audio,video")' +
      '.forEach(function(m){try{m.volume=n;}catch(e){}});};})();\n';
    let script = volumeScript;
    try {
      let asset = '';
      if (this.engineId === 'tyrano') {
        asset = HOOK_FILE;
      } else if (this.engineId === 'rpgm_mv') {
        asset = 'rpg_mv_hook.js';
      } else if (this.engineId === 'rpgm_mz') {
        asset = 'rpg_mz_hook.js';
      }
      if (asset.length > 0) {
        const content = await context.resourceManager.getRawFileContent(asset);
        const decoder = util.TextDecoder.create('utf-8');
        script += decoder.decodeToString(content);
      }
      if (this.engineId === 'rpgm_mz') {
        const decoder = util.TextDecoder.create('utf-8');
        const coreAppend = await context.resourceManager.getRawFileContent('rmmz_core_append.js');
        this.mzCoreAppend = decoder.decodeToString(coreAppend);
        const managersAppend = await context.resourceManager.getRawFileContent('rmmz_managers_append.js');
        this.mzManagersAppend = decoder.decodeToString(managersAppend);
      }
      if (this.config.touchPad && (this.engineId === 'rpgm_mv' || this.engineId === 'rpgm_mz')) {
        const padContent = await context.resourceManager.getRawFileContent('touch_pad.js');
        const decoder = util.TextDecoder.create('utf-8');
        script += '\n' + decoder.decodeToString(padContent);
      }
      if (this.engineId === 'rpgm_mv' || this.engineId === 'rpgm_mz') {
        const mouseContent = await context.resourceManager.getRawFileContent('virtual_mouse.js');
        const decoder = util.TextDecoder.create('utf-8');
        script += '\n' + decoder.decodeToString(mouseContent);
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'load hook failed: %{public}s', JSON.stringify(err));
    }
    this.hookScript = script;
  }

  private setupBridge(): void {
    this.bridge.setStorage = (key: string, value: string) => {
      TyranoStore.write(this.saveDir, key, value);
    };
    this.bridge.getStorage = (key: string) => {
      return TyranoStore.read(this.saveDir, key);
    };
    this.bridge.closeGame = () => {
      router.back();
    };
    this.bridge.finishGame = () => {
      router.back();
    };
    this.bridge.openUrl = (url: string) => {
      const lower = url.toLowerCase();
      if (lower.includes('endgame') || lower.includes('exit') || lower.startsWith('tyranoplayer')) {
        router.back();
        return;
      }
      hilog.info(DOMAIN, TAG, 'openUrl ignored: %{public}s', url);
    };
    this.bridge.stopMovie = () => {
    };
    this.bridge.audio = () => {
    };
    this.bridge.Save = (key: string, data: string) => {
      TyranoStore.write(this.saveDir, key, data);
    };
    this.bridge.Load = (key: string) => {
      return TyranoStore.read(this.saveDir, key);
    };
    this.bridge.Exists = (key: string) => {
      return TyranoStore.read(this.saveDir, key).length > 0;
    };
    this.bridge.Remove = (key: string) => {
      const path = TyranoStore.resolveFile(this.saveDir, key);
      if (path.length === 0) {
        return false;
      }
      try {
        if (fileIo.accessSync(path)) {
          fileIo.unlinkSync(path);
        }
        return true;
      } catch (err) {
        return false;
      }
    };
  }

  private serve(url: string, rangeHeader: string): WebResourceResponse | null {
    const response = new WebResourceResponse();
    const assets = this.assets;
    if (assets === null) {
      response.setResponseCode(404);
      response.setResponseMimeType('text/plain');
      response.setResponseData('missing assets');
      return response;
    }
    if (!url.startsWith(this.origin)) {
      if (this.config.network) {
        return null;
      }
      hilog.info(DOMAIN, TAG, 'blocked external request: %{public}s', url);
      response.setResponseCode(403);
      response.setResponseMimeType('text/plain');
      response.setResponseData('external network disabled');
      return response;
    }
    let path = url;
    const schemeIndex = path.indexOf('://');
    if (schemeIndex >= 0) {
      path = path.substring(schemeIndex + 3);
      const slash = path.indexOf('/');
      path = slash >= 0 ? path.substring(slash + 1) : ENTRY_PATH;
    }
    const query = path.indexOf('?');
    if (query >= 0) {
      path = path.substring(0, query);
    }
    const hash = path.indexOf('#');
    if (hash >= 0) {
      path = path.substring(0, hash);
    }
    path = TyranoAssets.normalize(decodeURIComponent(path));
    if (path.length === 0) {
      path = ENTRY_PATH;
    }
    const mime = TyranoAssets.mimeOf(path).split(';')[0];
    const total = assets.sizeOf(path);
    if (total < 0) {
      response.setResponseCode(404);
      response.setResponseMimeType('text/plain');
      response.setResponseData('not found');
      return response;
    }
    let start = 0;
    let length = total;
    let partial = false;
    if (rangeHeader.startsWith('bytes=')) {
      const range = rangeHeader.substring(6);
      const dash = range.indexOf('-');
      if (dash >= 0) {
        const first = range.substring(0, dash).trim();
        const second = range.substring(dash + 1).trim();
        if (first.length > 0) {
          start = parseInt(first, 10);
          if (second.length > 0) {
            length = parseInt(second, 10) - start + 1;
          } else {
            length = total - start;
          }
        } else if (second.length > 0) {
          const tail = parseInt(second, 10);
          start = total - tail;
          length = tail;
        }
        if (start < 0 || start >= total) {
          response.setResponseCode(416);
          response.setResponseMimeType(mime);
          response.setResponseData(new ArrayBuffer(0));
          return response;
        }
        if (start + length > total) {
          length = total - start;
        }
        partial = true;
      }
    }
    const data = assets.read(path, start, length);
    if (data === null) {
      response.setResponseCode(500);
      response.setResponseMimeType('text/plain');
      response.setResponseData('read failed');
      return response;
    }
    const headers: Array<Header> = [
      { headerKey: 'Accept-Ranges', headerValue: 'bytes' },
      { headerKey: 'Cache-Control', headerValue: 'no-cache' }
    ];
    if (partial) {
      headers.push({
        headerKey: 'Content-Range',
        headerValue: `bytes ${start}-${start + data.byteLength - 1}/${total}`
      });
      response.setResponseCode(206);
    } else {
      response.setResponseCode(200);
    }
    response.setResponseHeader(headers);
    response.setResponseMimeType(mime);
    if (path.toLowerCase() === ENTRY_PATH || path.toLowerCase().endsWith('/index.html')) {
      const html = TyranoAssets.decodeUtf8(data);
      const beforeBody = this.engineId === 'rpgm_mv' || this.engineId === 'rpgm_mz';
      const injected = WebPlayer.injectHook(html, this.hookScript, beforeBody);
      response.setResponseEncoding('utf-8');
      response.setResponseData(injected);
      return response;
    }
    if (this.engineId === 'rpgm_mz') {
      const lower = path.toLowerCase();
      if (lower === 'js/rmmz_core.js' && this.mzCoreAppend.length > 0) {
        response.setResponseEncoding('utf-8');
        response.setResponseData(`${TyranoAssets.decodeUtf8(data)}\n${this.mzCoreAppend}`);
        return response;
      }
      if (lower === 'js/rmmz_managers.js' && this.mzManagersAppend.length > 0) {
        response.setResponseEncoding('utf-8');
        response.setResponseData(`${TyranoAssets.decodeUtf8(data)}\n${this.mzManagersAppend}`);
        return response;
      }
    }
    if (mime.includes('text/') || mime.includes('application/javascript') ||
      mime.includes('application/json') || mime.includes('application/xml')) {
      response.setResponseEncoding('utf-8');
      response.setResponseData(TyranoAssets.decodeUtf8(data));
      return response;
    }
    response.setResponseEncoding('binary');
    response.setResponseData(data);
    return response;
  }

  private static injectHook(html: string, hook: string, beforeBody: boolean): string {
    if (hook.length === 0) {
      return html;
    }
    const tag = `\n<script type="text/javascript">\n${hook}\n</script>\n`;
    const marker = beforeBody ? '</body>' : '</head>';
    const index = html.toLowerCase().indexOf(marker);
    if (index >= 0) {
      return html.substring(0, index) + tag + html.substring(index);
    }
    return tag + html;
  }

  private requestRange(headers: Array<Header>): string {
    for (const header of headers) {
      if (header.headerKey.toLowerCase() === 'range') {
        return header.headerValue;
      }
    }
    return '';
  }

  private runGameScript(code: string): void {
    this.controller.runJavaScript(code).catch((err: BusinessError) => {
      hilog.warn(DOMAIN, TAG, 'runJavaScript failed: %{public}s', JSON.stringify(err));
    });
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Web({ src: `${this.origin}/${ENTRY_PATH}`, controller: this.controller })
        .width('100%')
        .height('100%')
        .darkMode(WebDarkMode.Off)
        .domStorageAccess(true)
        .javaScriptAccess(true)
        .mediaPlayGestureAccess(false)
        .onConsole((event) => {
          hilog.info(DOMAIN, TAG, '[game] %{public}s', event.message.getMessage());
          return false;
        })
        .onInterceptRequest((event) => {
          return this.serve(event.request.getRequestUrl(), this.requestRange(event.request.getRequestHeader()));
        })
        .javaScriptProxy({
          object: this.bridge,
          name: this.bridgeName,
          methodList: ['setStorage', 'getStorage', 'closeGame', 'finishGame', 'openUrl',
            'stopMovie', 'audio', 'Save', 'Load', 'Exists', 'Remove'],
          controller: this.controller
        })

      if (this.sidebarVisible) {
        GameSidebar({
          items: this.sidebarItems,
          onClose: () => {
            this.sidebarVisible = false;
          },
          onAction: (key: string) => {
            this.handleSidebarAction(key);
          }
        })
      }

      if (this.hostState.length > 0) {
        Column() {
          Text(this.hostState)
            .fontSize(13)
            .fontColor(AppTheme.onPrimary)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .parallelGesture(
      TapGesture({ count: 1, fingers: 3 })
        .onAction(() => {
          this.sidebarVisible = !this.sidebarVisible;
        })
    )
  }
}
