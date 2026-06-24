import { wifiManager } from '@kit.ConnectivityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { DeviceItem } from '../model/DeviceItem';
import { IMManager } from '../model/IMManager';

@Observed
export class DeviceListViewModel {
  devices: DeviceItem[] = [];
  isScanning: boolean = false;
  connectionState: string = '未连接';
  isGroupOwner: boolean = false;
  localDeviceName: string = '';
  localDeviceId: string = '';

  private imManager: IMManager = IMManager.getInstance();

  public init(): void {
    this.localDeviceName = this.imManager.getLocalDeviceName();
    this.localDeviceId = this.imManager.getLocalDeviceId();
    this.updateConnectionState();
    this.startDiscovery();
  }

  public startDiscovery(): void {
    this.isScanning = true;
    try {
      wifiManager.startDiscoverDevices();
      wifiManager.on('p2pPeerDeviceChange', (data: wifiManager.WifiP2pDevice[]) => {
        let newDevices: DeviceItem[] = [];
        for (let i = 0; i < data.length; i++) {
          let d = data[i];
          let level = d.deviceName ? 3 : 2;
          let item = new DeviceItem();
          item.deviceName = d.deviceName || '未知设备';
          item.deviceAddress = d.deviceAddress;
          item.isConnected = false;
          item.signalLevel = level;
          newDevices.push(item);
        }
        this.devices = newDevices;
      });
    } catch (error) {
      this.isScanning = false;
    }
  }

  public refreshDevices(): void {
    this.devices = [];
    this.startDiscovery();
  }

  public connectToDevice(deviceAddress: string): void {
    let target = this.devices.find(d => d.deviceAddress === deviceAddress);
    if (!target) {
      return;
    }
    try {
      let config: wifiManager.WifiP2PConfig = {
        deviceAddress: deviceAddress,
        deviceAddressType: 1,
        netId: -2,
        passphrase: '',
        groupName: 'IMGroup',
        goBand: 0
      };
      wifiManager.p2pConnect(config);
      this.imManager.startServer();
      this.isGroupOwner = this.imManager.isGroupOwner();
      this.connectionState = '已连接';
    } catch (error) {
      this.connectionState = '连接失败';
    }
  }

  public createGroup(): void {
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
      this.imManager.startServer();
      this.isGroupOwner = true;
      this.connectionState = '已连接';
    } catch (error) {
      this.connectionState = '创建群组失败';
    }
  }

  public disconnectAll(): void {
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

  public updateConnectionState(): void {
    let state = this.imManager.getConnectionState();
    if (state === 2) {
      this.connectionState = '已连接';
      this.isGroupOwner = this.imManager.isGroupOwner();
    } else if (state === 1) {
      this.connectionState = '连接中...';
    } else {
      this.connectionState = '未连接';
    }
  }

  public getOnlineCount(): number {
    let count = 0;
    for (let i = 0; i < this.devices.length; i++) {
      if (this.devices[i].signalLevel > 0) {
        count++;
      }
    }
    return count;
  }
}
