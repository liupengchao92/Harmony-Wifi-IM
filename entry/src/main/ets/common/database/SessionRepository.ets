import { SessionModel } from '../../model/SessionModel';
import { SessionDao } from './SessionDao';

export class SessionRepository {
  private sessionDao: SessionDao = new SessionDao();

  public async saveSession(session: SessionModel): Promise<void> {
    await this.sessionDao.upsert(session);
  }

  public async getAllSessions(): Promise<SessionModel[]> {
    return await this.sessionDao.getAll();
  }

  public async getSessionById(sessionId: string): Promise<SessionModel | null> {
    return await this.sessionDao.getById(sessionId);
  }

  public async clearUnread(sessionId: string): Promise<void> {
    await this.sessionDao.clearUnread(sessionId);
  }

  public async deleteSession(sessionId: string): Promise<void> {
    await this.sessionDao.delete(sessionId);
  }
}
