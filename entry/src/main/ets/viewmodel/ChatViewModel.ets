import { MessageModel, MessageType, MessageStatus } from '../model/MessageModel';
import { IMManager } from '../model/IMManager';
import { MessageRepository } from '../common/database/MessageRepository';
import { SessionRepository } from '../common/database/SessionRepository';
import { Logger } from '../common/utils/Logger';

/**
 * 聊天视图模型
 *
 * 管理聊天页的所有状态和业务逻辑：
 * 1. 加载历史消息
 * 2. 发送文本/图片消息
 * 3. 接收实时消息（通过 IMManager 回调）
 * 4. 会话未读清零
 */
@Observed
export class ChatViewModel {
  messages: MessageModel[] = [];
  sessionId: string = '';
  sessionType: number = 1;   // 1=单聊, 2=群聊
  peerName: string = '';
  isSending: boolean = false;
  groupMemberCount: number = 0;

  private imManager: IMManager = IMManager.getInstance();
  private messageRepository: MessageRepository = new MessageRepository();
  private sessionRepository: SessionRepository = new SessionRepository();
  private logger: Logger = new Logger('ChatViewModel');

  /** 当有新消息添加到 messages 数组时通知 UI 层（用于自动滚动） */
  onMessageAdded: (() => void) | null = null;

  /**
   * 初始化聊天页面
   * @param sessionId 会话 ID
   * @param sessionType 会话类型（1=单聊, 2=群聊）
   * @param peerName 对方名称/群组名称
   */
  public init(sessionId: string, sessionType: number, peerName: string): void {
    this.sessionId = sessionId;
    this.sessionType = sessionType;
    this.peerName = peerName;
    this.logger.info(`init: sessionId=${sessionId}, type=${sessionType}, peerName=${peerName}`);

    // 加载本地历史消息
    this.loadHistoryMessages();

    // 注册实时消息接收回调
    this.imManager.onNewMessage((message: MessageModel) => {
      // 仅处理当前会话的消息（单聊按 sessionId 匹配，群聊按 GROUP 匹配）
      if (message.sessionId === this.sessionId ||
        (message.receiverId === 'GROUP' && this.sessionType === 2)) {
        this.logger.info(`onNewMessage: type=${MessageType[message.type]}, from=${message.senderName}`);
        // ArkTS @State 需要整体替换数组才能触发更新
        let newArr: MessageModel[] = new Array(this.messages.length + 1);
        for (let i: number = 0; i < this.messages.length; i++) {
          newArr[i] = this.messages[i];
        }
        newArr[this.messages.length] = message;
        this.messages = newArr;
        if (this.onMessageAdded) {
          this.onMessageAdded();
        }
      }
    });

    // 群聊时获取成员数量
    if (sessionType === 2) {
      this.groupMemberCount = this.imManager.getGroupMembers().length;
    }
  }

  /** 从数据库加载历史消息（按时间正序） */
  private async loadHistoryMessages(): Promise<void> {
    this.messages = await this.messageRepository.getAllMessagesBySession(this.sessionId);
    this.logger.info(`loadHistoryMessages: ${this.messages.length} 条消息`);
  }

  /**
   * 发送文本消息
   * 1. 创建 MessageModel（状态=SENDING）
   * 2. 立即添加到消息列表（乐观更新）
   * 3. 通过 IMManager 发送
   */
  public sendTextMessage(text: string): void {
    if (!text.trim()) {
      return;
    }
    let receiverId: string = this.sessionType === 1 ? this.sessionId : 'GROUP';
    this.logger.info(`sendTextMessage: to=${receiverId}`);

    let message: MessageModel = new MessageModel();
    message.type = MessageType.TEXT;
    message.content = text.trim();
    message.senderId = this.imManager.getLocalDeviceId();
    message.senderName = this.imManager.getLocalDeviceName();
    message.receiverId = receiverId;
    message.sessionId = this.sessionId;
    message.isLocal = true;
    message.status = MessageStatus.SENDING;

    // 立即添加到列表（乐观更新）
    let newArr: MessageModel[] = new Array(this.messages.length + 1);
    for (let i: number = 0; i < this.messages.length; i++) {
      newArr[i] = this.messages[i];
    }
    newArr[this.messages.length] = message;
    this.messages = newArr;
    if (this.onMessageAdded) {
      this.onMessageAdded();
    }

    this.isSending = true;
    this.imManager.sendMessage(message);
    this.isSending = false;
  }

  /**
   * 发送图片消息
   * 当前为占位实现，后续需要集成文件选择和图片压缩
   */
  public sendImageMessage(imagePath: string): void {
    let receiverId: string = this.sessionType === 1 ? this.sessionId : 'GROUP';
    let fileName: string = imagePath.split('/').pop() ?? 'image.jpg';
    this.logger.info(`sendImageMessage: path=${imagePath}`);

    let message: MessageModel = new MessageModel();
    message.type = MessageType.IMAGE;
    message.content = '[图片] ' + fileName;
    message.senderId = this.imManager.getLocalDeviceId();
    message.senderName = this.imManager.getLocalDeviceName();
    message.receiverId = receiverId;
    message.sessionId = this.sessionId;
    message.isLocal = true;
    message.status = MessageStatus.SENDING;
    message.imagePath = imagePath;
    message.imageSize = 0;

    // 立即添加到列表
    let newArr: MessageModel[] = new Array(this.messages.length + 1);
    for (let i: number = 0; i < this.messages.length; i++) {
      newArr[i] = this.messages[i];
    }
    newArr[this.messages.length] = message;
    this.messages = newArr;
    if (this.onMessageAdded) {
      this.onMessageAdded();
    }

    this.isSending = true;
    this.imManager.sendMessage(message);
    this.isSending = false;
  }

  /** 清空当前会话的未读计数 */
  public async clearUnread(): Promise<void> {
    await this.sessionRepository.clearUnread(this.sessionId);
  }

  public getLocalDeviceId(): string {
    return this.imManager.getLocalDeviceId();
  }
}
