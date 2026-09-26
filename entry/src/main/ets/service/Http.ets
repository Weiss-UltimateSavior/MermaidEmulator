import { http } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';

const CONNECT_TIMEOUT: number = 15000;
const READ_TIMEOUT: number = 20000;

export class Http {
  static async getJson(url: string, headers: Record<string, string>): Promise<string> {
    return await Http.requestText(url, http.RequestMethod.GET, headers, '');
  }

  static async postJson(url: string, body: string, headers: Record<string, string>): Promise<string> {
    return await Http.requestText(url, http.RequestMethod.POST, headers, body);
  }

  static async download(url: string, filePath: string, headers: Record<string, string>): Promise<boolean> {
    const request = http.createHttp();
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: headers,
        connectTimeout: CONNECT_TIMEOUT,
        readTimeout: READ_TIMEOUT * 2,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        return false;
      }
      const buffer = response.result as ArrayBuffer;
      if (buffer.byteLength === 0) {
        return false;
      }
      const file = fileIo.openSync(filePath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(file.fd, buffer);
      } finally {
        fileIo.closeSync(file);
      }
      return true;
    } catch (err) {
      return false;
    } finally {
      request.destroy();
    }
  }

  private static async requestText(url: string, method: http.RequestMethod,
    headers: Record<string, string>, body: string): Promise<string> {
    const request = http.createHttp();
    try {
      const options: http.HttpRequestOptions = {
        method: method,
        header: headers,
        connectTimeout: CONNECT_TIMEOUT,
        readTimeout: READ_TIMEOUT,
        expectDataType: http.HttpDataType.STRING
      };
      if (body.length > 0) {
        options.extraData = body;
      }
      const response = await request.request(url, options);
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`HTTP ${response.responseCode}`);
      }
      return response.result as string;
    } finally {
      request.destroy();
    }
  }
}
