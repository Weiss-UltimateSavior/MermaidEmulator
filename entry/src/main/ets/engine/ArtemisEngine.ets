import { EngineCore, EngineFeature, EngineStatus, KernelProgress } from '../model/Engine';

export class ArtemisEngine extends EngineCore {
  constructor() {
    super();
    this.id = 'artemis';
    this.name = 'Artemis Engine';
    this.shortName = 'Artemis';
    this.vendor = 'Artemis Project';
    this.version = '待接入';
    this.status = EngineStatus.NOT_INTEGRATED;
    this.accent = '#6C5CE7';
    this.runtime = 'arm64 运行时（规划中）';
    this.description = 'Artemis Engine 是广泛用于视觉小说与 AVG 的运行时，使用 .pfs 资源封包与 KAG 风格脚本，支持视频、音频与多存档槽位。本应用将首个接入该内核。';
    this.extensions = ['.pfs', '.asb', '.psb', '.tjs'];
    this.runtimeReady = false;
    this.features = [
      new EngineFeature($r('sys.symbol.doc_text'), '脚本解析', 'KAG / TJS 脚本解释器'),
      new EngineFeature($r('sys.symbol.archivebox'), '资源封包', '.pfs 虚拟文件系统'),
      new EngineFeature($r('sys.symbol.display'), '渲染管线', '2D 精灵合成与转场'),
      new EngineFeature($r('sys.symbol.speaker_wave_3'), '音频输出', 'BGM / SE / 语音混音'),
      new EngineFeature($r('sys.symbol.bookmark'), '存档系统', '多槽位与全局数据'),
      new EngineFeature($r('sys.symbol.bolt'), '性能优化', '帧率自适应与缓存')
    ];
    this.progress = [
      new KernelProgress('UI 外壳与播放器界面', 100),
      new KernelProgress('内核抽象与注册表', 100),
      new KernelProgress('NAPI 运行时桥接', 0),
      new KernelProgress('资源解包与文件系统', 0),
      new KernelProgress('渲染与音频管线', 0)
    ];
  }
}
