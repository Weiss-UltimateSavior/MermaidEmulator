export interface ArtemisStartOptions {
  dataDir: string;
  saveDir: string;
  osId: string;
  sidecut: number;
  vsync: boolean;
}

export const start: (options: ArtemisStartOptions) => void;
export const stop: () => void;
export const pause: () => void;
export const resume: () => void;
export const sendKey: (keyCode: number, down: boolean) => void;
export const state: () => number;
