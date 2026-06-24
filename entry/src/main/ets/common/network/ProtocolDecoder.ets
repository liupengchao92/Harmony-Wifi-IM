export class ProtocolDecoder {
  private buffer: Uint8Array = new Uint8Array(0);

  public decode(data: Uint8Array): Uint8Array[] {
    this.buffer = this.concat(this.buffer, data);
    let messages: Uint8Array[] = [];
    while (this.buffer.length >= 4) {
      let length = this.readInt32BE(this.buffer, 0);
      let totalLen = 4 + length;
      if (this.buffer.length < totalLen) {
        break;
      }
      let message = this.buffer.slice(4, totalLen);
      messages.push(message);
      this.buffer = this.buffer.slice(totalLen);
    }
    return messages;
  }

  public static buildFrame(data: Uint8Array): Uint8Array {
    let length = data.length;
    let frame = new Uint8Array(4 + length);
    frame[0] = (length >> 24) & 0xFF;
    frame[1] = (length >> 16) & 0xFF;
    frame[2] = (length >> 8) & 0xFF;
    frame[3] = length & 0xFF;
    frame.set(data, 4);
    return frame;
  }

  private readInt32BE(buffer: Uint8Array, offset: number): number {
    return ((buffer[offset] & 0xFF) << 24) |
      ((buffer[offset + 1] & 0xFF) << 16) |
      ((buffer[offset + 2] & 0xFF) << 8) |
      (buffer[offset + 3] & 0xFF);
  }

  private concat(a: Uint8Array, b: Uint8Array): Uint8Array {
    let result = new Uint8Array(a.length + b.length);
    result.set(a, 0);
    result.set(b, a.length);
    return result;
  }

  public static uint8ArrayToString(data: Uint8Array): string {
    let result = '';
    for (let i = 0; i < data.length; i++) {
      result += String.fromCharCode(data[i]);
    }
    return result;
  }

  public static stringToUint8Array(str: string): Uint8Array {
    let arr = new Uint8Array(str.length);
    for (let i = 0; i < str.length; i++) {
      arr[i] = str.charCodeAt(i);
    }
    return arr;
  }
}
