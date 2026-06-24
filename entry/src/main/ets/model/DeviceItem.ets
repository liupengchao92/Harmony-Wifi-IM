export class DeviceItem {
  deviceName: string = '';
  deviceAddress: string = '';
  isConnected: boolean = false;
  signalLevel: number = 0;

  constructor(data?: Partial<DeviceItem>) {
    if (data) {
      this.deviceName = data.deviceName ?? this.deviceName;
      this.deviceAddress = data.deviceAddress ?? this.deviceAddress;
      this.isConnected = data.isConnected ?? this.isConnected;
      this.signalLevel = data.signalLevel ?? this.signalLevel;
    }
  }
}
