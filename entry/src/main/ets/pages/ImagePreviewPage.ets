import router from '@ohos.router';

@Entry
@Component
struct ImagePreviewPage {
  @State imageName: string = '';
  @State imageSize: string = '';

  aboutToAppear(): void {
    let params = router.getParams() as Record<string, Object>;
    this.imageName = (params.imageName as string) || 'image.jpg';
    this.imageSize = (params.imageSize as string) || '0 B';
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#0F0F1A')

      Column() {
        Text('🖼')
          .fontSize(120)
          .opacity(0.4)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Column() {
        Row() {
          Button('✕')
            .fontSize(18)
            .fontColor(Color.White)
            .backgroundColor('rgba(255,255,255,0.12)')
            .borderRadius(18)
            .width(36)
            .height(36)
            .onClick(() => {
              router.back();
            })

          Blank()

          Text('图片预览')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)

          Blank()

          Button('↓')
            .fontSize(18)
            .fontColor(Color.White)
            .backgroundColor('rgba(255,255,255,0.12)')
            .borderRadius(18)
            .width(36)
            .height(36)
        }
        .padding({ left: 16, right: 16 })
        .width('100%')
      }
      .backgroundColor('rgba(15,15,26,0.85)')
      .padding({ top: 12, bottom: 12 })
      .width('100%')
      .align(Alignment.Top)

      Row() {
        Text(this.imageName)
          .fontSize(14)
          .fontColor('rgba(255,255,255,0.9)')
        Text(this.imageSize)
          .fontSize(12)
          .fontColor('rgba(255,255,255,0.5)')
          .margin({ left: 12 })
      }
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .width('100%')
      .backgroundColor('rgba(15,15,26,0.85)')
      .align(Alignment.Bottom)
    }
    .width('100%')
    .height('100%')
  }
}
