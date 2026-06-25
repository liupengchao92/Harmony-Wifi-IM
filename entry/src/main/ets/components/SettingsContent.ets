import { IMManager } from '../model/IMManager';
import { wifiManager } from '@kit.ConnectivityKit';
import { common } from '@kit.AbilityKit';
import { Logger } from '../common/utils/Logger';

@Component
export struct SettingsContent {
  @State deviceName: string = '我的设备';
  @State isGroupOwner: boolean = false;
  @State wifiEnabled: boolean = false;
  @State groupMemberCount: number = 0;
  @State groupName: string = 'P2P群组';
  @State messageHistoryOn: boolean = true;
  @State notificationOn: boolean = true;
  @State autoSaveImage: boolean = false;
  @State showExitConfirm: boolean = false;
  private imManager: IMManager = IMManager.getInstance();
  private logger: Logger = new Logger('SettingsContent');

  aboutToAppear(): void {
    this.deviceName = this.imManager.getLocalDeviceName();
    this.isGroupOwner = this.imManager.isGroupOwner();
    this.groupMemberCount = this.imManager.getGroupMembers().length;
    this.checkWifiState();
  }

  private checkWifiState(): void {
    try {
      let isConnected = wifiManager.isConnected();
      this.wifiEnabled = isConnected;
    } catch (e) {
      this.wifiEnabled = false;
    }
  }

