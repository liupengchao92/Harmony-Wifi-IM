import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { DatabaseHelper } from '../common/database/DatabaseHelper';
import { IMManager } from '../model/IMManager';

const DOMAIN = 0x0000;
const TAG = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, TAG, '%{public}s', 'EntryAbility onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'EntryAbility onDestroy — 断开所有连接');
    IMManager.getInstance().disconnect();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'EntryAbility onWindowStageCreate');
    this.initApp();
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, '%{public}s', 'Succeeded in loading the content.');
    });
  }

  /**
   * 应用初始化：
   * 1. 初始化数据库（创建表和索引）
   * 2. 生成本机设备 ID（格式：device_<timestamp36进制>）
   * 3. 初始化 IM 核心管理器，注册网络和消息回调
   */
  private async initApp(): Promise<void> {
    // 1. 初始化本地数据库
    await DatabaseHelper.getInstance().init(this.context);
    hilog.info(DOMAIN, TAG, '%{public}s', 'Database initialized');

    // 2. 生成设备信息
    let deviceId: string = this.generateDeviceId();
    let deviceName: string = '我的设备';
    hilog.info(DOMAIN, TAG, 'Device info — ID: %{public}s, Name: %{public}s', deviceId, deviceName);

    // 3. 初始化 IM 管理器
    IMManager.getInstance().init(deviceId, deviceName);
    hilog.info(DOMAIN, TAG, '%{public}s', 'IMManager initialized');
  }

  /**
   * 生成设备唯一标识
   * 格式: device_<timestamp36进制>
   * 注意：重启应用后 ID 会变化，不持久化
   */
  private generateDeviceId(): string {
    return 'device_' + Date.now().toString(36);
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'EntryAbility onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'EntryAbility onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'EntryAbility onBackground');
  }
}
