export const initEngine: (gamePath: string) => boolean;
export const setSaveDir: (path: string) => void;
export const setResourceManager: (resMgr: object) => boolean;
export const setSurface: (surfaceId: string) => boolean;
export const shutdown: () => void;
export const pause: () => void;
export const resume: () => void;
export const sendMouseEvent: (type: number, x: number, y: number, button: number) => void;
export const sendKey: (vk: number, down: boolean) => void;
export const sendText: (text: string) => void;
export const registerCallbacks: (
  titleCb: (title: string) => void,
  fullscreenCb: (full: boolean) => void,
  imeCb: (show: boolean, x: number, y: number, w: number, h: number) => void
) => void;
export const updateWindowSize: (width: number, height: number) => void;
