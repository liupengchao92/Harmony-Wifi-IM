import { DeviceListContent } from '../components/DeviceListContent';
import { SessionListContent } from '../components/SessionListContent';
import { SettingsContent } from '../components/SettingsContent';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;

  build() {
    Column() {
      Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
        TabContent() {
          SessionListContent()
        }
        .tabBar(this.buildTab(0, '消息', $r('app.media.ic_tab_message_normal'), $r('app.media.ic_tab_message_selected')))

        TabContent() {
          DeviceListContent()
        }
        .tabBar(this.buildTab(1, '设备', $r('app.media.ic_tab_device_normal'), $r('app.media.ic_tab_device_selected')))

        TabContent() {
          SettingsContent()
        }
        .tabBar(this.buildTab(2, '设置', $r('app.media.ic_tab_setting_normal'), $r('app.media.ic_tab_setting_selected')))
      }
      .barBackgroundColor(Color.White)
      .onChange((index: number) => {
        this.currentIndex = index;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F7')
  }

  @Builder
  buildTab(index: number, label: string, normalIcon: Resource, selectedIcon: Resource) {
    Column() {
      Image(this.currentIndex === index ? selectedIcon : normalIcon)
        .width(24)
        .height(24)
        .objectFit(ImageFit.Contain)
      Text(label)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.currentIndex === index ? '#E8753A' : '#9E9EB0')
        .margin({ top: 2 })
      Circle()
        .width(4)
        .height(4)
        .fill(this.currentIndex === index ? '#E8753A' : Color.Transparent)
        .margin({ top: 1 })
    }
    .justifyContent(FlexAlign.Center)
    .height(54)
    .width('100%')
  }
}
