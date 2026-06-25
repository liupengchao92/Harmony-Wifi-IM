import { SessionModel } from '../model/SessionModel';
import { SessionRepository } from '../common/database/SessionRepository';
import { MessageRepository } from '../common/database/MessageRepository';
import { IMManager } from '../model/IMManager';
import { Logger } from '../common/utils/Logger';

/**
 * 会话列表视图模型
 *
 * 管理会话列表页的所有状态和业务逻辑：
 * 1. 加载所有会话（按最后消息时间倒序）
 * 2. 未读消息数统计
 * 3. 会话删除（级联删除消息）
 * 4. 未读清零
 */
@Observed
export class SessionListViewModel {
  sessions: SessionModel[] = [];
  unreadTotal: number = 0;

  private sessionRepository: SessionRepository = new SessionRepository();
  private messageRepository: MessageRepository = new MessageRepository();
  private imManager: IMManager = IMManager.getInstance();
  private logger: Logger = new Logger('SessionListViewModel');

  /** 加载所有会话并按时间排序 */
  public async loadSessions(): Promise<void> {
    this.logger.info('loadSessions: 加载会话列表');
    this.sessions = await this.sessionRepository.getAllSessions();
    this.updateUnreadTotal();
  }

  /** 收到新消息后重新加载会话列表 */
  public async onNewMessage(): Promise<void> {
    this.sessions = await this.sessionRepository.getAllSessions();
    this.updateUnreadTotal();
  }

  /** 删除会话及其所有关联消息 */
  public async deleteSession(sessionId: string): Promise<void> {
    this.logger.info(`deleteSession: sessionId=${sessionId}`);
    await this.sessionRepository.deleteSession(sessionId);
    await this.messageRepository.deleteSessionMessages(sessionId);
    // 手动替换数组以触发 @State 更新
    let newSessions: SessionModel[] = [];
    for (let i: number = 0; i < this.sessions.length; i++) {
      if (this.sessions[i].sessionId !== sessionId) {
        newSessions.push(this.sessions[i]);
      }
    }
    this.sessions = newSessions;
    this.updateUnreadTotal();
  }

  /** 清空指定会话的未读计数 */
  public async clearUnread(sessionId: string): Promise<void> {
    await this.sessionRepository.clearUnread(sessionId);
    let session: SessionModel | undefined = this.findSession(sessionId);
    if (session) {
      session.unreadCount = 0;
    }
    this.updateUnreadTotal();
  }

  /** 在会话列表中查找指定会话 */
  private findSession(sessionId: string): SessionModel | undefined {
    for (let i: number = 0; i < this.sessions.length; i++) {
      if (this.sessions[i].sessionId === sessionId) {
        return this.sessions[i];
      }
    }
    return undefined;
  }

  /** 更新未读消息总数 */
  private updateUnreadTotal(): void {
    let total: number = 0;
    for (let i: number = 0; i < this.sessions.length; i++) {
      total += this.sessions[i].unreadCount;
    }
    this.unreadTotal = total;
  }

  /** 获取当前连接状态的文本描述（用于 UI 显示） */
  public getConnectionState(): string {
    let state: number = this.imManager.getConnectionState();
    if (state === 2) {
      return '已连接';
    } else if (state === 1) {
      return '连接中...';
    }
    return '未连接';
  }
}
