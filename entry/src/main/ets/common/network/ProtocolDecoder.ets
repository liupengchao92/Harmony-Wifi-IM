import { Logger } from '../utils/Logger';

/**
 * 协议解码器
 *
 * 实现「长度前缀」帧协议，解决 TCP 粘包/半包问题：
 *
 *   帧格式: ┌─────────────┬──────────────┐
 *           │ 4字节长度(BE)│  消息体(JSON) │
 *           └─────────────┴──────────────┘
 *
 * - 解码器维护累积缓冲区，不完整的数据留存等待后续到达
 * - 单次回调可能包含多条完整消息，逐条解析返回
 */
export class ProtocolDecoder {
  private buffer: Uint8Array = new Uint8Array(0);
  private logger: Logger = new Logger('ProtocolDecoder');

  /**
   * 解码接收到的原始数据
   * @param data TCP 回调中的原始字节数据
   * @returns 解码后的完整消息体数组（每条消息已去除 4 字节长度头）
   */
  public decode(data: Uint8Array): Uint8Array[] {
    // 将新数据追加到累积缓冲区
    this.buffer = this.concat(this.buffer, data);
    let messages: Uint8Array[] = [];

    // 循环解析：每次读取 4 字节长度头 + 对应长度的消息体
    while (this.buffer.length >= 4) {
      let length: number = this.readInt32BE(this.buffer, 0);
      let totalLen: number = 4 + length;

      // 数据不完整（半包），等待下次回调
      if (this.buffer.length < totalLen) {
        break;
      }

      // 提取完整消息（跳过 4 字节长度头）
      let message: Uint8Array = this.buffer.slice(4, totalLen);
      messages.push(message);

      // 从缓冲区移除已处理的数据
      this.buffer = this.buffer.slice(totalLen);
    }

    if (messages.length > 0) {
      this.logger.info(`decode: 解析出 ${messages.length} 条消息，buffer 剩余 ${this.buffer.length} 字节`);
    }
    return messages;
  }

  /**
   * 构建协议帧（编码）
   * @param data 原始消息体
   * @returns 添加了 4 字节大端长度前缀的完整帧
   */
  public static buildFrame(data: Uint8Array): Uint8Array {
    let length: number = data.length;
    let frame: Uint8Array = new Uint8Array(4 + length);
    // 大端写入 4 字节长度
    frame[0] = (length >> 24) & 0xFF;
    frame[1] = (length >> 16) & 0xFF;
    frame[2] = (length >> 8) & 0xFF;
    frame[3] = length & 0xFF;
    // 写入消息体
    frame.set(data, 4);
    return frame;
  }

  /** 从 Uint8Array 的指定偏移读取 32 位大端整数 */
  private readInt32BE(buffer: Uint8Array, offset: number): number {
    return ((buffer[offset] & 0xFF) << 24) |
      ((buffer[offset + 1] & 0xFF) << 16) |
      ((buffer[offset + 2] & 0xFF) << 8) |
      (buffer[offset + 3] & 0xFF);
  }

  /** 拼接两个 Uint8Array */
  private concat(a: Uint8Array, b: Uint8Array): Uint8Array {
    let result: Uint8Array = new Uint8Array(a.length + b.length);
    result.set(a, 0);
    result.set(b, a.length);
    return result;
  }

  /** 将 Uint8Array 转为 UTF-8 字符串（ASCII兼容） */
  public static uint8ArrayToString(data: Uint8Array): string {
    let result: string = '';
    for (let i: number = 0; i < data.length; i++) {
      result += String.fromCharCode(data[i]);
    }
    return result;
  }

  /** 将字符串转为 Uint8Array（ASCII兼容） */
  public static stringToUint8Array(str: string): Uint8Array {
    let arr: Uint8Array = new Uint8Array(str.length);
    for (let i: number = 0; i < str.length; i++) {
      arr[i] = str.charCodeAt(i);
    }
    return arr;
  }
}
