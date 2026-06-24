import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;

export class Logger {
  private tag: string;

  constructor(tag: string) {
    this.tag = tag;
  }

  public info(msg: string): void {
    hilog.info(DOMAIN, this.tag, '%{public}s', msg);
  }

  public debug(msg: string): void {
    hilog.debug(DOMAIN, this.tag, '%{public}s', msg);
  }

  public warn(msg: string): void {
    hilog.warn(DOMAIN, this.tag, '%{public}s', msg);
  }

  public error(msg: string, err?: Error): void {
    if (err) {
      hilog.error(DOMAIN, this.tag, '%{public}s: %{public}s', msg, JSON.stringify(err));
    } else {
      hilog.error(DOMAIN, this.tag, '%{public}s', msg);
    }
  }
}
