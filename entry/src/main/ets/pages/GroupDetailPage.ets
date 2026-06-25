import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { GroupDetailViewModel } from '../viewmodel/GroupDetailViewModel';
import { GroupMember } from '../model/GroupMember';
import { DateUtil } from '../common/utils/DateUtil';

/** 成员头像调色板 */
const AVATAR_COLORS: string[] = [
  '#D1E8FF', '#E8D5F5', '#D1F5E0', '#FFE5D1',
  '#D1F0F5', '#F5E5D1', '#E5D1F5', '#F5D1E5',
];
const AVATAR_TEXT_COLORS: string[] = [
  '#3B82F6', '#8B5CF6', '#22C55E', '#F59E0B',
  '#06B6D4', '#E8753A', '#7C3AED', '#EC4899',
];

/**
 * 根据字符串哈希获取头像背景色索引
 * 同一成员始终返回同一颜色
 */
function getAvatarColorIndex(name: string): number {
  let hash: number = 0;
  for (let i: number = 0; i < name.length; i++) {
    hash = ((hash << 5) - hash) + name.charCodeAt(i);
    hash = hash & hash;
  }
  return Math.abs(hash) % AVATAR_COLORS.length;
}

@Entry
@Component
struct GroupDetailPage {
  @State viewModel: GroupDetailViewModel = new GroupDetailViewModel();
  @State sessionId: string = '';

  aboutToAppear(): void {
    let params: Record<string, Object> = router.getParams() as Record<string, Object>;
    this.sessionId = params.sessionId as string;
    this.viewModel.init(this.sessionId);
  }

