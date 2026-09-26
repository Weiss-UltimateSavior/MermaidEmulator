export class AppTheme {
  static readonly bg: string = '#F2F5FA';
  static readonly bgElevated: string = '#FFFFFF';
  static readonly surface: string = '#FFFFFF';
  static readonly surfaceAlt: string = '#EEF3FA';
  static readonly surfaceHigh: string = '#DEE7F5';
  static readonly border: string = '#E4EAF4';

  static readonly primary: string = '#0E8BD3';
  static readonly primaryDim: string = '#0A6BA4';
  static readonly accent: string = '#6C5CE7';
  static readonly accentDim: string = '#4F44A8';
  static readonly success: string = '#18A46B';
  static readonly warning: string = '#D98A0B';
  static readonly danger: string = '#D6453D';

  static readonly onPrimary: string = '#FFFFFF';
  static readonly textPrimary: string = '#0F1A2C';
  static readonly textSecondary: string = '#4A5B76';
  static readonly textTertiary: string = '#8896AD';

  static readonly radiusL: number = 20;
  static readonly radiusM: number = 14;
  static readonly radiusS: number = 10;
  static readonly gap: number = 12;
  static readonly pagePadding: number = 16;

  private static readonly covers: string[][] = [
    ['#3B6FD4', '#1D3B7A'],
    ['#1F93B5', '#0F4A63'],
    ['#7B62E8', '#3B2E86'],
    ['#2AA37B', '#14523D'],
    ['#B25E8C', '#5C2B44'],
    ['#C97F3D', '#6B3F16'],
    ['#4F74CC', '#22325E'],
    ['#8A5BD4', '#3E2168']
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
    return [[AppTheme.alpha(color, '2E'), 0.0], [AppTheme.bgElevated, 1.0]];
  }

  static coverGradient(seed: string): Array<[ResourceColor, number]> {
    const pair = AppTheme.cover(seed);
    return [[pair[0], 0.0], [pair[1], 1.0]];
  }
}
