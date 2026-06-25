import { GroupMember } from '../model/GroupMember';
import { IMManager } from '../model/IMManager';
import { SessionRepository } from '../common/database/SessionRepository';
import { MessageRepository } from '../common/database/MessageRepository';
import { Logger } from '../common/utils/Logger';

/**
 * 群详情视图模型
 *
 * 管理群详情页的所有状态和业务逻辑：
 * 1. 群组基本信息（名称、ID、创建时间）
 * 2. 成员列表（从 IMManager 获取）
 * 3. 群组操作（邀请、清空聊天、退出）
 */
@Observed
export class GroupDetailViewModel {
  groupName: string = '';
  groupId: string = '';
  createdTime: number = 0;
  memberCount: number = 0;
  members: GroupMember[] = [];
  isGroupOwner: boolean = false;

  private sessionId: string = '';
  private imManager: IMManager = IMManager.getInstance();
  private sessionRepository: SessionRepository = new SessionRepository();
  private messageRepository: MessageRepository = new MessageRepository();
  private logger: Logger = new Logger('GroupDetailViewModel');

  /** 初始化群详情数据 */
  public async init(sessionId: string): Promise<void> {
    this.sessionId = sessionId;
    this.logger.info(`init: sessionId=${sessionId}`);

    // 从 IMManager 获取群组成员和创建时间
    this.members = this.imManager.getGroupMembers();
    this.memberCount = this.members.length;
    this.isGroupOwner = this.imManager.isGroupOwner();
    this.createdTime = this.imManager.getGroupCreatedTime();

    // 群组 ID 从 sessionId 中提取（格式：group_<deviceId>）
    this.groupId = sessionId;

    // 群组名称从数据库会话记录中获取
    let session = await this.sessionRepository.getSessionById(sessionId);
    if (session) {
      this.groupName = session.peerName || 'P2P群组';
    } else {
      this.groupName = 'P2P群组';
    }
  }

  /** 邀请设备加入（暂为占位） */
  public inviteDevice(): void {
    this.logger.info('inviteDevice: 功能开发中');
  }

  /** 清空聊天记录 */
  public async clearChatHistory(): Promise<void> {
    this.logger.info(`clearChatHistory: sessionId=${this.sessionId}`);
    await this.messageRepository.deleteSessionMessages(this.sessionId);
    // 更新会话的最后一条消息为空
    let session = await this.sessionRepository.getSessionById(this.sessionId);
    if (session) {
      session.lastMessage = '';
      session.lastMessageTime = Date.now();
      await this.sessionRepository.saveSession(session);
    }
  }

  /** 退出群组 */
  public async leaveGroup(): Promise<void> {
    this.logger.info(`leaveGroup: sessionId=${this.sessionId}`);
    // 断开 TCP 连接并清理群组状态
    this.imManager.disconnect();
    // 删除会话及消息
    await this.sessionRepository.deleteSession(this.sessionId);
    await this.messageRepository.deleteSessionMessages(this.sessionId);
  }
}
