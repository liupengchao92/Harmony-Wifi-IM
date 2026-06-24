export class HeartbeatManager {
  private static instance: HeartbeatManager;
  private intervalId: number = -1;
  private failedCount: number = 0;
  private readonly HEARTBEAT_INTERVAL: number = 10000;
  private readonly MAX_FAILED_COUNT: number = 3;
  private onHeartbeatTimeout: (() => void) | null = null;

  public static getInstance(): HeartbeatManager {
    if (!HeartbeatManager.instance) {
      HeartbeatManager.instance = new HeartbeatManager();
    }
    return HeartbeatManager.instance;
  }

  public setOnTimeout(callback: () => void): void {
    this.onHeartbeatTimeout = callback;
  }

  public start(): void {
    this.stop();
    this.intervalId = setInterval(() => {
      this.failedCount++;
      if (this.failedCount >= this.MAX_FAILED_COUNT) {
        if (this.onHeartbeatTimeout) {
          this.onHeartbeatTimeout();
        }
        this.stop();
      }
    }, this.HEARTBEAT_INTERVAL);
  }

  public reset(): void {
    this.failedCount = 0;
  }

  public stop(): void {
    if (this.intervalId !== -1) {
      clearInterval(this.intervalId);
      this.intervalId = -1;
    }
    this.failedCount = 0;
  }
}
