export enum EngineStatus {
  READY = 'ready',
  NOT_INTEGRATED = 'pending',
  PLANNED = 'planned',
  DISABLED = 'disabled'
}

export class EngineFeature {
  icon: Resource;
  label: string;
  detail: string;

  constructor(icon: Resource, label: string, detail: string) {
    this.icon = icon;
    this.label = label;
    this.detail = detail;
  }
}

export class KernelProgress {
  label: string;
  value: number;

  constructor(label: string, value: number) {
    this.label = label;
    this.value = value;
  }

  stageText(): string {
    if (this.value >= 100) {
      return '已完成';
    }
    if (this.value > 0) {
      return '进行中';
    }
    return '待开始';
  }
}

export class EngineCore {
  id: string = '';
  name: string = '';
  shortName: string = '';
  vendor: string = '';
  version: string = '';
  status: EngineStatus = EngineStatus.PLANNED;
  accent: string = '#6C5CE7';
  description: string = '';
  runtime: string = '';
  extensions: string[] = [];
  features: EngineFeature[] = [];
  progress: KernelProgress[] = [];
  runtimeReady: boolean = false;

  canHandle(fileName: string): boolean {
    const lower = fileName.toLowerCase();
    return this.extensions.some((ext: string) => lower.endsWith(ext.toLowerCase()));
  }

  statusText(): string {
    switch (this.status) {
      case EngineStatus.READY:
        return '已接入';
      case EngineStatus.NOT_INTEGRATED:
        return '未接入';
      case EngineStatus.DISABLED:
        return '已停用';
      default:
        return '规划中';
    }
  }

  statusColor(): string {
    switch (this.status) {
      case EngineStatus.READY:
        return '#18A46B';
      case EngineStatus.NOT_INTEGRATED:
        return '#D98A0B';
      case EngineStatus.DISABLED:
        return '#8896AD';
      default:
        return '#6C5CE7';
    }
  }

  overallProgress(): number {
    if (this.progress.length === 0) {
      return 0;
    }
    let total = 0;
    this.progress.forEach((item: KernelProgress) => {
      total += item.value;
    });
    return Math.round(total / this.progress.length);
  }
}

export class PlannedEngine extends EngineCore {
  constructor(id: string, name: string, vendor: string, description: string, extensions: string[]) {
    super();
    this.id = id;
    this.name = name;
    this.shortName = name;
    this.vendor = vendor;
    this.version = '—';
    this.status = EngineStatus.PLANNED;
    this.accent = '#8896AD';
    this.description = description;
    this.runtime = '尚未排期';
    this.extensions = extensions;
  }
}
