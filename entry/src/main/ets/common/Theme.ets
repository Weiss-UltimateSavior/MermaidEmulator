export class AppTheme {
  static readonly bg: string = '#070D1A';
  static readonly bgElevated: string = '#0C1425';
  static readonly surface: string = '#111C31';
  static readonly surfaceAlt: string = '#182742';
  static readonly surfaceHigh: string = '#203150';
  static readonly border: string = '#1B2A46';

  static readonly primary: string = '#3FC5F0';
  static readonly primaryDim: string = '#1C7BA3';
  static readonly accent: string = '#8B7BFF';
  static readonly accentDim: string = '#4F44A8';
  static readonly success: string = '#42D19B';
  static readonly warning: string = '#F0B23F';
  static readonly danger: string = '#F2695F';

  static readonly textPrimary: string = '#EAF3FF';
  static readonly textSecondary: string = '#9DB2D4';
  static readonly textTertiary: string = '#5F7396';

  static readonly radiusL: number = 20;
  static readonly radiusM: number = 14;
  static readonly radiusS: number = 10;
  static readonly gap: number = 12;
  static readonly pagePadding: number = 16;

  private static readonly covers: string[][] = [
    ['#274B9F', '#111E45'],
    ['#0F6E8C', '#0A2C44'],
    ['#5B3FA8', '#251A4D'],
    ['#1C7A5E', '#0D3327'],
    ['#8A4A6E', '#3A1C30'],
    ['#A2632A', '#42260F'],
    ['#3B5AA8', '#171F42'],
    ['#6B3FA0', '#2A1543']
  ];

  static cover(seed: string): string[] {
    const index = AppTheme.hash(seed) % AppTheme.covers.length;
    return AppTheme.covers[index];
  }

  static hash(seed: string): number {
    let value = 0;
    for (let i = 0; i < seed.length; i++) {
      value = (value * 31 + seed.charCodeAt(i)) % 1000003;
    }
    return value;
  }

  static alpha(color: string, alphaHex: string): string {
    return `#${alphaHex}${color.substring(1)}`;
  }

  static heroGradient(color: string): Array<[ResourceColor, number]> {
    return [[color, 0.0], [AppTheme.bg, 1.0]];
  }

  static coverGradient(seed: string): Array<[ResourceColor, number]> {
    const pair = AppTheme.cover(seed);
    return [[pair[0], 0.0], [pair[1], 1.0]];
  }
}
