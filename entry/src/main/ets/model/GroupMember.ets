/**
 * 群组成员数据模型
 *
 * 存储群组成员的设备标识、展示名称、角色及在线状态。
 * 用于群详情页成员列表渲染。
 */
export class GroupMember {
  deviceId: string = '';
  deviceName: string = '';
  isOwner: boolean = false;
  isOnline: boolean = true;

  constructor(deviceId?: string, deviceName?: string, isOwner?: boolean, isOnline?: boolean) {
    if (deviceId) {
      this.deviceId = deviceId;
    }
    if (deviceName) {
      this.deviceName = deviceName;
    }
    if (isOwner !== undefined) {
      this.isOwner = isOwner;
    }
    if (isOnline !== undefined) {
      this.isOnline = isOnline;
    }
  }

  /** 获取头像显示的文字（取设备名首字符） */
  public getAvatarText(): string {
    if (!this.deviceName) {
      return '?';
    }
    return this.deviceName.charAt(0);
  }
}
