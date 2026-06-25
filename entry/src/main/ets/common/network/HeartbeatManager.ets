import { Logger } from '../utils/Logger';

/**
 * 心跳管理器（单例）
 *
 * 基于超时的连接健康检测：
 * - 每 10 秒检查一次失败计数
 * - 需要调用方在收到任何消息时主动调用 reset() 来清零计数
 * - 连续 MAX_FAILED_COUNT 次未收到消息，判定连接离线
 * - 触发 onHeartbeatTimeout 回调通知上层处理
 *
 * 注意：当前仅为超时检测，未实现主动发送心跳包。
 *       心跳包的发送/响应逻辑由上层（IMManager）负责。
 */
export class HeartbeatManager {
  private static instance: HeartbeatManager;
  private intervalId: number = -1;
  private failedCount: number = 0;
  private readonly HEARTBEAT_INTERVAL: number = 10000; // 心跳间隔 10 秒
  private readonly MAX_FAILED_COUNT: number = 3;       // 连续 3 次无响应判定离线
  private onHeartbeatTimeout: (() => void) | null = null;
  private logger: Logger = new Logger('HeartbeatManager');

  public static getInstance(): HeartbeatManager {
    if (!HeartbeatManager.instance) {
      HeartbeatManager.instance = new HeartbeatManager();
    }
    return HeartbeatManager.instance;
  }

  /** 注册心跳超时回调 */
  public setOnTimeout(callback: () => void): void {
    this.onHeartbeatTimeout = callback;
  }

  /**
   * 启动心跳检测
   * 清除之前的定时器，开启新的周期检测
   */
  public start(): void {
    this.stop();
    this.logger.info('start: 心跳检测启动');
    this.intervalId = setInterval(() => {
      this.failedCount++;
      this.logger.info(`start: 心跳检测 count=${this.failedCount}/${this.MAX_FAILED_COUNT}`);
      if (this.failedCount >= this.MAX_FAILED_COUNT) {
        this.logger.info('start: 心跳超时，判定离线');
        if (this.onHeartbeatTimeout) {
          this.onHeartbeatTimeout();
        }
        this.stop();
      }
    }, this.HEARTBEAT_INTERVAL);
  }

  /**
   * 重置心跳计数器
   * 收到任何消息时应调用此方法，表示连接正常
   */
  public reset(): void {
    if (this.failedCount > 0) {
      this.logger.info('reset: 心跳计数重置');
    }
    this.failedCount = 0;
  }

  /**
   * 停止心跳检测
   * 清除定时器并重置计数器
   */
  public stop(): void {
    if (this.intervalId !== -1) {
      clearInterval(this.intervalId);
      this.intervalId = -1;
      this.logger.info('stop: 心跳检测停止');
    }
    this.failedCount = 0;
  }
}
