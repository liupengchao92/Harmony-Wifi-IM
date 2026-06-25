import { DeviceListViewModel } from '../viewmodel/DeviceListViewModel';
import { DeviceItem } from '../model/DeviceItem';
import router from '@ohos.router';

const AVATAR_COLORS: string[] = ['#4A90D9', '#7B68EE', '#E8A838', '#50C878', '#D44C4C', '#4CAF50', '#FF7043', '#5C6BC0'];

@Component
export struct DeviceListContent {
  @State viewModel: DeviceListViewModel = new DeviceListViewModel();

  aboutToAppear(): void {
    this.viewModel.init();
    // 绑定导航回调：连接/创建群组成功后自动跳转到聊天页
    this.viewModel.onNavigateToChat = (sessionId: string, sessionType: number, peerName: string) => {
      router.pushUrl({
        url: 'pages/ChatPage',
        params: {
          sessionId: sessionId,
          sessionType: sessionType,
          peerName: peerName
        }
      });
    };
  }

  build() {
    Column() {
      // Header
      Row() {
        Blank().width(32)
        Text('设备发现')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A2E')
          .letterSpacing(-0.3)
        Blank().width(32)
      }
      .width('100%')
      .height(44)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(Color.White)
      .border({ width: { bottom: 1 }, color: { bottom: '#F0F0F2' } })

      Scroll() {
        Column() {
          this.myDeviceCard()
          this.nearbyHeader()
          this.deviceList()
          this.bottomArea()
        }
        .padding({ left: 16, right: 16, top: 16, bottom: 24 })
        .height('100%')
      }
      .layoutWeight(1)
    }
    .backgroundColor('#F5F5F7')
    .width('100%')
    .height('100%')
  }

  // =================== 我的设备卡片 ===================
  @Builder
  myDeviceCard() {
    Column() {
      Row() {
        // 头像
        Stack() {
          Circle()
            .width(40)
            .height(40)
            .fill('#E8753A')
          Text(this.getAvatarText(this.viewModel.localDeviceName || 'H'))
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width(40)
        .height(40)

        // 设备名称 + ID
        Column() {
          Text(this.viewModel.localDeviceName || '我的 HarmonyOS 设备')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A2E')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('ID: ' + (this.viewModel.localDeviceId || 'HW-0000'))
            .fontSize(12)
            .fontColor('#9E9EB0')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 12 })
        .layoutWeight(1)
      }
      .width('100%')

      // 连接状态（对齐头像右侧文字）
      Row() {
        Circle()
          .width(8)
          .height(8)
          .fill(this.viewModel.connectionState === '已连接' ? '#34C759' : '#9E9EB0')
        Text(this.viewModel.connectionState === '已连接' ? 'Wi-Fi Direct 已连接' : '未连接')
          .fontSize(12)
          .fontColor(this.viewModel.connectionState === '已连接' ? '#34C759' : '#9E9EB0')
          .margin({ left: 6 })
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .border({ width: 1, color: '#F0F0F2' })
    .margin({ bottom: 16 })
  }

  // =================== 附近设备标题 ===================
  @Builder
  nearbyHeader() {
    Row() {
      Text('附近设备')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A2E')
      Blank()
      Row() {
        Text('↻')
          .fontSize(14)
          .fontColor('#E8753A')
        Text('刷新')
          .fontSize(12)
          .fontColor('#E8753A')
          .margin({ left: 2 })
      }
      .onClick(() => {
        this.viewModel.refreshDevices();
      })
    }
    .width('100%')
    .margin({ bottom: 12 })
  }

  // =================== 设备列表 ===================
  @Builder
  deviceList() {
    Column() {
      if (this.viewModel.devices.length === 0) {
        Text('未发现附近设备')
          .fontSize(14)
          .fontColor('#9E9EB0')
          .width('100%')
          .padding(32)
          .textAlign(TextAlign.Center)
      }
      ForEach(this.viewModel.devices, (device: DeviceItem, index: number) => {
        this.deviceItem(device, index)
      }, (device: DeviceItem) => device.deviceAddress)
    }
    .width('100%')
    .backgroundColor(Color.White)
    .borderRadius(12)
    .border({ width: 1, color: '#F0F0F2' })
    .clip(true)
  }

  @Builder
  deviceItem(device: DeviceItem, index: number) {
    Row() {
      // 头像
      Stack() {
        Circle()
          .width(40)
          .height(40)
          .fill(AVATAR_COLORS[index % AVATAR_COLORS.length])
        Text(this.getAvatarText(device.deviceName))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      .width(40)
      .height(40)

      // 设备名称 + 信号状态
      Column() {
        Text(device.deviceName)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A2E')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row() {
          this.signalBars(device.signalLevel)
          Text(device.signalLevel > 2 ? '在线' : '可连接')
            .fontSize(12)
            .fontColor(device.signalLevel > 2 ? '#34C759' : '#9E9EB0')
            .margin({ left: 6 })
        }
        .alignItems(VerticalAlign.Center)
        .margin({ top: 2 })
      }
      .margin({ left: 12 })
      .layoutWeight(1)

      // 连接按钮
      if (device.signalLevel > 2) {
        Button('连接')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor('#E8753A')
          .borderRadius(8)
          .height(30)
          .padding({ left: 12, right: 12 })
          .onClick(() => {
            this.viewModel.connectToDevice(device.deviceAddress);
            // P2P 连接成功后自动跳转聊天
            setTimeout(() => {
              this.viewModel.onP2pConnected();
            }, 2000);
          })
      } else {
        Button('连接')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#E8753A')
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: '#E8753A' })
          .borderRadius(8)
          .height(30)
          .padding({ left: 12, right: 12 })
          .onClick(() => {
            this.viewModel.connectToDevice(device.deviceAddress);
            // P2P 连接成功后自动跳转聊天
            setTimeout(() => {
              this.viewModel.onP2pConnected();
            }, 2000);
          })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Center)
  }

  // =================== 信号强度条 ===================
  @Builder
  signalBars(level: number) {
    Row() {
      ForEach([0, 1, 2, 3], (i: number) => {
        Rect()
          .width(3)
          .radius(0.5)
          .height(4 + i * 4)
          .fill(i < level ? '#E8753A' : '#E5E5EA')
          .margin({ left: i > 0 ? 2 : 0 })
      }, (i: number) => i.toString())
    }
    .alignItems(VerticalAlign.Bottom)
    .height(16)
  }

  // =================== 底部操作区 ===================
  @Builder
  bottomArea() {
    Column() {
      Button() {
        Row() {
          Text('☰')
            .fontSize(16)
            .fontColor(Color.White)
            .margin({ right: 6 })
          Text('创建群组')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
        }
        .alignItems(VerticalAlign.Center)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height(44)
      .backgroundColor('#E8753A')
      .borderRadius(12)
      .onClick(() => {
        this.viewModel.createGroup();
        // 创建群组后自动进入群聊
        setTimeout(() => {
          this.viewModel.joinGroupChat();
        }, 1500);
      })

      Text(`已发现 ${this.viewModel.devices.length} 台设备，${this.getOnlineCount()} 台在线`)
        .fontSize(12)
        .fontColor('#9E9EB0')
        .margin({ top: 12 })
    }
    .margin({ top: 24 })
    .width('100%')
  }

  getAvatarText(name: string): string {
    if (!name) {
      return '?';
    }
    return name.charAt(0);
  }

  getOnlineCount(): number {
    let count = 0;
    for (let i = 0; i < this.viewModel.devices.length; i++) {
      if (this.viewModel.devices[i].signalLevel > 2) {
        count++;
      }
    }
    return count;
  }
}
