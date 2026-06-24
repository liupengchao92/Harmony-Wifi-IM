import { MessageModel, MessageStatus } from '../../model/MessageModel';
import { MessageDao } from './MessageDao';

export class MessageRepository {
  private messageDao: MessageDao = new MessageDao();

  public async saveMessage(message: MessageModel): Promise<void> {
    await this.messageDao.insert(message);
  }

  public async getMessagesBySession(sessionId: string, limit: number, offset: number): Promise<MessageModel[]> {
    return await this.messageDao.getBySessionId(sessionId, limit, offset);
  }

  public async getAllMessagesBySession(sessionId: string): Promise<MessageModel[]> {
    return await this.messageDao.getAllBySessionId(sessionId);
  }

  public async updateMessageStatus(messageId: string, status: MessageStatus): Promise<void> {
    await this.messageDao.updateStatus(messageId, status);
  }

  public async deleteSessionMessages(sessionId: string): Promise<void> {
    await this.messageDao.deleteBySessionId(sessionId);
  }
}