  build() {
    Stack() {
      Column() {
        // Header
        Row() {
          Text('设置')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A2E')
          Blank()
        }
        .width('100%')
        .height(44)
        .padding({ left: 16, right: 16 })
        .backgroundColor(Color.White)
        .border({ width: { bottom: 1 }, color: { bottom: '#E5E5EA' } })

        Scroll() {
          Column() {
            this.deviceInfoSection()
            this.connectionSection()
            this.generalSection()
            this.aboutSection()
            this.exitButton()
          }
          .padding({
            left: 16,
            right: 16,
            top: 24,
            bottom: 32
          })
        }
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F5F7')

      // 退出确认对话框
      if (this.showExitConfirm) {
        Column() {
          Column() {
            Text('退出应用')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A2E')
              .margin({ bottom: 8 })
            Text('确定要退出应用吗？所有连接将被断开。')
              .fontSize(14)
              .fontColor('#6B6B80')
              .margin({ bottom: 20 })
            Row() {
              Button('取消')
                .fontSize(14)
                .fontColor('#6B6B80')
                .backgroundColor('#F0F0F2')
                .borderRadius(8)
                .height(40)
                .layoutWeight(1)
                .onClick(() => {
                  this.showExitConfirm = false;
                })
              Blank().width(12)
              Button('确定退出')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(Color.White)
                .backgroundColor('#FF3B30')
                .borderRadius(8)
                .height(40)
                .layoutWeight(1)
                .onClick(() => {
                  this.showExitConfirm = false;
                  this.disconnectAll();
                  this.exitApp()
                })
            }
            .width('100%')
          }
          .width('80%')
          .padding(24)
          .backgroundColor(Color.White)
          .borderRadius(16)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(0, 0, 0, 0.45)')
      }
    }
    .width('100%')
    .height('100%')
  }

  // =================== 设备信息 ===================
  @Builder
  deviceInfoSection() {
    Column() {
      this.sectionTitle('设备信息')

      Column() {
        // 设备名称
        Row() {
          Text('设备名称')
            .fontSize(15)
            .fontColor('#1A1A2E')
          Blank()
          Text(this.deviceName)
            .fontSize(14)
            .fontColor('#6B6B80')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('›')
            .fontSize(20)
            .fontColor('#9E9EB0')
            .margin({ left: 8 })
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .border({ width: { bottom: 1 }, color: { bottom: '#E5E5EA' } })

        // 设备 ID
        Row() {
          Text('设备 ID')
            .fontSize(15)
            .fontColor('#1A1A2E')
          Blank()
          Text(this.imManager.getLocalDeviceId())
            .fontSize(14)
            .fontColor('#6B6B80')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .border({ width: { bottom: 1 }, color: { bottom: '#E5E5EA' } })

        // Wi-Fi 状态
        Row() {
          Text('Wi-Fi 状态')
            .fontSize(15)
            .fontColor('#1A1A2E')
          Blank()
          Row() {
            Circle()
              .width(8)
              .height(8)
              .fill(this.wifiEnabled ? '#34C759' : '#9E9EB0')
              .margin({ right: 6 })
            Text(this.wifiEnabled ? '已开启' : '未开启')
              .fontSize(14)
              .fontColor(this.wifiEnabled ? '#34C759' : '#6B6B80')
          }
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
      }
      .backgroundColor(Color.White)
      .borderRadius(12)
      .border({ width: 1, color: '#E5E5EA' })
    }
    .width('100%')
    .margin({ bottom: 24 })
  }

  // =================== 连接管理 ===================
  @Builder
  connectionSection() {
    Column() {
      this.sectionTitle('连接管理')

      Column() {
        // Wi-Fi Direct 状态
        Row() {
          Text('Wi-Fi Direct')
            .fontSize(15)
            .fontColor('#1A1A2E')
          Blank()
          Text(this.imManager.getConnectionState() === 2 ? '已连接' : '未连接')
            .fontSize(14)
            .fontColor(this.imManager.getConnectionState() === 2 ? '#34C759' : '#6B6B80')
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .border({ width: { bottom: 1 }, color: { bottom: '#E5E5EA' } })

        // 当前群组
        Row() {
          Text('当前群组')
            .fontSize(15)
            .fontColor('#1A1A2E')
          Blank()
          Text(`${this.groupName} (${this.groupMemberCount}人)`)
            .fontSize(14)
            .fontColor('#6B6B80')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('›')
            .fontSize(20)
            .fontColor('#9E9EB0')
            .margin({ left: 8 })
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .border({ width: { bottom: 1 }, color: { bottom: '#E5E5EA' } })

        // 本机角色
        Row() {
          Text('本机角色')
            .fontSize(15)
            .fontColor('#1A1A2E')
          Blank()
          Text(this.isGroupOwner ? 'Group Owner (群主)' : 'Group Client (成员)')
            .fontSize(14)
            .fontColor('#6B6B80')
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .border({ width: { bottom: 1 }, color: { bottom: '#E5E5EA' } })

        // 断开连接 (危险操作)
        Row() {
          Text('断开连接')
            .fontSize(15)
            .fontColor('#1A1A2E')
          Blank()
          Text('断开所有连接')
            .fontSize(14)
            .fontColor('#FF3B30')
          Text('›')
            .fontSize(20)
            .fontColor('#FF3B30')
            .margin({ left: 8 })
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .border({ width: { left: 2 }, color: { left: '#FF3B30' } })
        .onClick(() => {
          this.disconnectAll();
        })
      }
      .backgroundColor(Color.White)
      .borderRadius(12)
      .border({ width: 1, color: '#E5E5EA' })
    }
    .width('100%')
    .margin({ bottom: 24 })
  }

  // =================== 通用设置 ===================
  @Builder
  generalSection() {
    Column() {
      this.sectionTitle('通用设置')

      Column() {
        // 消息记录
        Row() {
          Text('消息记录')
            .fontSize(15)
            .fontColor('#1A1A2E')
          Blank()
          Toggle({ type: ToggleType.Switch, isOn: this.messageHistoryOn })
            .selectedColor('#E8753A')
            .switchPointColor(Color.White)
            .onChange((isOn: boolean) => {
              this.messageHistoryOn = isOn;
            })
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .border({ width: { bottom: 1 }, color: { bottom: '#E5E5EA' } })

        // 新消息通知
        Row() {
          Text('新消息通知')
            .fontSize(15)
            .fontColor('#1A1A2E')
          Blank()
          Toggle({ type: ToggleType.Switch, isOn: this.notificationOn })
            .selectedColor('#E8753A')
            .switchPointColor(Color.White)
            .onChange((isOn: boolean) => {
              this.notificationOn = isOn;
            })
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .border({ width: { bottom: 1 }, color: { bottom: '#E5E5EA' } })

        // 图片自动保存
        Row() {
          Text('图片自动保存')
            .fontSize(15)
            .fontColor('#1A1A2E')
          Blank()
          Toggle({ type: ToggleType.Switch, isOn: this.autoSaveImage })
            .selectedColor('#E8753A')
            .switchPointColor(Color.White)
            .onChange((isOn: boolean) => {
              this.autoSaveImage = isOn;
            })
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
      }
      .backgroundColor(Color.White)
      .borderRadius(12)
      .border({ width: 1, color: '#E5E5EA' })
    }
    .width('100%')
    .margin({ bottom: 24 })
  }

  // =================== 关于 ===================
  @Builder
  aboutSection() {
    Column() {
      this.sectionTitle('关于')

      Column() {
        // 版本
        Row() {
          Text('版本')
            .fontSize(15)
            .fontColor('#1A1A2E')
          Blank()
          Text('V1.0.0')
            .fontSize(14)
            .fontColor('#6B6B80')
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .border({ width: { bottom: 1 }, color: { bottom: '#E5E5EA' } })

        // 技术底座
        Row() {
          Text('技术底座')
            .fontSize(15)
            .fontColor('#1A1A2E')
          Blank()
          Text('HarmonyOS + Wi-Fi Direct')
            .fontSize(14)
            .fontColor('#6B6B80')
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
      }
      .backgroundColor(Color.White)
      .borderRadius(12)
      .border({ width: 1, color: '#E5E5EA' })
    }
    .width('100%')
    .margin({ bottom: 24 })
  }

  // =================== 退出应用 ===================
  @Builder
  exitButton() {
    Button('退出应用')
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .fontColor('#FF3B30')
      .backgroundColor(Color.Transparent)
      .border({ width: 1, color: '#FF3B30', style: BorderStyle.Solid })
      .borderRadius(12)
      .width('100%')
      .height(44)
      .onClick(() => {
        this.showExitConfirm = true;
      })
      .margin({ top: 8, bottom: 16 })
  }

  // =================== 辅助方法 ===================
  @Builder
  sectionTitle(title: string) {
    Text(title)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor('#6B6B80')
      .width('100%')
      .padding({ bottom: 8 })
  }

  /** 断开所有 Wi-Fi Direct 连接和 TCP 连接 */
  private disconnectAll(): void {
    this.logger.info('disconnectAll: 断开所有连接');
    try {
      wifiManager.stopDiscoverDevices();
    } catch (e) {
      // ignore
    }
    this.imManager.disconnect();
  }

  /** 退出应用：通过 UIAbilityContext 终止当前 Ability */
  private exitApp(): void {
    this.logger.info('exitApp: 退出应用');
    try {
      let ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      ctx.terminateSelf();
    } catch (e) {
      this.logger.error('exitApp: 退出失败', e as Error);
    }
  }
}