  build() {
    Column() {
      this.header()
      this.groupInfoSection()
      this.mainContent()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F7')
  }

  // =================== Header ===================

  @Builder
  header() {
    Row() {
      Button('←')
        .fontSize(20)
        .fontColor('#1A1A2E')
        .backgroundColor(Color.Transparent)
        .width(32)
        .height(32)
        .onClick(() => {
          router.back();
        })

      Text('群详情')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A2E')
        .letterSpacing(-0.3)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      // 占位，保持标题居中
      Row()
        .width(32)
        .height(32)
    }
    .width('100%')
    .height(44)
    .padding({ left: 16, right: 16 })
    .backgroundColor(Color.White)
    .border({ width: { bottom: 0.5 }, color: { bottom: '#F0F0F2' } })
    .zIndex(999)
  }

  // =================== Main Content ===================

  @Builder
  mainContent() {
    Scroll() {
      Column() {
        this.memberSection()
        this.actionSection()
        // 底部安全区域
        Row()
          .width('100%')
          .height(34)
          .backgroundColor('#F5F5F7')
      }
      .height('100%')
      .width('100%')
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  // =================== Group Info Section ===================

  @Builder
  groupInfoSection() {
    Column() {
      // 头像带径向光晕
      Stack() {
        // 光晕背景
        Circle()
          .width(96)
          .height(96)
          .fill('rgba(232, 117, 58, 0.08)')

        // 头像
        Circle()
          .width(64)
          .height(64)
          .fill('#E8753A')

        Text(this.getGroupAvatarText())
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      .width(96)
      .height(96)
      .margin({ bottom: 12 })

      // 群组名称
      Text(this.viewModel.groupName)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A2E')
        .letterSpacing(-0.4)
        .margin({ bottom: 4 })

      // 群组 ID
      Text(this.viewModel.groupId)
        .fontSize(12)
        .fontColor('#6B6B80')
        .margin({ bottom: 4 })

      // 创建时间
      Text('创建时间: ' + DateUtil.formatDateTime(this.viewModel.createdTime))
        .fontSize(12)
        .fontColor('#9E9EB0')
    }
    .width('100%')
    .padding({ top: 24, bottom: 24, left: 16, right: 16 })
    .backgroundColor(Color.White)
  }

  // =================== Member Section ===================

  @Builder
  memberSection() {
    Column() {
      // 标题
      Text('群组成员 (' + this.viewModel.memberCount + ')')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A2E')
        .width('100%')
        .padding({ left: 16, right: 16, top: 24, bottom: 12 })

      // 成员列表卡片
      Column() {
        ForEach(this.viewModel.members, (member: GroupMember, index: number) => {
          this.memberItem(member, index)
        }, (member: GroupMember) => member.deviceId)
      }
      .width('100%')
      .borderRadius(12)
      .backgroundColor(Color.White)
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  @Builder
  memberItem(member: GroupMember, index: number) {
    Row() {
      // 头像
      this.memberAvatar(member)

      // 名称 + 角色标签
      Row() {
        Text(member.deviceName)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A2E')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (member.isOwner) {
          Text('群主')
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .backgroundColor('#E8753A')
            .borderRadius(9999)
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .margin({ left: 6 })
        } else {
          Text('成员')
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor('#6B6B80')
            .backgroundColor('#EDEDF0')
            .borderRadius(9999)
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .margin({ left: 6 })
        }
      }
      .layoutWeight(1)

      // 在线状态
      Row() {
        Circle()
          .width(6)
          .height(6)
          .fill(member.isOnline ? '#34C759' : '#9E9EB0')
        Text(member.isOnline ? '在线' : '离线')
          .fontSize(12)
          .fontColor(member.isOnline ? '#34C759' : '#9E9EB0')
          .margin({ left: 4 })
      }
      .margin({ left: 8 })
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .border({
      width: { bottom: index < this.viewModel.memberCount - 1 ? 0.5 : 0 },
      color: { bottom: '#EAEAEF' }
    })
  }

  @Builder
  memberAvatar(member: GroupMember) {
    Stack() {
      Circle()
        .width(48)
        .height(48)
        .fill(AVATAR_COLORS[getAvatarColorIndex(member.deviceName)])
      Text(member.deviceName.charAt(0))
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(AVATAR_TEXT_COLORS[getAvatarColorIndex(member.deviceName)])
    }
    .width(48)
    .height(48)
    .margin({ right: 12 })
  }

  // =================== Action Section ===================

  @Builder
  actionSection() {
    Column() {
      // 标题
      Text('群组操作')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A2E')
        .width('100%')
        .padding({ left: 16, right: 16, top: 24, bottom: 12 })

      // 操作列表卡片
      Column() {
        // 邀请设备加入
        this.actionButton(
          '邀请设备加入',
          '#E8753A',
          false,
          true,
          () => { this.onInviteDevice(); }
        )

        // 清空聊天记录
        this.actionButton(
          '清空聊天记录',
          '#6B6B80',
          false,
          true,
          () => { this.onClearHistory(); }
        )

        // 退出群组（危险操作，左侧红色边框强调）
        this.actionButton(
          '退出群组',
          '#FF3B30',
          true,
          false,
          () => { this.onLeaveGroup(); }
        )
      }
      .width('100%')
      .borderRadius(12)
      .backgroundColor(Color.White)
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  @Builder
  actionButton(label: string, color: string, isDanger: boolean, hasBorder: boolean,
    onClick: () => void) {
    Button() {
      Row() {
        Text(label)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(color)
      }
      .width('100%')
      .height(44)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(44)
    .backgroundColor(isDanger ? 'rgba(255, 59, 48, 0.03)' : Color.Transparent)
    .border({
      width: {
        left: isDanger ? 2 : 0,
        bottom: hasBorder ? 0.5 : 0
      },
      color: {
        left: isDanger ? '#FF3B30' : Color.Transparent,
        bottom: '#EAEAEF'
      }
    })
    .borderRadius(0)
    .onClick(onClick)
  }

  // =================== Actions ===================

  private onInviteDevice(): void {
    promptAction.showToast({ message: '功能开发中', duration: 2000 });
  }

  private async onClearHistory(): Promise<void> {
    await this.viewModel.clearChatHistory();
    promptAction.showToast({ message: '聊天记录已清空', duration: 2000 });
  }

  private async onLeaveGroup(): Promise<void> {
    await this.viewModel.leaveGroup();
    promptAction.showToast({ message: '已退出群组', duration: 2000 });
    // 返回到首页
    router.back({ url: 'pages/Index' });
  }

  /** 获取群组头像展示文本（取群名前两个字符） */
  private getGroupAvatarText(): string {
    let name: string = this.viewModel.groupName;
    if (!name) {
      return '群';
    }
    return name.substring(0, Math.min(2, name.length));
  }
}
