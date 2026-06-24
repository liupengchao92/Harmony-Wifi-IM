import router from '@ohos.router';
import { SessionListViewModel } from '../viewmodel/SessionListViewModel';
import { SessionModel } from '../model/SessionModel';
import { DateUtil } from '../common/utils/DateUtil';

@Component
export struct SessionListContent {
  @State viewModel: SessionListViewModel = new SessionListViewModel();

  aboutToAppear(): void {
    this.viewModel.loadSessions();
  }

  build() {
    Column() {
      // Header
      Row() {
        Text('消息')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A2E')
          .letterSpacing(-0.3)
        Blank()
        Button('✏')
          .fontSize(20)
          .fontColor('#1A1A2E')
          .backgroundColor(Color.Transparent)
          .width(32)
          .height(32)
      }
      .width('100%')
      .height(44)
      .padding({ left: 16, right: 16 })
      .backgroundColor(Color.White)
      .border({ width: { bottom: 1 }, color: { bottom: '#F0F0F2' } })

      // Session List
      if (this.viewModel.sessions.length === 0) {
        Column() {
          Text('暂无会话')
            .fontSize(14)
            .fontColor('#9E9EB0')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .backgroundColor(Color.White)
      } else {
        List() {
          ForEach(this.viewModel.sessions, (session: SessionModel) => {
            ListItem() {
              this.sessionItem(session)
            }
          }, (session: SessionModel) => session.sessionId)
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }

  @Builder
  sessionItem(session: SessionModel) {
    Row() {
      // 头像
      Stack() {
        Circle()
          .width(48)
          .height(48)
          .fill(session.sessionType === 2 ? '#E0D4F5' : '#D4E4FF')
        Text(session.sessionType === 2 ? this.getGroupAvatarText(session) : session.peerName.charAt(0))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(session.sessionType === 2 ? '#7B5BB5' : '#3B6FD4')

        // 未读角标
        if (session.unreadCount > 0) {
          Text(session.unreadCount > 99 ? '99+' : session.unreadCount.toString())
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .backgroundColor('#E8753A')
            .borderRadius(9)
            .padding({ left: 5, right: 5, top: 2, bottom: 2 })
            .align(Alignment.TopEnd)
            .margin({ top: -2, right: -2 })
        }
      }
      .width(48)
      .height(48)

      // 会话内容
      Column() {
        // 名称 + 时间
        Row() {
          Text(session.sessionType === 2
            ? `${session.peerName} (${session.memberCount}人)`
            : session.peerName)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1A1A2E')
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(DateUtil.formatTime(session.lastMessageTime))
            .fontSize(10)
            .fontColor('#9E9EB0')
            .margin({ left: 8 })
        }
        .width('100%')

        // 最后一条消息
        Text(session.lastMessage)
          .fontSize(12)
          .fontColor('#6B6B80')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4 })
          .width('100%')
      }
      .margin({ left: 12 })
      .layoutWeight(1)
    }
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .width('100%')
    .border({ width: { bottom: 1 }, color: { bottom: '#EAEAEF' } })
    .onClick(() => {
      router.pushUrl({
        url: 'pages/ChatPage',
        params: {
          sessionId: session.sessionId,
          sessionType: session.sessionType,
          peerName: session.peerName
        }
      });
    })
  }

  private getGroupAvatarText(session: SessionModel): string {
    if (!session.peerName) {
      return '群';
    }
    // 取前两个字符作为群头像缩写
    return session.peerName.substring(0, Math.min(2, session.peerName.length));
  }
}
