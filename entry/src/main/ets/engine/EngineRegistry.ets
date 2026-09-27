import { EngineCore, EngineStatus, PlannedEngine } from '../model/Engine';
import { ArtemisEngine } from './ArtemisEngine';

export class EngineRegistry {
  private static installedCores: EngineCore[] | null = null;
  private static plannedCores: EngineCore[] | null = null;

  private static ensure(): void {
    if (EngineRegistry.installedCores !== null) {
      return;
    }
    EngineRegistry.installedCores = [new ArtemisEngine(), EngineRegistry.kirikiriEngine()];
    EngineRegistry.plannedCores = [
      new PlannedEngine('renpy', "Ren'Py", 'Ren\'Py Team', 'Python 驱动的视觉小说引擎，支持 .rpa 归档。', ['.rpa', '.rpy']),
      new PlannedEngine('onscripter', 'ONScripter', 'ONScripter Project', '经典 NScripter 兼容内核，支持 .nsa / .sar 封包。', ['.nsa', '.sar', '.nscript']),
      EngineRegistry.rpgmEngine('rpgm_mv', 'RPG Maker MV',
        'RPG Maker MV 游戏（Web 运行时，已接入）', ['.js']),
      EngineRegistry.rpgmEngine('rpgm_mz', 'RPG Maker MZ',
        'RPG Maker MZ 游戏（Web 运行时，已接入）', ['.js']),
      EngineRegistry.tyranoEngine(),
      EngineRegistry.webOtherEngine()
    ];
  }

  private static webOtherEngine(): EngineCore {
    const engine = new PlannedEngine('webother', 'WebOther', 'Web',
      '通用网页游戏（index.html，Web 运行时，已接入）', ['.html', '.htm']);
    engine.status = EngineStatus.READY;
    engine.version = 'Web 运行时';
    engine.runtime = 'ArkWeb';
    return engine;
  }

  private static kirikiriEngine(): EngineCore {
    const engine = new PlannedEngine('kirikiri', 'KiriKiri', 'KiriKiri Z Project',
      'KiriKiri / KAG 视觉小说（krkrsdl3 运行时，已接入）', ['.xp3', '.ks']);
    engine.status = EngineStatus.READY;
    engine.version = 'krkrsdl3';
    engine.runtime = 'OpenGL ES3';
    return engine;
  }

  private static tyranoEngine(): EngineCore {
    const engine = new PlannedEngine('tyrano', 'TyranoScript', 'ShikemokuMK',
      'TyranoScript 视觉小说（Web 运行时，已接入）', ['.ks', '.asar']);
    engine.status = EngineStatus.READY;
    engine.version = 'Web 运行时';
    engine.runtime = 'ArkWeb';
    return engine;
  }

  private static rpgmEngine(id: string, name: string, description: string,
    extensions: string[]): EngineCore {
    const engine = new PlannedEngine(id, name, 'Kadokawa', description, extensions);
    engine.icon = $r('sys.symbol.gamecontroller');
    engine.status = EngineStatus.READY;
    engine.version = 'Web 运行时';
    engine.runtime = 'ArkWeb';
    return engine;
  }

  static installed(): EngineCore[] {
    EngineRegistry.ensure();
    return EngineRegistry.installedCores as EngineCore[];
  }

  static planned(): EngineCore[] {
    EngineRegistry.ensure();
    return EngineRegistry.plannedCores as EngineCore[];
  }

  static all(): EngineCore[] {
    return EngineRegistry.installed().concat(EngineRegistry.planned());
  }

  static find(id: string): EngineCore {
    const hit = EngineRegistry.all().find((core: EngineCore) => core.id === id);
    return hit ?? EngineRegistry.installed()[0];
  }

  static detect(fileName: string): EngineCore {
    const hit = EngineRegistry.installed().find((core: EngineCore) => core.canHandle(fileName));
    return hit ?? EngineRegistry.installed()[0];
  }

  static readyCount(): number {
    return EngineRegistry.installed().filter((core: EngineCore) => core.status === EngineStatus.READY).length;
  }
}
