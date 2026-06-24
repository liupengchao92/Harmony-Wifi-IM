import { MessageModel, MessageType, MessageStatus } from '../model/MessageModel';

@Component
export struct MessageBubble {
  @Prop message: MessageModel = new MessageModel();
  @Prop isGroup: boolean = false;

  build() {
    if (this.message.type === MessageType.SYSTEM_JOIN || this.message.type === MessageType.SYSTEM_LEAVE) {
      this.systemBubble()
    } else if (this.message.isLocal) {
      this.sentBubble()
    } else {
      this.receivedBubble()
    }
  }

  @Builder
  systemBubble() {
    Flex({ justifyContent: FlexAlign.Center }) {
      Text(this.message.content)
        .fontSize(12)
        .fontColor(Color.Gray)
        .padding({ left: 12, right: 12, top: 4, bottom: 4 })
        .backgroundColor('#F5F5F7')
        .borderRadius(12)
    }
    .width('100%')
    .margin({ top: 4, bottom: 4 })
  }

  @Builder
  sentBubble() {
    Flex({ justifyContent: FlexAlign.End }) {
      Column() {
        if (this.message.type === MessageType.IMAGE) {
          Column() {
            Text('🖼')
              .fontSize(48)
              .width(120)
              .height(120)
              .backgroundColor(Color.White)
              .borderRadius(8)
              .clip(true)
          }
          .borderRadius({ topLeft: 12, topRight: 2, bottomLeft: 12, bottomRight: 12 })
          .backgroundColor('#E8753A')
          .padding(4)
        } else {
          Text(this.message.content)
            .fontSize(14)
            .fontColor(Color.White)
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        }
        if (this.message.status === MessageStatus.SENDING) {
          Text('发送中...')
            .fontSize(10)
            .fontColor(Color.White)
            .padding({ left: 12, right: 12, bottom: 4 })
        }
        if (this.message.status === MessageStatus.FAILED) {
          Text('发送失败')
            .fontSize(10)
            .fontColor('#FF3B30')
            .padding({ left: 12, right: 12, bottom: 4 })
        }
      }
      .borderRadius({ topLeft: 12, topRight: 2, bottomLeft: 12, bottomRight: 12 })
      .backgroundColor('#E8753A')
      .constraintSize({ maxWidth: '70%' })
    }
    .width('100%')
    .margin({ top: 4, bottom: 4 })
    .padding({ left: 48, right: 0 })
  }

  @Builder
  receivedBubble() {
    Flex({ justifyContent: FlexAlign.Start }) {
      Column() {
        if (this.isGroup) {
          Text(this.message.senderName)
            .fontSize(11)
            .fontColor('#E8753A')
            .width('100%')
            .padding({ left: 12, top: 4 })
        }
        if (this.message.type === MessageType.IMAGE) {
          Column() {
            Text('🖼')
              .fontSize(48)
              .width(120)
              .height(120)
              .backgroundColor('#EDEDF0')
              .borderRadius(8)
              .clip(true)
          }
          .borderRadius({ topLeft: 2, topRight: 12, bottomLeft: 12, bottomRight: 12 })
          .backgroundColor('#F0F0F2')
          .padding(4)
        } else {
          Text(this.message.content)
            .fontSize(14)
            .fontColor('#1A1A2E')
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        }
      }
      .borderRadius({ topLeft: 2, topRight: 12, bottomLeft: 12, bottomRight: 12 })
      .backgroundColor('#F0F0F2')
      .constraintSize({ maxWidth: '70%' })
    }
    .width('100%')
    .margin({ top: 4, bottom: 4 })
    .padding({ left: 0, right: 48 })
  }
}
