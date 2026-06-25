import { wifiManager } from '@kit.ConnectivityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { router } from '@kit.ArkUI';
import { DeviceItem } from '../model/DeviceItem';
import { SessionModel } from '../model/SessionModel';
import { IMManager } from '../model/IMManager';
import { ConnectionState } from '../common/network/TcpConnectionManager';
import { SessionRepository } from '../common/database/SessionRepository';
import { Logger } from '../common/utils/Logger';

/**
 * 设备列表视图模型
 *
 * 管理设备发现页的所有状态和业务逻辑：
 * 1. Wi-Fi Direct P2P 设备扫描与列表更新
 * 2. 连接设备（p2pConnect）→ TCP 连接 → 自动创建会话 → 跳转聊天
 * 3. 创建 P2P 群组（createGroup）→ 启动 TCP 服务端 → 跳转群聊
 * 4. 监听 P2P 连接状态变化，双向同步连接状态
 */
@Observed
export class DeviceListViewModel {
  devices: DeviceItem[] = [];
  isScanning: boolean = false;
  connectionState: string = '未连接';
  isGroupOwner: boolean = false;
  localDeviceName: string = '';
  localDeviceId: string = '';
  /** 连接/创建群组成功后触发跳转到聊天页的回调 */
  onNavigateToChat: ((sessionId: string, sessionType: number, peerName: string) => void) | null = null;

  private imManager: IMManager = IMManager.getInstance();
  private sessionRepository: SessionRepository = new SessionRepository();
  private logger: Logger = new Logger('DeviceListViewModel');

  public init(): void {
    this.localDeviceName = this.imManager.getLocalDeviceName();
    this.localDeviceId = this.imManager.getLocalDeviceId();
    this.logger.info(`init: deviceName=${this.localDeviceName}, deviceId=${this.localDeviceId}`);
    this.updateConnectionState();
    this.registerConnectionListener();
    this.startDiscovery();
    this.registerP2pListener();
  }

  /** 注册 IM 连接状态回调，TCP 状态变化时更新 UI */
  private registerConnectionListener(): void {
    this.imManager.onConnectionStateChanged(() => {
      this.updateConnectionState();
    });
  }

  /**
   * 注册 Wi-Fi Direct P2P 连接状态变化监听
   * 当 P2P 连接成功后：
   * - 如果本机是 GO：启动 TCP 服务端
   * - 如果本机是 GC：获取 GO 的 IP 地址，发起 TCP 连接
   */
  private registerP2pListener(): void {
    try {
      wifiManager.on('p2pConnectionChange', (result: wifiManager.WifiP2pLinkedInfo) => {
        let connected: boolean = result.connectState === wifiManager.P2pConnectState.CONNECTED;
        this.logger.info(`p2pConnectionChange: connected=${connected}`);
        if (connected) {
          this.connectionState = '已连接';
          // 如果不是 GO，说明是被连接方，需要连接到 GO 的 TCP 服务端
          if (!this.imManager.isGroupOwner()) {
            let goAddr: string = result.groupOwnerAddr;
            this.logger.info(`p2pConnectionChange: 非 GO，连接 GO 地址=${goAddr}`);
            if (goAddr) {
              this.imManager.connect(goAddr);
            }
          }
        }
      });
    } catch (e) {
      this.logger.error('registerP2pListener: 注册失败');
    }
  }

  /**
   * 启动设备发现
   * 调用 wifiManager.startDiscoverDevices() 扫描附近 Wi-Fi Direct 设备
   * 通过 on('p2pPeerDeviceChange') 监听扫描结果
   */
  public startDiscovery(): void {
    this.isScanning = true;
    this.logger.info('startDiscovery: 开始扫描');
    try {
      wifiManager.startDiscoverDevices();
      wifiManager.on('p2pPeerDeviceChange', (data: wifiManager.WifiP2pDevice[]) => {
        let newDevices: DeviceItem[] = [];
        for (let i: number = 0; i < data.length; i++) {
          let d: wifiManager.WifiP2pDevice = data[i];
          // 有设备名称说明设备在线，信号较强 (3 格)；否则信号一般 (2 格)
          let level: number = d.deviceName ? 3 : 2;
          let item: DeviceItem = new DeviceItem();
          item.deviceName = d.deviceName || '未知设备';
          item.deviceAddress = d.deviceAddress;
          item.isConnected = false;
          item.signalLevel = level;
          newDevices.push(item);
        }
        this.devices = newDevices;
        this.logger.info(`startDiscovery: 发现 ${newDevices.length} 台设备`);
      });
    } catch (error) {
      this.isScanning = false;
      this.logger.error('startDiscovery: 扫描失败', error as Error);
    }
  }

  /** 手动刷新设备列表 */
  public refreshDevices(): void {
    this.logger.info('refreshDevices: 手动刷新');
    this.devices = [];
    this.startDiscovery();
  }

