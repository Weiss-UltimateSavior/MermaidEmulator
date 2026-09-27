import { router } from '@kit.ArkUI';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppTheme } from '../common/Theme';
import { Game } from '../model/Game';
import { AppBackground } from '../components/AppBackground';
import { PageTopBar } from '../components/CommonWidgets';
import { LibraryStore } from '../store/LibraryStore';

const DOMAIN: number = 0x4D45;
const TAG: string = 'CoverCrop';
const COVER_RATIO: number = 0.74;
const OUT_WIDTH: number = 600;
const OUT_HEIGHT: number = 811;
const COVER_SOURCE: string = '自定义';

@Entry
@Component
struct CoverCrop {
  @StorageLink('safeBottomVp') safeBottom: number = 0;
  @StorageLink('themePrimary') themePrimary: string = AppTheme.primaryDefault;
  @State sourceUri: string = '';
  @State frameW: number = 0;
  @State frameH: number = 0;
  @State baseW: number = 0;
  @State baseH: number = 0;
  @State offsetX: number = 0;
  @State offsetY: number = 0;
  @State zoom: number = 1;
  @State busy: boolean = false;
  @State ready: boolean = false;
  private imgW: number = 0;
  private imgH: number = 0;
  private minScale: number = 1;
  private maxScale: number = 1;
  private panStartX: number = 0;
  private panStartY: number = 0;
  private pinchStartScale: number = 1;
  private source: image.ImageSource | null = null;
  private sourceFile: fileIo.File | null = null;
  private game: Game | null = null;

  aboutToAppear(): void {
    const uri = AppStorage.get<string>('coverCropUri') ?? '';
    const gameId = AppStorage.get<string>('coverCropGameId') ?? '';
    this.game = LibraryStore.list().find((item: Game) => item.id === gameId) ?? null;
    if (uri.length === 0 || this.game === null) {
      this.getUIContext().getPromptAction().showToast({ message: '图片或游戏信息缺失' });
      router.back();
      return;
    }
    this.sourceUri = uri;
    this.loadImage(uri);
  }

  aboutToDisappear(): void {
    this.releaseSource();
  }

