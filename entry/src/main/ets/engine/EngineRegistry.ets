import { EngineCore, EngineStatus, PlannedEngine } from '../model/Engine';
import { ArtemisEngine } from './ArtemisEngine';

export class EngineRegistry {
  private static installedCores: EngineCore[] | null = null;
  private static plannedCores: EngineCore[] | null = null;

  private static ensure(): void {
    if (EngineRegistry.installedCores !== null) {
      return;
    }
    EngineRegistry.installedCores = [new ArtemisEngine()];
    EngineRegistry.plannedCores = [
      new PlannedEngine('kirikiri', 'KiriKiri', 'KiriKiri Project', '吉里吉里内核，支持 .xp3 封包与 KAG 脚本。', ['.xp3', '.ks']),
      new PlannedEngine('renpy', "Ren'Py", 'Ren\'Py Team', 'Python 驱动的视觉小说引擎，支持 .rpa 归档。', ['.rpa', '.rpy']),
      new PlannedEngine('onscripter', 'ONScripter', 'ONScripter Project', '经典 NScripter 兼容内核，支持 .nsa / .sar 封包。', ['.nsa', '.sar', '.nscript'])
    ];
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