  /**
   * 连接到一个 Wi-Fi Direct 设备
   *
   * 流程：
   * 1. wifiManager.p2pConnect() → P2P 连接
   * 2. P2P 连接成功后（p2pConnectionChange 回调）→ TCP 连接
   * 3. 上层在 P2P 成功后调用 onP2pConnected() → 创建会话 → 跳转聊天
   */
  public connectToDevice(deviceAddress: string): void {
    let target: DeviceItem | undefined = this.devices.find(d => d.deviceAddress === deviceAddress);
    if (!target) {
      return;
    }
    this.logger.info(`connectToDevice: device=${target.deviceName} (${deviceAddress})`);
    try {
      let config: wifiManager.WifiP2PConfig = {
        deviceAddress: deviceAddress,
        deviceAddressType: 1,
        netId: -2,        // 永久组，下次可快速重连
        passphrase: '',
        groupName: 'IMGroup',
        goBand: 0
      };
      wifiManager.p2pConnect(config);
      this.connectionState = '连接中...';
    } catch (error) {
      this.connectionState = '连接失败';
      this.logger.error('connectToDevice: P2P 连接失败', error as Error);
    }
  }

  /**
   * P2P 连接成功后的回调（由 DeviceListContent 在延迟后调用）
   * 1. 如果本机是 GO，启动 TCP 服务端
   * 2. 为第一个发现的设备创建单聊会话并跳转
   */
  public async onP2pConnected(): Promise<void> {
    this.isGroupOwner = this.imManager.isGroupOwner();
    this.connectionState = '已连接';
    this.logger.info(`onP2pConnected: isGroupOwner=${this.isGroupOwner}`);

    if (this.isGroupOwner) {
      // 作为 GO：启动 TCP 服务端，等待客户端连接
      this.imManager.startServer();
    }

    // 为第一个在线的设备自动创建单聊会话并跳转
    if (this.devices.length > 0) {
      await this.startChatWithDevice(this.devices[0]);
    }
  }

  /** 创建与指定设备的单聊会话，并触发导航到聊天页 */
  private async startChatWithDevice(device: DeviceItem): Promise<void> {
    let peerId: string = device.deviceAddress;
    let peerName: string = device.deviceName;
    this.logger.info(`startChatWithDevice: peerId=${peerId}, peerName=${peerName}`);
    // 检查是否已有会话，没有则创建
    let existing: SessionModel | null = await this.sessionRepository.getSessionById(peerId);
    if (!existing) {
      peerId = await this.imManager.createSingleSession(peerId, peerName);
    }
    // 触发导航到聊天页
    if (this.onNavigateToChat) {
      this.onNavigateToChat(peerId, 1, peerName);
    }
  }

  /**
   * 创建 P2P 群组（本机作为 GO）
   * 1. wifiManager.createGroup() → 创建群组
   * 2. 启动 TCP 服务端 → 等待成员连接
   */
  public createGroup(): void {
    this.logger.info('createGroup: 创建群组');
    try {
      let config: wifiManager.WifiP2PConfig = {
        deviceAddress: '',
        deviceAddressType: 1,
        netId: -2,
        passphrase: '',
        groupName: 'IMGroup',
        goBand: 0
      };
      wifiManager.createGroup(config);
      this.isGroupOwner = true;
      this.connectionState = '已连接';
      // 创建群组后启动 TCP 服务端
      this.imManager.startServer();
    } catch (error) {
      this.connectionState = '创建群组失败';
      this.logger.error('createGroup: 创建失败', error as Error);
    }
  }

  /**
   * 加入群聊后创建群聊会话并跳转
   * 由 DeviceListContent 在 createGroup() 后延迟调用
   */
  public async joinGroupChat(): Promise<void> {
    let sessionId: string = 'group_' + this.localDeviceId;
    this.logger.info(`joinGroupChat: sessionId=${sessionId}`);
    let existing: SessionModel | null = await this.sessionRepository.getSessionById(sessionId);
    if (!existing) {
      await this.imManager.createSingleSession(sessionId, 'P2P群组');
      // 更新为群聊类型（createSingleSession 默认创建单聊类型）
      let session: SessionModel | null = await this.sessionRepository.getSessionById(sessionId);
      if (session) {
        session.sessionType = 2; // 群聊
        await this.sessionRepository.saveSession(session);
      }
    }
    if (this.onNavigateToChat) {
      this.onNavigateToChat(sessionId, 2, 'P2P群组');
    }
  }

  /** 断开所有连接：停止设备发现 + TCP 断开 */
  public disconnectAll(): void {
    this.logger.info('disconnectAll: 断开所有连接');
    try {
      wifiManager.stopDiscoverDevices();
    } catch (e) {
      // ignore
    }
    this.imManager.disconnect();
    this.connectionState = '未连接';
    this.isGroupOwner = false;
    this.isScanning = false;
    this.devices = [];
  }

  /** 根据 IM 层的连接状态更新 UI 状态 */
  public updateConnectionState(): void {
    let state: ConnectionState = this.imManager.getConnectionState();
    if (state === 2) {
      this.connectionState = '已连接';
      this.isGroupOwner = this.imManager.isGroupOwner();
    } else if (state === 1) {
      this.connectionState = '连接中...';
    } else {
      this.connectionState = '未连接';
    }
  }

  /** 统计在线设备数（signalLevel > 0） */
  public getOnlineCount(): number {
    let count: number = 0;
    for (let i: number = 0; i < this.devices.length; i++) {
      if (this.devices[i].signalLevel > 0) {
        count++;
      }
    }
    return count;
  }
}