  private releaseSource(): void {
    const source = this.source;
    if (source !== null) {
      this.source = null;
      source.release().catch(() => {
      });
    }
    const file = this.sourceFile;
    if (file !== null) {
      this.sourceFile = null;
      try {
        fileIo.closeSync(file);
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'close image failed: %{public}s', JSON.stringify(err));
      }
    }
  }

  private async loadImage(uri: string): Promise<void> {
    try {
      const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      const source = image.createImageSource(file.fd);
      const info = await source.getImageInfo();
      if (info.size.width <= 0 || info.size.height <= 0) {
        throw new Error('invalid image size');
      }
      this.imgW = info.size.width;
      this.imgH = info.size.height;
      this.sourceFile = file;
      this.source = source;
      this.setupLayout();
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'load image failed: %{public}s', JSON.stringify(err));
      this.getUIContext().getPromptAction().showToast({ message: '无法读取所选图片' });
      router.back();
    }
  }

  private setupLayout(): void {
    if (this.frameW <= 0 || this.frameH <= 0 || this.imgW <= 0 || this.imgH <= 0) {
      return;
    }
    const fit = Math.min(this.frameW / this.imgW, this.frameH / this.imgH);
    this.baseW = this.imgW * fit;
    this.baseH = this.imgH * fit;
    this.minScale = Math.max(this.frameW / this.baseW, this.frameH / this.baseH);
    this.maxScale = this.minScale * 6;
    this.zoom = this.minScale;
    this.offsetX = 0;
    this.offsetY = 0;
    this.ready = true;
  }

  private clampTransform(): void {
    const displayW = this.baseW * this.zoom;
    const displayH = this.baseH * this.zoom;
    if (displayW > this.frameW) {
      const limitX = (displayW - this.frameW) / 2;
      this.offsetX = Math.max(-limitX, Math.min(limitX, this.offsetX));
    } else {
      this.offsetX = 0;
    }
    if (displayH > this.frameH) {
      const limitY = (displayH - this.frameH) / 2;
      this.offsetY = Math.max(-limitY, Math.min(limitY, this.offsetY));
    } else {
      this.offsetY = 0;
    }
  }

  private cropRegion(): image.Region {
    const pixelPerVp = this.imgW / this.baseW;
    const cropW = Math.max(1, Math.round(this.frameW / this.zoom * pixelPerVp));
    const cropH = Math.max(1, Math.round(this.frameH / this.zoom * pixelPerVp));
    const centerX = this.baseW / 2 - this.offsetX / this.zoom;
    const centerY = this.baseH / 2 - this.offsetY / this.zoom;
    let left = Math.round(centerX * pixelPerVp - cropW / 2);
    let top = Math.round(centerY * pixelPerVp - cropH / 2);
    left = Math.max(0, Math.min(this.imgW - cropW, left));
    top = Math.max(0, Math.min(this.imgH - cropH, top));
    const region: image.Region = {
      x: left,
      y: top,
      size: { width: cropW, height: cropH }
    };
    return region;
  }

  private onCropAreaChange(width: number, height: number): void {
    const availableW = width - AppTheme.pagePadding * 2;
    if (availableW <= 0 || height <= 0) {
      return;
    }
    const boxW = Math.max(1, Math.min(availableW, height * COVER_RATIO));
    this.frameW = boxW;
    this.frameH = boxW / COVER_RATIO;
    this.setupLayout();
  }

  private async saveCover(): Promise<void> {
    const game = this.game;
    const source = this.source;
    if (this.busy || !this.ready || game === null || source === null) {
      return;
    }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    this.busy = true;
    let pixelMap: image.PixelMap | null = null;
    const packer = image.createImagePacker();
    try {
      const options: image.DecodingOptions = {
        desiredRegion: this.cropRegion(),
        desiredSize: { width: OUT_WIDTH, height: OUT_HEIGHT },
        cropAndScaleStrategy: image.CropAndScaleStrategy.CROP_FIRST
      };
      pixelMap = await source.createPixelMap(options);
      const buffer = await packer.packToData(pixelMap, { format: 'image/jpeg', quality: 92 });
      const dir = `${context.filesDir}/covers`;
      if (!fileIo.accessSync(dir)) {
        fileIo.mkdirSync(dir, true);
      }
      const target = `${dir}/${game.id}_custom.jpg`;
      const out = fileIo.openSync(target,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(out.fd, buffer);
      fileIo.closeSync(out);
      if (game.coverPath.length > 0 && game.coverPath !== target) {
        try {
          if (fileIo.accessSync(game.coverPath)) {
            fileIo.unlinkSync(game.coverPath);
          }
        } catch (err) {
          hilog.warn(DOMAIN, TAG, 'remove old cover failed: %{public}s', JSON.stringify(err));
        }
      }
      LibraryStore.updateCover(game, target, COVER_SOURCE);
      this.getUIContext().getPromptAction().showToast({ message: '封面已更新' });
      router.back();
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'save cover failed: %{public}s', JSON.stringify(err));
      this.getUIContext().getPromptAction().showToast({ message: '封面保存失败' });
    } finally {
      packer.release();
      if (pixelMap !== null) {
        pixelMap.release();
      }
      this.busy = false;
    }
  }

  build() {
    Stack() {
      AppBackground()

      Column({ space: AppTheme.topBarGap }) {
        Column() {
          PageTopBar({ title: '修改封面' })
        }
        .width('100%')
        .padding({ left: AppTheme.pagePadding, right: AppTheme.pagePadding })

        Column() {
          Stack() {
            if (this.ready) {
              Image(this.sourceUri)
                .width(this.baseW)
                .height(this.baseH)
                .objectFit(ImageFit.Fill)
                .draggable(false)
                .translate({ x: this.offsetX, y: this.offsetY })
                .scale({ x: this.zoom, y: this.zoom })
            }
          }
          .width(this.frameW)
          .height(this.frameH)
          .clip(true)
          .backgroundColor('#1A1F28')
          .gesture(
            GestureGroup(GestureMode.Parallel,
              PanGesture({ fingers: 1, distance: 1 })
                .onActionStart(() => {
                  this.panStartX = this.offsetX;
                  this.panStartY = this.offsetY;
                })
                .onActionUpdate((event: GestureEvent) => {
                  this.offsetX = this.panStartX + event.offsetX;
                  this.offsetY = this.panStartY + event.offsetY;
                  this.clampTransform();
                }),
              PinchGesture({ fingers: 2 })
                .onActionStart(() => {
                  this.pinchStartScale = this.zoom;
                })
                .onActionUpdate((event: GestureEvent) => {
                  const next = this.pinchStartScale * event.scale;
                  this.zoom = Math.max(this.minScale, Math.min(this.maxScale, next));
                  this.clampTransform();
                })
            )
          )
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .onAreaChange((oldValue: Area, newValue: Area) => {
          this.onCropAreaChange(Number(newValue.width), Number(newValue.height));
        })

        Text('拖动调整位置，双指缩放裁剪范围')
          .fontSize(12)
          .fontColor(AppTheme.textTertiary)
          .width('100%')
          .textAlign(TextAlign.Center)

        Row({ space: 12 }) {
          Button('取消')
            .layoutWeight(1)
            .height(44)
            .fontSize(14)
            .fontColor(AppTheme.textPrimary)
            .backgroundColor(AppTheme.surfaceAlt)
            .borderRadius(22)
            .stateEffect(false)
            .enabled(!this.busy)
            .onClick(() => {
              router.back();
            })

          Button(this.busy ? '正在保存…' : '确定')
            .layoutWeight(1)
            .height(44)
            .fontSize(14)
            .fontColor(AppTheme.onPrimary)
            .backgroundColor(this.themePrimary)
            .borderRadius(22)
            .stateEffect(false)
            .enabled(this.ready && !this.busy)
            .onClick(() => {
              this.saveCover();
            })
        }
        .width('100%')
        .padding({ left: AppTheme.pagePadding, right: AppTheme.pagePadding })
      }
      .width('100%')
      .height('100%')
      .padding({ bottom: 20 + this.safeBottom })
    }
    .width('100%')
    .height('100%')
  }
}
