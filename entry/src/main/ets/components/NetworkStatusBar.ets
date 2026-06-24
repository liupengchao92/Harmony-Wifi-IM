@Component
export struct NetworkStatusBar {
  @Prop statusText: string = '未连接';
  @Prop isConnected: boolean = false;

  build() {
    Row() {
      Circle()
        .width(8)
        .height(8)
        .fill(this.isConnected ? Color.Green : Color.Gray)
      Text(this.statusText)
        .fontSize(12)
        .fontColor(this.isConnected ? '#34C759' : '#9E9EB0')
        .margin({ left: 6 })
    }
    .padding({ left: 16, right: 16, top: 6, bottom: 6 })
    .width('100%')
    .backgroundColor('#F9F9FB')
  }
}
