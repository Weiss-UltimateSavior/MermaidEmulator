export class Format {
  static pad(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  static date(timestamp: number): string {
    if (timestamp <= 0) {
      return '—';
    }
    const date = new Date(timestamp);
    return `${date.getFullYear()}-${Format.pad(date.getMonth() + 1)}-${Format.pad(date.getDate())}`;
  }

  static dateTime(timestamp: number): string {
    if (timestamp <= 0) {
      return '从未运行';
    }
    const date = new Date(timestamp);
    return `${Format.date(timestamp)} ${Format.pad(date.getHours())}:${Format.pad(date.getMinutes())}`;
  }

  static fileTitle(uri: string): string {
    const segments = uri.split('/');
    const last = segments.length > 0 ? segments[segments.length - 1] : uri;
    let name = last;
    try {
      name = decodeURIComponent(last);
    } catch (err) {
      name = last;
    }
    const dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }
}
