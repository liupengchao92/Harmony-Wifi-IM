import router from '@ohos.router';
import { ChatViewModel } from '../viewmodel/ChatViewModel';
import { MessageModel, MessageType } from '../model/MessageModel';
import { MessageBubble } from '../components/MessageBubble';

@Entry
@Component
struct ChatPage {
  @State viewModel: ChatViewModel = new ChatViewModel();
  @State inputText: string = '';
  @State sessionId: string = '';
  @State sessionType: number = 1;
  @State peerName: string = '';
  /** 消息列表滚动控制器 */
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    let params: Record<string, Object> = router.getParams() as Record<string, Object>;
    this.sessionId = params.sessionId as string;
    this.sessionType = params.sessionType as number;
    this.peerName = params.peerName as string;
    this.viewModel.init(this.sessionId, this.sessionType, this.peerName);
    this.viewModel.clearUnread();

    // 新消息到达时自动滚动到底部
    this.viewModel.onMessageAdded = () => {
      this.scrollToBottom(80);
    };

    // 页面打开后等待历史消息加载完成，滚动到底部
    setTimeout(() => {
      this.scrollToBottom(80);
    }, 300);
  }

  /**
   * 滚动消息列表到底部（最新消息） — 微信行为：
   *
   * 使用 scrollTo + 极大的 yOffset 替代 scrollEdge，原因：
   * - HarmonyOS 的 scrollEdge 存在内部 Lock 机制，重复调用会被忽略
   * - scrollTo 不受 Lock 限制，每次都能可靠执行
   *
   * @param delay 延迟毫秒数，默认 80ms。键盘弹起场景建议 300ms。
   */
  private scrollToBottom(delay: number = 80): void {
    setTimeout(() => {
      this.scroller.scrollTo({
        xOffset: 0,
        yOffset: 999999,
        animation: false
      });
    }, delay);
  }

  build() {
    Column() {
      this.header()
      this.messageList()
      this.inputBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F7')
  }

  @Builder
  header() {
    Row() {
      Button('←')
        .fontSize(20)
        .fontColor('#1A1A2E')
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          router.back();
        })

      Column() {
        Text(this.peerName)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A2E')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.sessionType === 2) {
          Text(this.viewModel.groupMemberCount + ' 人')
            .fontSize(12)
            .fontColor('#9E9EB0')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      if (this.sessionType === 2) {
        Button('⋯')
          .fontSize(20)
          .fontColor('#1A1A2E')
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            router.pushUrl({
              url: 'pages/GroupDetailPage',
              params: { sessionId: this.sessionId }
            });
          })
      } else {
        Row()
          .width(32)
          .height(32)
      }
    }
    .width('100%')
    .height(52)
    .padding({ left: 8, right: 8, top: 8, bottom: 8 })
    .backgroundColor(Color.White)
    .border({ width: { bottom: 0.5 }, color: { bottom: '#E5E5EA' } })
    .expandSafeArea([SafeAreaType.KEYBOARD])
    .zIndex(999)
  }

  @Builder
  messageList() {
    List({ scroller: this.scroller }) {
      ForEach(this.viewModel.messages, (message: MessageModel) => {
        ListItem() {
          if (message.type === MessageType.SYSTEM_JOIN || message.type === MessageType.SYSTEM_LEAVE) {
            MessageBubble({ message: message, isGroup: this.sessionType === 2 })
          } else if (this.sessionType === 2 && !message.isLocal) {
            Row() {
              Circle()
                .width(32)
                .height(32)
                .fill('#E8753A')
                .margin({ right: 8, top: 4 })
              MessageBubble({ message: message, isGroup: true })
            }
            .padding({ left: 12, right: 12 })
          } else {
            MessageBubble({ message: message, isGroup: false })
          }
        }
        .padding({ left: 12, right: 12 })
      }, (message: MessageModel) => message.messageId)
    }
    .layoutWeight(1)
    .width('100%')
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  inputBar() {
    Row() {
      Button('+')
        .fontSize(24)
        .fontColor('#6B6B80')
        .backgroundColor(Color.Transparent)
        .width(40)
        .height(40)
        .onClick(() => {
          this.viewModel.sendImageMessage('photo.jpg');
        })

      TextInput({ placeholder: '输入消息...', text: this.inputText })
        .layoutWeight(1)
        .height(40)
        .backgroundColor('#F0F0F2')
        .borderRadius(20)
        .padding({ left: 16, right: 16 })
        .onChange((value: string) => {
          this.inputText = value;
        })
        .onEditChange((isEditing: boolean) => {
          if (isEditing) {
            this.scrollToBottom(300);
          }
        })

      Button('发送')
        .fontSize(14)
        .fontColor(Color.White)
        .backgroundColor('#E8753A')
        .borderRadius(20)
        .height(36)
        .margin({ left: 8 })
        .onClick(() => {
          this.viewModel.sendTextMessage(this.inputText);
          this.inputText = '';
          // 发送新消息后滚动到底部展示
          this.scrollToBottom();
        })
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 8, bottom: 8 })
    .backgroundColor(Color.White)
    .border({ width: { top: 0.5 }, color: { top: '#E5E5EA' } })
  }
}
