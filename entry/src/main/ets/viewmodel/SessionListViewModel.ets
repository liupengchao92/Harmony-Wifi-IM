import { SessionModel } from '../model/SessionModel';
import { SessionRepository } from '../common/database/SessionRepository';
import { MessageRepository } from '../common/database/MessageRepository';
import { IMManager } from '../model/IMManager';

@Observed
export class SessionListViewModel {
  sessions: SessionModel[] = [];
  unreadTotal: number = 0;

  private sessionRepository: SessionRepository = new SessionRepository();
  private messageRepository: MessageRepository = new MessageRepository();
  private imManager: IMManager = IMManager.getInstance();

  public async loadSessions(): Promise<void> {
    this.sessions = await this.sessionRepository.getAllSessions();
    this.updateUnreadTotal();
  }

  public async onNewMessage(): Promise<void> {
    this.sessions = await this.sessionRepository.getAllSessions();
    this.updateUnreadTotal();
  }

  public async deleteSession(sessionId: string): Promise<void> {
    await this.sessionRepository.deleteSession(sessionId);
    await this.messageRepository.deleteSessionMessages(sessionId);
    let newSessions: SessionModel[] = [];
    for (let i = 0; i < this.sessions.length; i++) {
      if (this.sessions[i].sessionId !== sessionId) {
        newSessions.push(this.sessions[i]);
      }
    }
    this.sessions = newSessions;
    this.updateUnreadTotal();
  }

  public async clearUnread(sessionId: string): Promise<void> {
    await this.sessionRepository.clearUnread(sessionId);
    let session = this.findSession(sessionId);
    if (session) {
      session.unreadCount = 0;
    }
    this.updateUnreadTotal();
  }

  private findSession(sessionId: string): SessionModel | undefined {
    for (let i = 0; i < this.sessions.length; i++) {
      if (this.sessions[i].sessionId === sessionId) {
        return this.sessions[i];
      }
    }
    return undefined;
  }

  private updateUnreadTotal(): void {
    let total = 0;
    for (let i = 0; i < this.sessions.length; i++) {
      total += this.sessions[i].unreadCount;
    }
    this.unreadTotal = total;
  }

  public getConnectionState(): string {
    let state = this.imManager.getConnectionState();
    if (state === 2) {
      return '已连接';
    } else if (state === 1) {
      return '连接中...';
    }
    return '未连接';
  }
}
